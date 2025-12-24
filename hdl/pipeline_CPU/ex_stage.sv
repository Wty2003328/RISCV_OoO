// module ex_stage 
// import rv32i_types::*; 
// (
//     input   logic           rst,

//     output  logic   [31:0]  dmem_addr,
//     output  logic   [3:0]   dmem_rmask,
//     output  logic   [3:0]   dmem_wmask,
//     output  logic   [31:0]  dmem_wdata,

//     input   id_ex_reg_t     id_ex,
//     output  ex_mem_reg_t    ex_mem,

//     input   logic           stalling
// );
    
//     logic           valid;
//     logic   [63:0]  order;
//     logic   [31:0]  pc;
//     logic   [31:0]  pc_next;
//     logic   [31:0]  rs1_v;
//     logic   [31:0]  rs2_v;
//     logic   [31:0]  imm;
//     logic   [31:0]  a;
//     logic   [31:0]  b;
//     logic   [3:0]   aluop;
//     logic           regf_we;
//     logic   [4:0]   rd_s;
//     logic   [31:0]  rd_v;
//     alu_m1_sel_t    alu_m1_sel;
//     alu_m2_sel_t    alu_m2_sel;
//     logic   [6:0]   opcode;
//     logic   [2:0]   funct3;
//     logic   [31:0]  mem_addr;

//     logic   [31:0]  aluout;
//     logic           br;
//     logic           br_en;

//     logic signed   [31:0] as;
//     logic signed   [31:0] bs;
//     logic unsigned [31:0] au;
//     logic unsigned [31:0] bu;

//     // Read from ID/EX pipeline register
//     assign pc = id_ex.instr_pkt.pc;
//     assign rs1_v = id_ex.instr_pkt.rs1_v;
//     assign rs2_v = id_ex.instr_pkt.rs2_v;
//     assign regf_we = id_ex.instr_pkt.regf_we;
//     assign order = id_ex.instr_pkt.order;
//     assign rd_s = id_ex.instr_pkt.rd_s;

//     assign imm = id_ex.imm;
//     assign aluop = id_ex.aluop;
//     assign alu_m1_sel = id_ex.alu_m1_sel;
//     assign alu_m2_sel = id_ex.alu_m2_sel;
//     assign opcode = id_ex.opcode;
//     assign funct3 = id_ex.funct3;

//     assign valid = (stalling) ? '0 :id_ex.instr_pkt.valid;

//     assign as =   signed'(a);
//     assign bs =   signed'(b);
//     assign au = unsigned'(a);
//     assign bu = unsigned'(b);

//     // Store into EX/MEM pipeline register
//     always_comb begin
//         ex_mem = '0;
//         if (!rst) begin
//             ex_mem.instr_pkt.valid = id_ex.instr_pkt.valid;
//             ex_mem.instr_pkt.order = id_ex.instr_pkt.order;
//             ex_mem.instr_pkt.inst = id_ex.instr_pkt.inst;
//             ex_mem.instr_pkt.pc = id_ex.instr_pkt.pc;
//             ex_mem.instr_pkt.pc_next = pc_next;
//             ex_mem.instr_pkt.rs1_s = id_ex.instr_pkt.rs1_s;
//             ex_mem.instr_pkt.rs2_s = id_ex.instr_pkt.rs2_s;
//             ex_mem.instr_pkt.rs1_v = id_ex.instr_pkt.rs1_v;
//             ex_mem.instr_pkt.rs2_v = id_ex.instr_pkt.rs2_v;
//             ex_mem.instr_pkt.regf_we = id_ex.instr_pkt.regf_we;
//             ex_mem.instr_pkt.rd_s = id_ex.instr_pkt.rd_s;
//             ex_mem.instr_pkt.rd_v = rd_v;
//             ex_mem.instr_pkt.mem_addr = mem_addr;       // used to calculate and monitor
//             ex_mem.instr_pkt.dmem_addr = dmem_addr;     // used for memory interface
//             ex_mem.instr_pkt.dmem_rmask = dmem_rmask;
//             ex_mem.instr_pkt.dmem_wmask = dmem_wmask;
//             ex_mem.instr_pkt.dmem_wdata = dmem_wdata;

//             ex_mem.opcode = opcode;
//             ex_mem.funct3 = funct3;
//             ex_mem.br     = br;
//         end
// end
    
//     // ALU
//     always_comb begin
//         unique case (alu_m1_sel)
//             rs1_out: a = rs1_v;
//             pc_out: a = pc;
//         endcase
//         unique case (alu_m2_sel)
//             rs2_out: b = rs2_v;
//             imm_out: b = imm;
//         endcase
//     end

//     always_comb begin
//         unique case (aluop)
//             alu_op_add:     aluout = au +   bu;
//             alu_op_sub:     aluout = au -   bu;
//             alu_op_slti:    aluout = unsigned'((as <  bs) ? 1:0);
//             alu_op_sltiu:   aluout = unsigned'((au <  bu) ? 1:0);
//             alu_op_xor:     aluout = au ^   bu;
//             alu_op_sll:     aluout = au <<  bu[4:0];
//             alu_op_or :     aluout = au |   bu;
//             alu_op_and:     aluout = au &   bu;
//             alu_op_srl:     aluout = au >>  bu[4:0];
//             alu_op_sra:     aluout = unsigned'(as >>> bu[4:0]);
//             default   :     aluout = 'x;
//         endcase
//     end

//     // Branch condition
//     always_comb begin
//         unique case (funct3)
//             branch_f3_beq : br_en = (au == bu);
//             branch_f3_bne : br_en = (au != bu);
//             branch_f3_blt : br_en = (as <  bs);
//             branch_f3_bge : br_en = (as >=  bs);
//             branch_f3_bltu: br_en = (au <  bu);
//             branch_f3_bgeu: br_en = (au >=  bu);
//             default       : br_en = 1'bx;
//         endcase
//     end

//     // Branch
//     always_comb begin
//         rd_v = aluout;
//         pc_next = id_ex.instr_pkt.pc_next;
//         br = '0;
//         if (valid) begin
//             unique case (opcode)
//                 op_b_jal: begin
//                     rd_v = pc + 'd4;
//                     pc_next = aluout;
//                     br = '1;
//                 end
//                 op_b_jalr: begin
//                     rd_v = pc + 'd4;
//                     pc_next = aluout & 32'hfffffffe;
//                     br = '1;
//                 end
//                 op_b_br: begin
//                     rd_v = aluout; // default
//                     br = br_en;
//                     if (br) begin
//                         pc_next = pc + imm;
//                     end else begin
//                         pc_next = id_ex.instr_pkt.pc_next;
//                     end
//                 end
//                 default: begin
//                     rd_v = aluout;
//                     pc_next = id_ex.instr_pkt.pc_next;
//                     br = '0;
//                 end
//             endcase
//         end
//     end
    
//     // I am going to change

//     // Load & Store
//     always_comb begin
//         mem_addr = '0;      // used to calculate
//         dmem_addr =  '0;    // output to memory interface
//         dmem_rmask = '0;
//         dmem_wmask = '0;
//         dmem_wdata = '0;
//         if (valid) begin
//             unique case (opcode)
//                 op_b_load: begin
//                     mem_addr = aluout;
//                     dmem_addr = mem_addr & 32'hFFFFFFFC;
//                     unique case (funct3)
//                         load_f3_lb, load_f3_lbu: dmem_rmask = 4'b0001 << mem_addr[1:0];
//                         load_f3_lh, load_f3_lhu: dmem_rmask = 4'b0011 << mem_addr[1:0];
//                         load_f3_lw             : dmem_rmask = 4'b1111;
//                         default                : dmem_rmask = '0;
//                     endcase
//                 end
//                 op_b_store: begin
//                     mem_addr = aluout;
//                     dmem_addr = mem_addr & 32'hFFFFFFFC;
//                     unique case (funct3)
//                         store_f3_sb: dmem_wmask = 4'b0001 << mem_addr[1:0];
//                         store_f3_sh: dmem_wmask = 4'b0011 << mem_addr[1:0];
//                         store_f3_sw: dmem_wmask = 4'b1111;
//                         default    : dmem_wmask = '0;
//                     endcase
//                     unique case (funct3)
//                         store_f3_sb: dmem_wdata[8 *mem_addr[1:0] +: 8 ] = rs2_v[7 :0];
//                         store_f3_sh: dmem_wdata[16*mem_addr[1]   +: 16] = rs2_v[15:0];
//                         store_f3_sw: dmem_wdata = rs2_v;
//                         default    : dmem_wdata = '0;
//                     endcase
//                 end
//                 default: begin
//                     mem_addr = '0;
//                     dmem_addr =  '0;
//                     dmem_rmask = '0;
//                     dmem_wmask = '0;
//                     dmem_wdata = '0;
//                 end
//             endcase
//         end
//     end

// endmodule