module ooo_gshare_btb_ff
  import rv32i_types::*;
  import params::*;
(
    input logic clk,
    input logic rst,

    // FETCH interface
    input  logic              fetch_en,
    output logic              predict_taken,
    output logic       [31:0] pc_target,
    input  fetch_pkt_t        fifo_out,
    output fetch_pkt_t        fifo_out_decode,

    // DISPATCH (speculation)
    input logic                 dispatch_en,
    input logic [ROB_WIDTH-1:0] dispatch_rob_id,
    input logic                 stall_RS_LS,

    // RESOLVE (commit)
    input logic                 resolve_en,
    input logic                 mispredict,
    input logic [ROB_WIDTH-1:0] resolve_rob_id,
    input logic [         31:0] actual_target
);

  // ────────────────────────────────────────────────────────────────
  // parameters & local defs
  localparam LG_BTB = 5;  // 2^5 = 32 entries
  localparam BTB_ENTRIES = 1 << LG_BTB;

  // GHR width = index width for gshare
  logic [LG_BTB-1:0] ghr;
  // checkpoint arrays
  logic [LG_BTB-1:0] ghr_cp       [   0:ROB_SIZE-1];
  logic [LG_BTB-1:0] idx_cp       [   0:ROB_SIZE-1];

  // PHT
  logic [       1:0] pht          [0:BTB_ENTRIES-1];
  logic              pht_v        [0:BTB_ENTRIES-1];
  logic [       1:0] pht_next;

  // BTB: tag, valid, target
  // store PC[31:7] as tag → 25 bits
  logic [      24:0] btb_tag      [0:BTB_ENTRIES-1];
  logic              btb_v        [0:BTB_ENTRIES-1];
  logic [      31:0] btb_tgt      [0:BTB_ENTRIES-1];

  // registered outputs
  logic              pht_taken_ff;
  logic              tag_v_ff;
  logic [      24:0] tag_pc_ff;
  logic [      31:0] tgt_ff;

  //─── INDEX GENERATION ─────────────────────────────────────────────
  logic [      31:0] pc_fetch;

  logic [       6:0] opcode;
  assign pc_fetch = fifo_out.pc;
  assign opcode   = fifo_out_decode.inst[6:0];
  // new fetch when fetch_en and PC changed
  logic        new_fetch;
  logic [31:0] pc_fetch_ff;
  assign new_fetch = fetch_en && (pc_fetch != pc_fetch_ff);

  // index = PC[6:2] ⊕ GHR
  wire [LG_BTB-1:0] read_idx = pc_fetch[LG_BTB+1:2] ^ ghr;

  // snapshot last fetch-PC & read_idx
  always_ff @(posedge clk) begin
    if (rst) begin
      pc_fetch_ff <= 32'b0;
    end else if (pc_fetch != '1) begin
      pc_fetch_ff <= pc_fetch;
    end
  end

  // at dispatch, checkpoint the index & history
  always_ff @(posedge clk) begin
    if (!rst && dispatch_en) begin
      ghr_cp[dispatch_rob_id] <= ghr;
      idx_cp[dispatch_rob_id] <= read_idx;
    end
  end

  //─── COMBINATIONAL PHT UPDATE ──────────────────────────────────────
  // actual direction = predicted ⊕ mispredict 
  wire actual_dir = pht_taken_ff ^ mispredict;
  // choose the write index at resolve
  wire [LG_BTB-1:0] write_idx = idx_cp[resolve_rob_id];

  always_comb begin
    pht_next = 2'b01;
    if (resolve_en && pht_v[write_idx]) begin
      case (pht[write_idx])
        2'b00: pht_next = actual_dir ? 2'b01 : 2'b00;
        2'b01: pht_next = actual_dir ? 2'b10 : 2'b00;
        2'b10: pht_next = actual_dir ? 2'b11 : 2'b01;
        2'b11: pht_next = actual_dir ? 2'b11 : 2'b10;
      endcase
    end
  end

  //─── SEQUENTIAL UPDATES: GHR、PHT、BTB ──────────────────────────────
  always_ff @(posedge clk) begin
    if (rst) begin
      ghr          <= '0;
      pht_taken_ff <= 1'b0;
      tag_v_ff     <= 1'b0;
      tag_pc_ff    <= '0;
      tgt_ff       <= '0;
      for (integer i = 0; i < BTB_ENTRIES; i++) begin
        pht[i]     <= 2'b10;
        pht_v[i]   <= 1'b0;
        btb_v[i]   <= 1'b0;
        btb_tag[i] <= '0;
        btb_tgt[i] <= '0;
      end
    end else begin
      pht_taken_ff <= pht_v[read_idx] ? pht[read_idx][1] : 1'b0;
      tag_v_ff     <= btb_v[read_idx];
      tag_pc_ff    <= btb_tag[read_idx];
      tgt_ff       <= btb_tgt[read_idx];

      if (dispatch_en) begin
        ghr <= {ghr[LG_BTB-2:0], pht_taken_ff};
      end else if (resolve_en) begin
        ghr <= {ghr_cp[resolve_rob_id][LG_BTB-2:0], (pht_taken_ff ^ mispredict)};
      end

      if (resolve_en) begin
        pht[write_idx]   <= pht_next;
        pht_v[write_idx] <= 1'b1;
      end

      // BTB ：tag = PC[31:7]，target = actual_target
      if (resolve_en) begin
        btb_v[write_idx]   <= 1'b1;
        btb_tag[write_idx] <= 25'(pc_fetch >> (LG_BTB + 2));
        btb_tgt[write_idx] <= actual_target;
      end
    end
  end

  //─── PREDICTION OUTPUT ─────────────────────────────────────────────
  wire btb_hit = tag_v_ff && (tag_pc_ff == 25'(pc_fetch >> (LG_BTB + 2)));
  assign predict_taken =
       !stall_RS_LS
    && (fifo_out_decode.inst != '1)
    && ((pht_v[read_idx] ? pht[read_idx][1] : 1'b1) && btb_hit)
    && (opcode inside {op_b_jal, op_b_jalr, op_b_br});

  assign pc_target = btb_hit ? tgt_ff : fifo_out_decode.pc + 32'd4;

  //─── FIFO）────────────────────────────────────
  always_ff @(posedge clk) begin
    // predict taken sent with fifo_out_decode, don't want to send instr after
    if (rst | mispredict | (!stall_RS_LS && predict_taken)) begin
      fifo_out_decode <= '0;
    end else if (!stall_RS_LS && !mispredict) begin
      fifo_out_decode <= fifo_out;
    end
    // else
    //   fifo_out_decode.inst <= '1;
    // fifo_out_decode.branch_taken <= predict_taken;
    // fifo_out_decode.branch_target <= pc_target;
    // end
  end
endmodule
