// Input from reservation station
module ALU  
import rv32i_types::*;
import params::*;
(
    input   logic           rst,
    input   logic           clk,
    input   RS_t            ALU_RS_next,

    // to PRF
    output  logic   [P_WIDTH - 1: 0]    rs1_paddr,
    output  logic   [P_WIDTH - 1: 0]    rs2_paddr,
    input   logic   [31:0]  p1_data,
    input   logic   [31:0]  p2_data,


    output  logic   [31:0]  aluout,
    output  RS_t            ALU_RS_out
);
    
    logic           valid;
    // logic   [63:0]  order;
    logic   [31:0]  pc;
    // logic   [31:0]  pc_next;
    logic   [31:0]  rs1_v;
    logic   [31:0]  rs2_v;
    logic   [31:0]  imm;
    logic   [31:0]  a;
    logic   [31:0]  b;
    logic   [3:0]   aluop;
    // logic           regf_we;
    // logic   [4:0]   rd_s;
    // logic   [31:0]  rd_v;
    alu_m1_sel_t    alu_m1_sel;
    alu_m2_sel_t    alu_m2_sel;
    // logic   [6:0]   opcode;
    logic   [2:0]   funct3;
    logic   [31:0]  p1_data_save, p2_data_save;

    // logic   [31:0]  aluout;
    logic           br;
    logic           br_en;

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    // RS_t    ALU_RS;

    always_ff @(posedge clk) begin
        if(rst)
            ALU_RS_out <= '0;
        else
            ALU_RS_out <= ALU_RS_next;
            ALU_RS_out.rvfi.rs1_rdata <= p1_data;
            ALU_RS_out.rvfi.rs2_rdata <= p2_data;
            p1_data_save <= p1_data;
            p2_data_save <= p2_data;
    end

    // check if use rs1/rs2, then pass
    assign rs1_paddr = ALU_RS_next.rs1_use ? ALU_RS_next.rs1_paddr : '0;
    assign rs2_paddr = ALU_RS_next.rs2_use ? ALU_RS_next.rs2_paddr : '0;
    // assign ALU_RS_out.rvfi.rs1_rdata = p1_data;
    // assign ALU_RS_out.rvfi.rs2_rdata = p2_data;
    assign rs1_v = p1_data_save;
    assign rs2_v = p2_data_save;
    assign pc = ALU_RS_out.pc;

    // assign regf_we = id_ex.instr_pkt.regf_we;
    // assign order = id_ex.instr_pkt.order;
    // assign rd_s = id_ex.instr_pkt.rd_s;

    assign imm = ALU_RS_out.imm; // WILL NEED TO CHANGE IF imm CHANGES
    assign aluop = ALU_RS_out.aluop;
    assign alu_m1_sel = ALU_RS_out.alu_m1_sel;
    assign alu_m2_sel = ALU_RS_out.alu_m2_sel;
    assign funct3 = ALU_RS_out.funct3;

    // assign valid = (stalling_if) ? '0 :id_ex.instr_pkt.valid;

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    // Store into EX/MEM pipeline register
//     always_comb begin
//         // ex_mem = '0;
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
    
    // ALU
    always_comb begin
        unique case (alu_m1_sel)
            rs1_out: a = rs1_v;
            pc_out: a = pc;
        endcase
        unique case (alu_m2_sel)
            rs2_out: b = rs2_v;
            imm_out: b = imm;
        endcase
    end

    always_comb begin
        unique case (aluop)
            alu_op_add:     aluout = au +   bu;
            alu_op_sub:     aluout = au -   bu;
            alu_op_slti:    aluout = unsigned'((as <  bs) ? 1:0);
            alu_op_sltiu:   aluout = unsigned'((au <  bu) ? 1:0);
            alu_op_xor:     aluout = au ^   bu;
            alu_op_sll:     aluout = au <<  bu[4:0];
            alu_op_or :     aluout = au |   bu;
            alu_op_and:     aluout = au &   bu;
            alu_op_srl:     aluout = au >>  bu[4:0];
            alu_op_sra:     aluout = unsigned'(as >>> bu[4:0]);
            default   :     aluout = 'x;
        endcase
    end


 

endmodule: ALU