module prf
  import rv32i_types::*;
  import params::*;
(
    input logic               clk,
    input logic               rst,
    input CDB_t               CDB          [CDB_SIZE],  // Fixed CDB size = 5
    input       [P_WIDTH-1:0] alu_rs1_paddr,
    input       [P_WIDTH-1:0] alu_rs2_paddr,
    input       [P_WIDTH-1:0] mul_rs1_paddr,
    input       [P_WIDTH-1:0] mul_rs2_paddr,
    input       [P_WIDTH-1:0] div_rs1_paddr,
    input       [P_WIDTH-1:0] div_rs2_paddr,
    input       [P_WIDTH-1:0] br_rs1_paddr,
    input       [P_WIDTH-1:0] br_rs2_paddr,
    input       [P_WIDTH-1:0] ls_rs1_paddr,
    input       [P_WIDTH-1:0] ls_rs2_paddr,

    output logic [31:0] alu_rs1_v,
    output logic [31:0] alu_rs2_v,
    output logic [31:0] mul_rs1_v,
    output logic [31:0] mul_rs2_v,
    output logic [31:0] div_rs1_v,
    output logic [31:0] div_rs2_v,
    output logic [31:0] br_rs1_v,
    output logic [31:0] br_rs2_v,
    output logic [31:0] ls_rs1_v,
    output logic [31:0] ls_rs2_v
);

  //-------------------------------------------------------------------------
  // Register file storage: 128 registers, each 32 bits wide.
  //-------------------------------------------------------------------------
  logic [31:0] data[0:P_REG_SIZE-1];

  //-------------------------------------------------------------------------
  // Sequential register file update (write-back via the CDB broadcasts)
  //-------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
      // On reset, clear all physical registers.
      for (integer unsigned i = 0; i < P_REG_SIZE; i++) begin
        data[i] <= 32'd0;
      end
    end else begin
      // For each CDB entry, if the write enable is active and the destination register is nonzero,
      // update the register file at the specified physical register address.
      for (integer unsigned i = 0; i < CDB_SIZE; i++) begin
        if (CDB[i].valid && (CDB[i].rd_addr != 5'd0)) begin
          data[CDB[i].rd_paddr] <= CDB[i].rd_data;
        end
      end
    end
  end

  //-------------------------------------------------------------------------
  // Combinational logic: read out operands and forward data from the CDB if necessary.
  //-------------------------------------------------------------------------
  always_comb begin
    // Initially read out the register file for each source operand.
    alu_rs1_v = (alu_rs1_paddr != {P_WIDTH{1'b0}}) ? data[alu_rs1_paddr] : 32'd0;
    alu_rs2_v = (alu_rs2_paddr != {P_WIDTH{1'b0}}) ? data[alu_rs2_paddr] : 32'd0;
    mul_rs1_v = (mul_rs1_paddr != {P_WIDTH{1'b0}}) ? data[mul_rs1_paddr] : 32'd0;
    mul_rs2_v = (mul_rs2_paddr != {P_WIDTH{1'b0}}) ? data[mul_rs2_paddr] : 32'd0;
    div_rs1_v = (div_rs1_paddr != {P_WIDTH{1'b0}}) ? data[div_rs1_paddr] : 32'd0;
    div_rs2_v = (div_rs2_paddr != {P_WIDTH{1'b0}}) ? data[div_rs2_paddr] : 32'd0;
    br_rs1_v  = (br_rs1_paddr != {P_WIDTH{1'b0}}) ? data[br_rs1_paddr] : 32'd0;
    br_rs2_v  = (br_rs2_paddr != {P_WIDTH{1'b0}}) ? data[br_rs2_paddr] : 32'd0;
    ls_rs1_v  = (ls_rs1_paddr != {P_WIDTH{1'b0}}) ? data[ls_rs1_paddr] : 32'd0;
    ls_rs2_v  = (ls_rs2_paddr != {P_WIDTH{1'b0}}) ? data[ls_rs2_paddr] : 32'd0;

    // Forwarding logic:
    // For every CDB entry, if it is valid and its destination register is nonzero, then check if
    // the destination matches any of the source addresses. If it does, forward the value.
    for (integer unsigned i = 0; i < CDB_SIZE; i++) begin
      if (CDB[i].valid && (CDB[i].rd_addr != 5'd0)) begin
        if (alu_rs1_paddr == CDB[i].rd_paddr) alu_rs1_v = CDB[i].rd_data;
        if (alu_rs2_paddr == CDB[i].rd_paddr) alu_rs2_v = CDB[i].rd_data;
        if (mul_rs1_paddr == CDB[i].rd_paddr) mul_rs1_v = CDB[i].rd_data;
        if (mul_rs2_paddr == CDB[i].rd_paddr) mul_rs2_v = CDB[i].rd_data;
        if (div_rs1_paddr == CDB[i].rd_paddr) div_rs1_v = CDB[i].rd_data;
        if (div_rs2_paddr == CDB[i].rd_paddr) div_rs2_v = CDB[i].rd_data;
        if (br_rs1_paddr == CDB[i].rd_paddr) br_rs1_v = CDB[i].rd_data;
        if (br_rs2_paddr == CDB[i].rd_paddr) br_rs2_v = CDB[i].rd_data;
        if (ls_rs1_paddr == CDB[i].rd_paddr) ls_rs1_v = CDB[i].rd_data;
        if (ls_rs2_paddr == CDB[i].rd_paddr) ls_rs2_v = CDB[i].rd_data;
      end
    end
  end

endmodule : prf