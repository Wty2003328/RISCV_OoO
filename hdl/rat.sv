module RAT
  import params::*;
  import rv32i_types::*;
(
    input logic clk,
    input logic rst,

    // Dispatch inputs for renaming a destination register (register 0 is hardwired and always valid)
    input logic                 dispatch_valid,
    input logic [          4:0] rd_dispatch,
    input logic [P_WIDTH - 1:0] pd_dispatch,

    input flush,
    input logic [P_WIDTH-1:0] RRAT[A_REG_SIZE],

    // Common Data Bus carrying updates from completed instructions (CDB array of fixed size 5)
    input CDB_t CDB[CDB_SIZE],

    // Dispatch source registers for operand lookup
    input logic [4:0] rs1_dispatch,
    input logic [4:0] rs2_dispatch,

    // RAT outputs for the physical register IDs and their valid bits
    output logic [P_WIDTH - 1:0] ps1,
    output logic                 ps1_valid,
    output logic [P_WIDTH - 1:0] ps2,
    output logic                 ps2_valid
);

  // Local parameters for internal use
  localparam NUM_ARCH_REGS = 32;
  localparam PHYS_REG_BITS = P_WIDTH;
  // localparam Integer CDB_SIZE = CDB_SI;

  // Internal RAT state: mapping from 32 architectural registers to physical registers
  logic [P_WIDTH-1:0] rat_mapping     [NUM_ARCH_REGS-1:0];
  logic [P_WIDTH-1:0] rat_mapping_next[NUM_ARCH_REGS-1:0];
  // Valid bits indicate whether the mapping holds a committed value
  logic               rat_valid       [NUM_ARCH_REGS-1:0];
  logic               rat_valid_next  [NUM_ARCH_REGS-1:0];
  //===================================================================
  // Sequential logic: update the RAT state on the clock edge
  //===================================================================
  always_ff @(posedge clk) begin
    if (rst) begin
      // On reset, directly map each architectural register to the same-numbered physical register
      // and mark them as valid.
      for (integer unsigned i = 0; i < NUM_ARCH_REGS; i++) begin
        rat_mapping[i] <= PHYS_REG_BITS'(i);
        rat_valid[i]   <= 1'b1;
      end
    end else begin
      rat_mapping <= rat_mapping_next;
      rat_valid   <= rat_valid_next;
    end
  end

  //===================================================================
  // Combinational logic: determine the next state of the RAT
  //===================================================================
  always_comb begin
    // By default, hold the current RAT state.
    rat_mapping_next = rat_mapping;
    rat_valid_next   = rat_valid;

    // On dispatch, allocate a new physical register for the destination (except for register 0)
    if (dispatch_valid && (rd_dispatch != 5'd0)) begin
      rat_mapping_next[rd_dispatch] = pd_dispatch;
      rat_valid_next[rd_dispatch]   = 1'b0;
    end

    if (flush) begin
      for (integer i = 0; i < 32; i++) begin
        rat_mapping_next[i] = RRAT[i];
        rat_valid_next[i]   = 1'b1;
      end
    end
    // end

    // //===================================================================
    // // Output logic: provide RAT mapping outputs for source registers.
    // // Includes forwarding logic from the CDB for updates in-flight.
    // //===================================================================
    // always_comb begin
    // Default assignments for outputs
    ps1       = 'x;
    ps1_valid = 'x;
    ps2       = 'x;
    ps2_valid = 'x;
    if (dispatch_valid) begin
      // Read the RAT mapping for source registers
      ps1       = rat_mapping[rs1_dispatch];
      ps1_valid = rat_valid[rs1_dispatch];
      ps2       = rat_mapping[rs2_dispatch];
      ps2_valid = rat_valid[rs2_dispatch];

      // If an update is in-flight that matches the source register mapping, forward the valid result.
      for (integer unsigned i = 0; i < CDB_SIZE; i++) begin
        if (CDB[i].valid) begin
          if ((rs1_dispatch == CDB[i].rd_addr) && (CDB[i].rd_paddr == rat_mapping[rs1_dispatch])) begin
            ps1_valid = 1'b1;
          end
          if ((rs2_dispatch == CDB[i].rd_addr) && (CDB[i].rd_paddr == rat_mapping[rs2_dispatch])) begin
            ps2_valid = 1'b1;
          end
          // rat_valid_next[CDB[i].rd_addr] = 1'b1;
        end
      end
    end
    for (integer unsigned i = 0; i < CDB_SIZE; i++) begin
      if (CDB[i].valid && CDB[i].rd_paddr == rat_mapping_next[CDB[i].rd_addr]) begin
        rat_valid_next[CDB[i].rd_addr] = 1'b1;
      end
    end
  end

endmodule : RAT
