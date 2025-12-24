// module mem_stage 
// import rv32i_types::*; 
// (
//     input logic           clk,
//     input logic           rst,
//     input logic           dmem_resp,
//     input logic   [31:0]  dmem_rdata,

//     output  logic   [31:0]  dmem_addr,
//     output  logic   [3:0]   dmem_rmask,
//     output  logic   [3:0]   dmem_wmask,
//     output  logic   [31:0]  dmem_wdata,

//     input  ex_mem_reg_t   ex_mem,
//     output mem_wb_reg_t   mem_wb,
//     // output logic          stalling_mem,

//     input  logic          stalling
// );
//     logic [63:0]    order_count;
//     logic   [6:0]       opcode;
//     logic   [2:0]       funct3;
//     logic   [31:0]      mem_addr;
//     logic   [31:0]      rd_v;
//     logic               valid;
//     logic               stalling_mem;
    
//     // Read from EX/MEM pipeline register
//     assign funct3 = ex_mem.funct3;
//     assign opcode = ex_mem.opcode;
//     assign mem_addr = ex_mem.instr_pkt.mem_addr; 
//     assign dmem_addr = ex_mem.instr_pkt.dmem_addr;
//     assign dmem_rmask = ex_mem.instr_pkt.dmem_rmask;
//     assign dmem_wmask = ex_mem.instr_pkt.dmem_wmask;
//     assign dmem_wdata = ex_mem.instr_pkt.dmem_wdata;
    
//     assign valid = (stalling) ? '0 : ex_mem.instr_pkt.valid;

//     always_comb begin
//         mem_wb = '0;
//         if (!rst) begin 
//             mem_wb.instr_pkt.valid = ex_mem.instr_pkt.valid;
//             mem_wb.instr_pkt.order = order_count;
//             // mem_wb.instr_pkt.order = ex_mem.instr_pkt.order;
//             mem_wb.instr_pkt.inst = ex_mem.instr_pkt.inst;
//             mem_wb.instr_pkt.pc = ex_mem.instr_pkt.pc;
//             mem_wb.instr_pkt.pc_next = ex_mem.instr_pkt.pc_next;
//             mem_wb.instr_pkt.rs1_s = ex_mem.instr_pkt.rs1_s;
//             mem_wb.instr_pkt.rs2_s = ex_mem.instr_pkt.rs2_s;
//             mem_wb.instr_pkt.rs1_v = ex_mem.instr_pkt.rs1_v;
//             mem_wb.instr_pkt.rs2_v = ex_mem.instr_pkt.rs2_v;
//             mem_wb.instr_pkt.regf_we = ex_mem.instr_pkt.regf_we;
//             mem_wb.instr_pkt.rd_s = ex_mem.instr_pkt.rd_s;
//             mem_wb.instr_pkt.rd_v = rd_v;
//             mem_wb.instr_pkt.mem_addr = ex_mem.instr_pkt.mem_addr;
//             mem_wb.instr_pkt.dmem_addr = ex_mem.instr_pkt.dmem_addr;
//             mem_wb.instr_pkt.dmem_rmask = ex_mem.instr_pkt.dmem_rmask;
//             mem_wb.instr_pkt.dmem_wmask = ex_mem.instr_pkt.dmem_wmask;
//             mem_wb.instr_pkt.dmem_wdata = ex_mem.instr_pkt.dmem_wdata;
//             mem_wb.instr_pkt.dmem_rdata = dmem_rdata;
//         end
//         mem_wb.stalling_mem = stalling_mem;
//     end

//     always_comb begin
//         rd_v = ex_mem.instr_pkt.rd_v;  
//         unique case (opcode)
//             op_b_load: begin
//                 if (dmem_resp) begin
//                     stalling_mem = 1'b0;
//                     unique case (funct3)
//                         load_f3_lb : rd_v = {{24{dmem_rdata[7 +8 *mem_addr[1:0]]}}, dmem_rdata[8 *mem_addr[1:0] +: 8 ]};
//                         load_f3_lbu: rd_v = {{24{1'b0}}                          , dmem_rdata[8 *mem_addr[1:0] +: 8 ]};
//                         load_f3_lh : rd_v = {{16{dmem_rdata[15+16*mem_addr[1]  ]}}, dmem_rdata[16*mem_addr[1]   +: 16]};
//                         load_f3_lhu: rd_v = {{16{1'b0}}                          , dmem_rdata[16*mem_addr[1]   +: 16]};
//                         load_f3_lw : rd_v = dmem_rdata;
//                         default    : rd_v = '0;
//                     endcase
//                 end else begin
//                     stalling_mem = 1'b1;
//                 end
//             end
//             op_b_store: begin
//                 if (dmem_resp) begin
//                     stalling_mem = 1'b0;
//                     rd_v = ex_mem.instr_pkt.rd_v;
//                 end else begin
//                     stalling_mem = 1'b1;
//                 end
//             end
//             default: begin
//                 stalling_mem = 1'b0;
//                 rd_v = ex_mem.instr_pkt.rd_v;  
//             end
//         endcase
//     end
//     always_ff @(posedge clk) begin
//         if (rst) begin
//             order_count<= '0;
//         end 
//         else begin
//             if (!stalling && mem_wb.instr_pkt.valid ) begin
//                 order_count <= order_count + 1;
//             end
//         end
//     end
// endmodule