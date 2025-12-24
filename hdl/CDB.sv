module CDB
  import rv32i_types::*;
  import params::*;
(
    input logic        clk,
    // input   logic   rst,
    input logic [31:0] alu_out,     // instruction/data packet from ROB
    input logic [65:0] mul_out,
    input logic [32:0] div_out,
    input logic [32:0] rem_out,
    input logic [31:0] rd_ls_out, // pc_next from branch
    input logic        divide_by_0,

    input  RS_t  alu_RS,
    input  RS_t  mul_RS,
    input  RS_t  div_RS,
    input  RS_t  br_RS,
    input  RS_t  ls_RS,
    input  logic        flush,
    output CDB_t WB_Bus[CDB_SIZE]

);

  logic [31:0] pc_next;
  logic        valid;
  CDB_t        WB_Bus_next[CDB_SIZE];
  always_ff @(posedge clk) begin
    // if(rst)
    //     for (integer i = 0; i< CDB_SIZE; i++) begin
    //         WB_Bus[i] <= '{default: 0};
    //     end 
    // else
    WB_Bus <= WB_Bus_next;
  end

  always_comb begin
    // WB_Bus_next[mul].valid = '0;
    // WB_Bus_next[alu].valid = '0;
    // WB_Bus_next[div].valid = '0;
    for (integer unsigned i = 0; i < CDB_SIZE; i++) begin
      WB_Bus_next[i] = '{default: 0};
    end
      if (alu_RS.valid && !flush) begin
        WB_Bus_next[alu].valid = '1;
        // WB_Bus_next[alu].order = alu_RS.order;
        // WB_Bus_next[alu].inst = alu_RS.inst;
        WB_Bus_next[alu].rd_paddr = alu_RS.rd_paddr;
        WB_Bus_next[alu].rd_addr = alu_RS.rd_addr;
        WB_Bus_next[alu].rd_data = alu_out;
        WB_Bus_next[alu].ROB_entry = alu_RS.ROB_entry;
        WB_Bus_next[alu].rvfi = alu_RS.rvfi;
        WB_Bus_next[alu].rvfi.rd_wdata = alu_out;
        WB_Bus_next[alu].is_branch='0;
        WB_Bus_next[alu].pc_wdata = alu_RS.pc_next;
        WB_Bus_next[alu].flush = alu_RS.branch_taken;
        // WB_Bus_next[alu].rvfi.rs1_rdata = alu_RS.rvfi.rs1_rdata;
        // NEED TO IMPLEMENT AUIPC/LUI
      end
      if (mul_RS.valid && !flush) begin
        WB_Bus_next[mul].is_branch = '0;
        WB_Bus_next[mul].valid = '1;
        WB_Bus_next[mul].flush = mul_RS.branch_taken;
        // WB_Bus_next[mul].order = mul_RS.order;
        // WB_Bus_next[mul].inst = mul_RS.inst;
        WB_Bus_next[mul].rd_paddr = mul_RS.rd_paddr;
        WB_Bus_next[mul].rd_addr = mul_RS.rd_addr;
        WB_Bus_next[mul].pc_wdata = mul_RS.pc_next;
        // WB_Bus_next[mul].rd_data = mul_out;
        WB_Bus_next[mul].ROB_entry = mul_RS.ROB_entry;
        WB_Bus_next[mul].rvfi = mul_RS.rvfi;
        // WB_Bus_next[mul].rvfi.rd_wdata = mul_out;
        if (mul_RS.mul_sel == 2'b0) begin  // MUL
          WB_Bus_next[mul].rd_data = mul_out[31:0];
          WB_Bus_next[mul].rvfi.rd_wdata = mul_out[31:0];
        end else begin
          WB_Bus_next[mul].rd_data = mul_out[63:32];
          WB_Bus_next[mul].rvfi.rd_wdata = mul_out[63:32];
        end
        // NEED TO IMPLEMENT UPPER VS LOWER
      end
      if (div_RS.valid && !flush) begin
        WB_Bus_next[div].is_branch = '0;
        WB_Bus_next[div].valid = '1;
        WB_Bus_next[div].rd_paddr = div_RS.rd_paddr;
        WB_Bus_next[div].rd_addr = div_RS.rd_addr;
        WB_Bus_next[div].ROB_entry = div_RS.ROB_entry;
        WB_Bus_next[div].rvfi = div_RS.rvfi;
        WB_Bus_next[div].pc_wdata = div_RS.pc_next;
        WB_Bus_next[div].flush = div_RS.branch_taken;
        // WB_Bus_next[div].rvfi.rd_wdata = div_out;
        // NEED TO IMPLEMENT DIV VS REM
        if (div_RS.div_sel[1] == 1'b0) begin
          WB_Bus_next[div].rd_data = div_out[31:0];
          WB_Bus_next[div].rvfi.rd_wdata = div_out[31:0];
          if (divide_by_0) begin
            WB_Bus_next[div].rd_data = '1;
            WB_Bus_next[div].rvfi.rd_wdata = '1;
          end
        end else begin
          WB_Bus_next[div].rd_data = rem_out[31:0];
          WB_Bus_next[div].rvfi.rd_wdata = rem_out[31:0];
          // if(divide_by_0) begin
          //     WB_Bus_next[div].rd_data = '1;
          //     WB_Bus_next[div].rvfi.rd_wdata = ';
          // end
        end
      end
      if (ls_RS.valid  && !flush) begin
        WB_Bus_next[ls].is_branch = '0;
        WB_Bus_next[ls].valid = '1;
        WB_Bus_next[ls].rd_paddr = ls_RS.rd_use ? ls_RS.rd_paddr : '0;
        WB_Bus_next[ls].rd_addr = ls_RS.rd_use ? ls_RS.rd_addr : '0;
        WB_Bus_next[ls].ROB_entry = ls_RS.ROB_entry;
        WB_Bus_next[ls].rvfi = ls_RS.rvfi;
        WB_Bus_next[ls].pc_wdata = ls_RS.pc_next;
        WB_Bus_next[ls].rd_data = rd_ls_out;
        WB_Bus_next[ls].rvfi.rd_wdata = rd_ls_out;
        WB_Bus_next[ls].flush = ls_RS.branch_taken; 
      end
      if (br_RS.valid && !flush) begin
        WB_Bus_next[br].is_branch = '1;
        WB_Bus_next[br].valid = '1;
        WB_Bus_next[br].rd_paddr = br_RS.rd_use ? br_RS.rd_paddr : '0;
        WB_Bus_next[br].rd_addr = br_RS.rd_use ? br_RS.rd_addr : '0;
        
        WB_Bus_next[br].ROB_entry = br_RS.ROB_entry;
        WB_Bus_next[br].rvfi = br_RS.rvfi;
        WB_Bus_next[br].pc_wdata = br_RS.pc_next;
        WB_Bus_next[br].flush = br_RS.flush;
        // WB_Bus_next[br].rvfi.pc_wdata = br_pc_waddr;
        //         WB_Bus_next[br].rvfi.rd_wdata = br_rd_wdata;

        WB_Bus_next[br].rd_data = br_RS.rd_use ? br_RS.rd_wdata : '0;
      end
    end

    // for (integer unsigned i = 0; i< CDB_SIZE; i++) begin
    //     WB_Bus_next[i] = '{default: 0};
    // end 
    // end

endmodule : CDB