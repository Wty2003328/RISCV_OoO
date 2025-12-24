module ooo_gshare_btb
  import rv32i_types::*;
  import params::*;
(
    input logic clk,
    input logic rst,

    // FETCH interface
    input  logic        fetch_en,
    // input  logic [31:0]            pc_fetch,
    output logic        predict_taken,
    output logic [31:0] pc_target,

    input fetch_pkt_t fifo_out,

    output fetch_pkt_t                 fifo_out_decode,
    // DISPATCH (speculation)
    input  logic                       dispatch_en,
    input  logic       [ROB_WIDTH-1:0] dispatch_rob_id,
    input  logic                       stall_RS_LS,      // stall because of RS/LS full

    // RESOLVE (commit)
    input logic                 resolve_en,      // one-hot for every branch commit
    input logic                 mispredict,      // flush
    input logic [ROB_WIDTH-1:0] resolve_rob_id,
    input logic [         31:0] actual_target    // flush_addr

    // one-cycle stall out to IF stage
    // output logic                   predictor_stall
);

  fetch_pkt_t fifo_out_next;

  always_comb begin
    fifo_out_next = fifo_out;
    // fifo_out_next.branch_taken = predict_taken;
    // fifo_out_next.branch_target = pc_target;
  end
  always_ff @(posedge clk) begin
    // predict taken sent with fifo_out_decode, don't want to send instr after
    if (rst | mispredict | (!stall_RS_LS && predict_taken)) begin
      fifo_out_decode <= '0;
    end else if (!stall_RS_LS && !mispredict) begin
      fifo_out_decode <= fifo_out_next;
    end
    // else
    //   fifo_out_decode.inst <= '1;
    // fifo_out_decode.branch_taken <= predict_taken;
    // fifo_out_decode.branch_target <= pc_target;
    // end
  end


  //─── PARAMETERS & TYPES ────────────────────────────────────────────────
  // typedef enum logic { IDLE, WAIT1 } fsm_t;
  logic [31:0] pc_fetch;
  //─── FETCH-STAGE FSM & INDEX CAPTURE ───────────────────────────────────
  logic        new_fetch;
  logic [31:0] pc_fetch_ff;
  logic [ 3:0] read_idx;
  // fsm_t         st, st_next;
  logic [ 6:0] opcode;
  assign pc_fetch  = fifo_out.pc;
  assign opcode    = fifo_out_decode.inst[6:0];

  // last‐cycle PC, so we detect “new fetch” when pc_fetch changes in IDLE
  assign new_fetch = (pc_fetch != '1) && (pc_fetch != pc_fetch_ff | fetch_en);
  // assign predictor_stall = (st == WAIT1);

  // always_ff @(posedge clk) begin
  //   if (rst)       st <= IDLE;
  //   else           st <= st_next;
  // end
  // always_comb begin
  //   st_next = st;
  //   case (st)
  //     IDLE: if (new_fetch) st_next = WAIT1;
  //     WAIT1:              st_next = IDLE;
  //   endcase
  // end

  logic [3:0] ghr;
  // latch last PC and grab the index when a new fetch fires
  logic [3:0] idx_fetch;
  logic [3:0] idx_fetch_ff;
  assign idx_fetch = pc_fetch[5:2] ^ ghr;
  always_ff @(posedge clk) begin
    if (rst | mispredict) begin
      pc_fetch_ff <= 32'b0;
      read_idx    <= 4'b0;
    end else begin
      if (pc_fetch != '1) pc_fetch_ff <= pc_fetch;
      if (new_fetch) read_idx <= idx_fetch;
      if (opcode inside {op_b_jal, op_b_jalr, op_b_br}) idx_fetch_ff <= read_idx;
    end
  end

  //─── GLOBAL HISTORY & CHECKPOINT ARRAYS ────────────────────────────────

  logic [3:0] ghr_cp[0:ROB_SIZE-1];
  logic [3:0] idx_cp[0:ROB_SIZE-1];

  //─── PHT SRAM & VALID ARRAY ────────────────────────────────────────────
  logic [1:0] pht_out, pht_next;
  logic pht_v_out;
  logic pht_taken_ff;
  // compute the *actual* direction from predicted ⊕ mispredict
  // (only valid when resolve_en==1; mispredict==1 flips the predicted)
  logic actual_dir;
  assign actual_dir = ((pht_taken_ff) ^ mispredict);

  // 2 saturating update at commit
  always_comb begin
    pht_next = 2'b10;
    if (resolve_en && pht_v_out) begin
      case (pht_out)
        2'b00:   pht_next = actual_dir ? 2'b01 : 2'b00;
        2'b01:   pht_next = actual_dir ? 2'b10 : 2'b00;
        2'b10:   pht_next = actual_dir ? 2'b11 : 2'b01;
        2'b11:   pht_next = actual_dir ? 2'b11 : 2'b10;
        default: pht_next = 2'b10;
      endcase
    end
  end

  // PHT counter SRAM (addr0 has one-cycle read latency)
  gshare_pht_array pht_array (
      .clk0(clk),
      .csb0(1'b0),
      .web0(~resolve_en),  // active-low write
      .addr0(resolve_en ? idx_cp[resolve_rob_id]  // on commit, write old index
      : read_idx),  // otherwise, read current
      .din0(pht_next),
      .dout0(pht_out)
  );

  // PHT valid  in an FF array (reset→0, set when we write)
  sp_ff_array #(
      .S_INDEX(4),
      .WIDTH  (1)
  ) pht_valid_array (
      .clk0 (clk),
      .rst0 (rst),
      .csb0 (1'b0),
      .web0 (~resolve_en),
      .addr0(resolve_en ? idx_cp[resolve_rob_id] : read_idx),
      .din0 (1'b1),
      .dout0(pht_v_out)
  );

  //─── BTB TAG SRAM + VALID + TARGET ────────────────────────────────────
  logic        btb_tag_v;
  logic [25:0] btb_tag_out;
  logic [31:0] btb_tgt_out;

  // Just the high PC in SRAM
  btb_tag_array btb_tag_array (
      .clk0 (clk),
      .csb0 (1'b0),
      .web0 (~resolve_en),
      .addr0(resolve_en ? idx_cp[resolve_rob_id] : read_idx),
      .din0 (pc_fetch[31:6]),
      .dout0(btb_tag_out)
  );

  // Reset-cleared valid flag
  sp_ff_array #(
      .S_INDEX(4),
      .WIDTH  (1)
  ) btb_valid_array (
      .clk0 (clk),
      .rst0 (rst),
      .csb0 (1'b0),
      .web0 (~resolve_en),
      .addr0(resolve_en ? idx_cp[resolve_rob_id] : read_idx),
      .din0 (1'b1),
      .dout0(btb_tag_v)
  );

  // Full 32 target
  btb_target_array btb_tgt_array (
      .clk0 (clk),
      .csb0 (1'b0),
      .web0 (~resolve_en),
      .addr0(resolve_en ? idx_cp[resolve_rob_id] : read_idx),
      .din0 (actual_target),
      .dout0(btb_tgt_out)
  );

  //─── REGISTERED OUTPUTS & GHR UPDATE ──────────────────────────────────

  logic        tag_v_ff;
  logic [25:0] tag_pc_ff;
  logic [31:0] tgt_ff;

  always_ff @(posedge clk) begin
    if (rst) begin
      ghr          <= 4'b0;
      pht_taken_ff <= 1'b0;
      tag_v_ff     <= 1'b0;
      tag_pc_ff    <= 26'b0;
      tgt_ff       <= 32'b0;
      // for(integer i=0; i<ROB_SIZE; i++) begin
      //   ghr_cp[i]     <= 8'b0;
      //   idx_cp[i]     <= 8'b0;
      // end
    end else begin
      // only trust the counter if valid, else default “not taken”
      pht_taken_ff <= pht_v_out ? pht_out[1] : 1'b0;

      tag_v_ff     <= btb_tag_v;
      tag_pc_ff    <= btb_tag_out;
      tgt_ff       <= btb_tgt_out;

      // speculative history push at dispatch
      if (dispatch_en) begin
        ghr_cp[dispatch_rob_id] <= ghr;
        idx_cp[dispatch_rob_id] <= read_idx;
        ghr <= {ghr[2:0], pht_taken_ff};
      end  // on commit, restore & push  direction
      else if (resolve_en) begin
        ghr <= {ghr_cp[resolve_rob_id][2:0], (pht_taken_ff ^ mispredict)};
      end
    end
  end
  localparam integer RAS_DEPTH = 8;
  logic [31:0] ras       [0:RAS_DEPTH-1];
  logic [ 2:0] ras_ptr;

  // Dispatch checkpoint （Record only）
  logic        is_call_cp[ 0:ROB_SIZE-1];
  logic        is_ret_cp [ 0:ROB_SIZE-1];
  logic [31:0] ret_pc_cp [ 0:ROB_SIZE-1];

  //── Dispatch ─────────────────────────────────
  always_ff @(posedge clk) begin
    if (rst) begin
      for (integer i = 0; i < ROB_SIZE; i++) begin
        is_call_cp[i] <= 1'b0;
        is_ret_cp[i]  <= 1'b0;
        ret_pc_cp[i]  <= '0;
      end
    end else if (dispatch_en) begin
      is_call_cp[dispatch_rob_id] <= (fifo_out_decode.inst[6:0] == op_b_jal);
      is_ret_cp[dispatch_rob_id]  <= (fifo_out_decode.inst[6:0] == op_b_jalr);
      ret_pc_cp[dispatch_rob_id]  <= fifo_out_decode.pc + 32'd4;
    end
  end

  //── Commit─────────────────────────────────────────
  always_ff @(posedge clk) begin
    if (rst) begin
      ras_ptr <= '0;
    end else if (resolve_en) begin
      // Commit 
      if (is_call_cp[resolve_rob_id]) begin
        // Call → push 
        ras[ras_ptr] <= ret_pc_cp[resolve_rob_id];
        ras_ptr      <= 3'(ras_ptr + 1);
      end else if (is_ret_cp[resolve_rob_id]) begin
        // Return → pop
        if (ras_ptr != 0) ras_ptr <= 3'(ras_ptr - 1);
      end
    end
  end

  //───────────────────────────────
  logic btb_hit;
  logic [31:0] ras_tos;
  assign ras_tos = (ras_ptr != 0) ? ras[ras_ptr-1] : 32'b0;
  //─── FINAL PREDICT OUTPUT ─────────────────────────────────────────────

  assign btb_hit = tag_v_ff && (tag_pc_ff == pc_fetch[31:6]);
  // assign predict_taken =  !stall_RS_LS && (fifo_out_decode.inst != '1) && ((pht_v_out ? pht_out[1] : 1'b0) && btb_hit) && opcode inside {op_b_br};
  always_comb begin
    pc_target = btb_hit ? tgt_ff : fifo_out_decode.pc + 4'd4;
    predict_taken =  !stall_RS_LS && (fifo_out_decode.inst != '1) && ((pht_v_out ? pht_out[1] : 1'b0) && btb_hit) && opcode inside {op_b_br};
    if (opcode == op_b_jalr) begin
      pc_target = ras_tos;
    end
  end
  // assign predict_taken = '0;
  // assign pc_target = btb_hit ? tgt_ff : fifo_out_decode.pc + 4'd4;
  logic test;
  assign test = opcode inside {op_b_jal, op_b_jalr, op_b_br};
endmodule
