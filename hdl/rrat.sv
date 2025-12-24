module rrat
  import rv32i_types::*;
  import params::*;
(
    input logic clk,
    input logic rst,
    input logic flush,
    input logic commit,
    // input logic rd_use, // may or maynot need
    // input logic flush,
    input logic [A_WIDTH-1:0] commit_rd_ROB,  // Architectural destination register at commit
    input logic [P_WIDTH-1:0] commit_pd_ROB,  // Committed physical register (7 bits)
    output logic [P_REG_SIZE-1:0] backup_free_list,  // backup free list
    output logic [P_WIDTH-1:0] RRAT[A_REG_SIZE],
    output logic [P_WIDTH-1:0] freed_reg_phys
);


  // always_ff @(posedge clk) begin
  //   // reset: map x0-31 to p0-31
  //   if (rst) begin
  //     for (integer unsigned i = 0; i < 32; i++) begin
  //       RRAT[i] <= unsigned'(P_WIDTH'(i));
  //     end
  //     // normal commit with rd used: update RRAT
  //   end else if (commit) begin
  //     RRAT[commit_rd_ROB] <= commit_pd_ROB;
  //   end
  // end

  // always_comb begin
  //   freed_reg_phys = 'x;
  //   if (commit) begin
  //     freed_reg_phys = RRAT[commit_rd_ROB];
  //   end
  // end

  logic [P_WIDTH-1:0] Reg_Mappings[0:A_REG_SIZE-1];
  logic               free_list   [0:P_REG_SIZE-1];
  always_ff @(posedge clk) begin
    if (rst) begin
      // Reset: x0..x31→p0..p31，free_list[0..31]=0，free_list[32..127]=1
      for (integer unsigned i = 0; i < A_REG_SIZE; i++) begin
        Reg_Mappings[i] <= P_WIDTH'(i);
      end
      for (integer unsigned i = 0; i < A_REG_SIZE; i++) free_list[i] <= 1'b0;
      for (integer unsigned i = A_REG_SIZE; i < P_REG_SIZE; i++) free_list[i] <= 1'b1;
    end else if (commit && (commit_rd_ROB != '0)) begin
      free_list[Reg_Mappings[commit_rd_ROB]] <= 1'b1;
      free_list[commit_pd_ROB]               <= 1'b0;
      Reg_Mappings[commit_rd_ROB]            <= commit_pd_ROB;
    end
  end


  always_comb begin
    if (commit && (commit_rd_ROB != '0)) freed_reg_phys = Reg_Mappings[commit_rd_ROB];
    else freed_reg_phys = '0;
  end

  always_comb begin
    // output current RRAT and free_list to backup
    for (integer unsigned i = 0; i < A_REG_SIZE; i++) RRAT[i] = Reg_Mappings[i];
    for (integer unsigned j = 0; j < P_REG_SIZE; j++) backup_free_list[j] = free_list[j];

    if (flush && commit && (commit_rd_ROB != '0)) begin
      RRAT[commit_rd_ROB]                           = commit_pd_ROB;
      backup_free_list[Reg_Mappings[commit_rd_ROB]] = 1'b1;
      backup_free_list[commit_pd_ROB]               = 1'b0;
    end
  end
endmodule