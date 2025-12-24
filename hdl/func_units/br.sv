module branch_unit
  import rv32i_types::*;
  import params::*;
(
    input  logic                 clk,
    input  logic                 rst,

    output logic [P_WIDTH-1:0]   rs1_paddr,
    output logic [P_WIDTH-1:0]   rs2_paddr,

    input  logic [31:0]          p1_data,
    input  logic [31:0]          p2_data,

    input  RS_t                  BR_RS_next,
    output RS_t                  BR_RS_out
);


  // logic [31:0] p1_data_save, p2_data_save;

  // always_ff @(posedge clk) begin
  //   if (rst) begin
  //     p1_data_save <= '0;
  //     p2_data_save <= '0;
  //   end else begin
  //     p1_data_save <= p1_data;
  //     p2_data_save <= p2_data;
  //   end
  // end
logic signed   [31:0] cas;
    logic signed   [31:0] cbs;
    logic unsigned [31:0] cau;
    logic unsigned [31:0] cbu;
    logic          [31:0]  ca, cb;
  logic branch_taken;

    assign cas =   signed'(ca);
    assign cbs =   signed'(cb);
    assign cau = unsigned'(ca);
    assign cbu = unsigned'(cb);
    // assign ca = id_ex.instr_pkt.rs1_data;
    // assign cb = id_ex.instr_pkt.rs2_data;

    always_comb begin
        ca = p1_data;
        cb = p2_data;
        // cb = id_ex.instr_pkt.rs2_data;

        unique case (BR_RS_next.funct3)
            branch_f3_beq : branch_taken = (cau == cbu);
            branch_f3_bne : branch_taken = (cau != cbu);
            branch_f3_blt : branch_taken = (cas <  cbs);
            branch_f3_bge : branch_taken = (cas >= cbs);
            branch_f3_bltu: branch_taken = (cau <  cbu);
            branch_f3_bgeu: branch_taken = (cau >= cbu);
            default       : branch_taken = 1'b0;
        endcase
    end

  // logic branch_taken;

  // always_comb begin
  //   branch_taken = 1'b0;

  //   if (BR_RS_next.valid) begin
  //     unique case (BR_RS_next.funct3)
  //       branch_f3_beq : branch_taken = (p1_data == p2_data);
  //       branch_f3_bne : branch_taken = (p1_data != p2_data);
  //       branch_f3_blt : branch_taken = ($signed(p1_data) <  $signed(p2_data));
  //       branch_f3_bge : branch_taken = ($signed(p1_data) >= $signed(p2_data));
  //       branch_f3_bltu: branch_taken = (p1_data <  p2_data);
  //       branch_f3_bgeu: branch_taken = (p1_data >= p2_data);
  //       default       : branch_taken = 1'bx;
        
  //     endcase
  //   end
  // end


  logic [31:0] pc_next_c;
  logic        flush_c;
  logic [31:0] rd_wdata_c;

  always_comb begin
    /* safe defaults */
    pc_next_c = BR_RS_next.pc + 32'd4;
    flush_c   = 1'b0;
    rd_wdata_c = '0;
    
    if (BR_RS_next.valid) begin
      unique case (BR_RS_next.mul_sel)
        // JAL
        2'b00: begin
          pc_next_c = BR_RS_next.pc + BR_RS_next.imm;
          flush_c   = 1'b1;
          rd_wdata_c = BR_RS_next.pc + 32'd4; 
        end
        // JALR
        2'b01: begin
          pc_next_c = (p1_data + BR_RS_next.imm) & 32'hFFFF_FFFE;
          flush_c   = 1'b1;
          rd_wdata_c = BR_RS_next.pc + 32'd4;
        end
        // BRANCH
        2'b10: begin
          if (branch_taken) begin
            pc_next_c = BR_RS_next.pc + BR_RS_next.imm;
            flush_c   = (pc_next_c == BR_RS_next.pc + 32'd4) ? 1'b0 : 1'b1;
          end
        end
        default: ;  // leave defaults
      endcase
    end
  end
  logic mispredict;
  assign mispredict =  (flush_c != BR_RS_next.branch_taken || (flush_c && pc_next_c != BR_RS_next.branch_target));

  


  always_ff @(posedge clk) begin
    if (rst) begin
      BR_RS_out <= '0;
    end else begin
      // copy everything from the incoming RS entry first
      BR_RS_out <= BR_RS_next;

      // overwrite fields that change in this stage
      BR_RS_out.rvfi.rs1_rdata <= p1_data;
      BR_RS_out.rvfi.rs2_rdata <= p2_data;
      BR_RS_out.rvfi.rd_wdata <= rd_wdata_c;
      BR_RS_out.rvfi.pc_wdata <= pc_next_c;
      BR_RS_out.pc_next        <= pc_next_c;
      BR_RS_out.rd_wdata      <= rd_wdata_c;
      BR_RS_out.flush          <= mispredict;
    end
  end


  assign rs1_paddr = BR_RS_next.rs1_use ? BR_RS_next.rs1_paddr : '0;
  assign rs2_paddr = BR_RS_next.rs2_use ? BR_RS_next.rs2_paddr : '0;

endmodule : branch_unit