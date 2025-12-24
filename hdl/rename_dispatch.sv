module rename_dispatch 
import rv32i_types::*;
import params::*;
(
    input logic       clk,
    input logic       rst,
    input logic [P_WIDTH - 1:0] ps1_RAT,
    input logic       ps1_valid,
    input logic [P_WIDTH - 1:0] ps2_RAT,
    input logic       ps2_valid,

    input logic [P_WIDTH - 1:0] pd_fl,

    input logic [ROB_WIDTH - 1:0] dispatch_ROB_Entry_ROB,

    // Control signals from the decoder/dispatched instruction
    input instr_pkt_t decode_output,
    input rvfi_t      decode_rvfi,
    // Status signals for free list, ROB, RS, etc.
    input logic is_empty_fl,
    input logic is_full_ROB,
    input logic is_full_RS,
    input logic is_full_LS,
    // input logic is_empty_fifo,
    // input logic fifo_deq,

    input logic       flush,
    input logic [63:0] flush_order,

    // Outputs to various structures
    output logic        fl_deque,            // To Free List FIFO: pop a free register
    output logic        ROB_enque,           // To ROB: enqueue new entry
    output logic        ROB_is_ls,         // To ROB: indicate if the head is a load/store instruction
    output logic        RS_enque,            // To RS: enqueue new entry (ALU type)
    output logic        LS_enque,            // To LS: enqueue new entry (LS)
    output RS_t         dispatch,         // ALU RS dispatch structure
    output logic [ 4:0] RAT_rd_dispatch,     // Destination architectural register for RAT update
    output logic [P_WIDTH - 1:0]  RAT_pd_dispatch,     // New physical register from the free list
    output logic [ 4:0] RAT_rs1_dispatch,    // Source register 1 for RAT lookup
    output logic [ 4:0] RAT_rs2_dispatch,    // Source register 2 for RAT lookup

    output logic [P_WIDTH - 1:0]  pd_rob,  // ROB pointer: physical register allocated for destination
    output logic [4:0] rd_rob,  // ROB pointer: destination architectural register
    output logic [63:0] order_rob,
    output logic RAT_dispatch_valid,  // Indicates that a valid dispatch is occurring
    // output logic fifo_deque  // Indicates that the FIFO should dequeue an entry

    output logic br_dispatch_en
);
  //-------------------------------------------------------------------------
  // Combinational control signals for dispatch enable and free list dequeue
  //-------------------------------------------------------------------------
  logic dispatch_execute;
  logic fl_deque_exception;  // Exception: no free-list pop needed (e.g. for branch, store, or nops)

  assign br_dispatch_en = dispatch_execute && (decode_output.opcode inside {op_b_jal, op_b_jalr, op_b_br});
  // Evaluate whether the dispatch should execute.
  always_comb begin
    // Default assignments
    fl_deque_exception = 1'b0;
    dispatch_execute   = 1'b0;
    // fifo_deque         = 1'b0;

    // If the destination register is 0 or the instruction is a store,
    // then no free-list allocation is required.
    if (decode_output.rd_addr == 5'd0 || decode_output.opcode == op_b_store) begin
      fl_deque_exception = 1'b1;
    end

    // Enable dispatch only if:
    // - The FIFO is not empty (i.e. instructions are available)
    // - The free list is not empty (unless not needed)
    // - The ROB, RS, and LS-specific RS are not full
    // - There is no flush in progress.

    if (!is_empty_fl && !is_full_ROB && !is_full_RS && (decode_output.valid)&& !is_full_LS) begin
      dispatch_execute = 1'b1;
      // fifo_deque       = 1'b1;
    end
  end

  // assign dispatch_execute =

  //-------------------------------------------------------------------------
  // Generate output enable signals for downstream structures
  //-------------------------------------------------------------------------
  assign fl_deque = dispatch_execute && !fl_deque_exception;
  assign ROB_enque = dispatch_execute;
  assign RAT_dispatch_valid = dispatch_execute;
  // assign RS_enque = dispatch_execute && ~(decode_output.opcode == op_b_store || decode_output.opcode == op_b_load);
  assign RS_enque = dispatch_execute && !ROB_is_ls;
  assign LS_enque = !is_empty_fl && !is_full_ROB && !is_full_RS && (decode_output.valid)  && ROB_is_ls;

  //-------------------------------------------------------------------------
  // RAT Update Signals: only valid when dispatch is enabled.
  //-------------------------------------------------------------------------
  always_comb begin
    // Default: unassigned
    RAT_rd_dispatch  = 5'dx;
    RAT_pd_dispatch  = 'x;
    RAT_rs1_dispatch = 5'dx;
    RAT_rs2_dispatch = 5'dx;
    if (RAT_dispatch_valid) begin
      RAT_rd_dispatch  = dispatch.rd_addr;
      RAT_pd_dispatch  = pd_fl;
      RAT_rs1_dispatch = decode_output.rs1_addr;
      RAT_rs2_dispatch = decode_output.rs2_addr;
    end
  end

  //-------------------------------------------------------------------------
  // ROB Update Signals: when enqueuing, forward the free-list physical register and destination.
  //-------------------------------------------------------------------------
  always_comb begin
    pd_rob = '0;
    rd_rob = '0;
    ROB_is_ls = '0;
    if (ROB_enque) begin
      pd_rob = pd_fl;
      rd_rob = dispatch.rd_addr;
      ROB_is_ls = (decode_output.opcode == op_b_load || decode_output.opcode == op_b_store);
    end
  end

  logic [63:0] order;
  always_ff @(posedge clk) begin
    if(rst)
      order <= '0;
    else if (flush) order <= flush_order;
    // else if (decode_output.valid && decode_output.predict_taken) order <= order;
    else if((RS_enque || LS_enque))
      order <= order + 1'b1;
  end
  assign order_rob = order;
  //-------------------------------------------------------------------------
  // RS Dispatch Structures: populate the dispatch entries for both ALU and load/store RS.
  //-------------------------------------------------------------------------
  always_comb begin
    // Default (unspecified) assignments.
    dispatch = 'x;

    if (RS_enque || LS_enque) begin
      dispatch.valid        = 1'b1;
      dispatch.imm          = decode_output.imm;
      dispatch.funct3       = decode_output.funct3;
      dispatch.mul_sel      = decode_output.mul_sel;
      dispatch.div_sel      = decode_output.div_sel;
      dispatch.aluop        = decode_output.aluop;
      dispatch.alu_m1_sel   = decode_output.alu_m1_sel;
      dispatch.alu_m2_sel   = decode_output.alu_m2_sel;
      dispatch.rs1_paddr    = ps1_RAT;
      dispatch.rs2_paddr    = ps2_RAT;
      dispatch.p1_rdy       = ps1_valid;
      dispatch.p2_rdy       = ps2_valid;
      dispatch.rd_addr      = decode_output.rd_use ? decode_output.rd_addr : '0;
      dispatch.rd_paddr     = fl_deque ? pd_fl : '0;
      dispatch.rs1_use      = decode_output.rs1_use;
      dispatch.rs2_use      = decode_output.rs2_use;
      dispatch.imm_use      = decode_output.imm_use;
      dispatch.rd_use       = decode_output.rd_use;
      // dispatch.ROB_Entry    = dispatch_ROB_Entry_ROB;
      // dispatch.control_sigs = decode_output;
      dispatch.CDB_ind      = decode_output.CDB_ind;
      dispatch.ls_sel       = decode_output.ls_sel;
      dispatch.pc           = decode_output.pc;
      dispatch.pc_next      = decode_output.pc_next;
      dispatch.ROB_entry    = dispatch_ROB_Entry_ROB;
      dispatch.rvfi         = decode_rvfi;
      dispatch.rvfi.order   = order;
      dispatch.branch_taken = decode_output.branch_taken;
      dispatch.branch_target = decode_output.branch_target;

      // For load instructions, or when using an immediate in place of rs2,
      // force ps2_valid high.
      if (decode_output.opcode == op_b_load) dispatch.p2_rdy = 1'b1;
      if (decode_output.imm_use== 1'b1 && decode_output.opcode != op_b_br) dispatch.p2_rdy = 1'b1;
      // For instructions like LUI/AUIPC, mark both source operand valid.
      if (decode_output.opcode == op_b_lui || decode_output.opcode == op_b_auipc) begin
        dispatch.p1_rdy = 1'b1;
        dispatch.p2_rdy = 1'b1;
      end
      // For jump instructions, update valid bits accordingly.
      if (decode_output.opcode == op_b_jal) begin
        dispatch.p1_rdy = 1'b1;
        dispatch.p2_rdy = 1'b1;
      end
      if (decode_output.opcode == op_b_jalr) dispatch.p2_rdy = 1'b1;
    end
  end

endmodule : rename_dispatch
