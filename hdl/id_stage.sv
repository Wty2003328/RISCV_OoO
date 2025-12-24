module id_stage 
import rv32i_types::*; 
(
    // input logic clk,
    input logic rst,

    // input from fetch stage
    // input if_id_reg_t if_id,
    input  fetch_pkt_t fifo_out, 
    input  logic        predict_taken,            // flush coming from ROB
    input  logic [31:0] pc_target,               // target address of branch
    // output of decode stage to rename
    output rvfi_t  rvfi,
    output instr_pkt_t instr
    
    // input from cpu.sv
    // input logic           stalling,
    // input logic           fifo_enable
);

    logic   [31:0]  pc;
    logic   [31:0]  pc_next;
    logic   [31:0]  inst;
    logic   [63:0]  order;

    logic   [2:0]   funct3;
    logic   [6:0]   funct7;
    logic   [6:0]   opcode;
    logic   [31:0]  i_imm, s_imm, b_imm, u_imm, j_imm;
    logic   [4:0]   rs1_addr, rs2_addr, rd_addr;
    logic   [31:0]  rs1_v, rs2_v;
    logic   [31:0]  imm;
    logic   [3:0]   aluop;
    logic           regf_we;
    alu_m1_sel_t    alu_m1_sel;
    alu_m2_sel_t    alu_m2_sel;

    logic   [1:0]   mul_sel, div_sel;
    logic           ls_sel;

    logic           valid;
    logic           rs1_use;
    logic           rs2_use;
    logic           imm_use;
    logic           rd_use;

    CDB_ind_t       CDB_ind; // to indicate which function unit

    // Read from IF/ID pipeline register
    assign inst = fifo_out.inst;
    assign pc = fifo_out.pc;
    assign pc_next = fifo_out.pc+32'd4;
    assign order = fifo_out.order;

    // Decode instruction fields and Immediate generation
    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];
    assign opcode = inst[6:0];
    assign i_imm  = {{21{inst[31]}}, inst[30:20]};
    assign s_imm  = {{21{inst[31]}}, inst[30:25], inst[11:7]};
    assign b_imm  = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    assign u_imm  = {inst[31:12], 12'h000};
    assign j_imm  = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
    assign rs1_addr  = inst[19:15];
    assign rs2_addr  = inst[24:20];
    assign rd_addr   = inst[11:7];

    // assign valid = (!stalling && fifo_enable) ?  '1: '0; // stall or FIFO data not ready


    // always_comb


    // Store into ID/DP pipeline register
    always_comb begin
        
        rvfi = '0;
        instr = '0;
        if (!rst) begin

            // rvfi package
            rvfi.valid = valid;
            rvfi.order = order;
            rvfi.inst = inst;
            rvfi.rs1_addr = rs1_use ? rs1_addr : '0;
            rvfi.rs2_addr = rs2_use ? rs2_addr : '0;
            rvfi.rs1_rdata = 32'b0;
            rvfi.rs2_rdata = 32'b0;
            rvfi.rd_addr = rd_use ? rd_addr : '0;
            rvfi.rd_wdata = 32'b0;
            rvfi.pc_rdata = pc;
            rvfi.pc_wdata = pc_next;
            rvfi.mem_addr = '0;
            rvfi.mem_rmask = '0;
            rvfi.mem_wmask = '0;
            rvfi.mem_rdata = '0;
            rvfi.mem_wdata = '0;

            // instruction package
            instr.valid = valid;
            instr.inst = inst;
            instr.funct3 = funct3;
            instr.opcode = opcode;
            instr.imm = imm;
            instr.aluop = aluop;
            instr.alu_m1_sel = alu_m1_sel;
            instr.alu_m2_sel = alu_m2_sel;
            instr.rs1_addr = rs1_addr;
            instr.rs1_paddr = 'x;
            instr.rs2_addr = rs2_addr;
            instr.rs2_paddr = 'x;
            instr.rs1_v = 32'b0;
            instr.rs2_v = 32'b0;
            // instr.regf_we = regf_we;
            instr.rd_addr = rd_addr;
            instr.rd_paddr = 'x;
            instr.rd_v = 32'b0;
            instr.rs1_use = rs1_use;
            instr.rs2_use = rs2_use;
            instr.imm_use = imm_use;
            instr.rd_use = rd_use;
            instr.mul_sel = mul_sel;
            instr.div_sel = div_sel;
            instr.CDB_ind = CDB_ind;
            instr.pc = pc;
            instr.pc_next = pc_next;
            instr.ls_sel = ls_sel;
            instr.branch_taken = predict_taken;
            instr.branch_target =  pc_target;
        end
    end

    always_comb begin
        // valid = (!stalling && fifo_enable) ?  '1: '0; // stall or FIFO data not ready
        valid = '1;
        if(instr == '1)
            valid = '0;
        mul_sel = '0;
        div_sel = '0;
        ls_sel = '0;
        unique case (opcode)
            op_b_lui: begin
                imm = u_imm;
                imm_use = 1'b1;
                // regf_we = 1'b1;
                rd_use = 1'b1;
                rs1_use = 1'b0;
                rs2_use = 1'b0;
                alu_m1_sel = rs1_out;
                alu_m2_sel = imm_out;
                aluop = alu_op_add;
                CDB_ind = alu;
            end
            op_b_auipc: begin
                imm = u_imm;
                imm_use = 1'b1;
                // regf_we = 1'b1;
                rd_use = 1'b1;
                rs1_use = 1'b0;
                rs2_use = 1'b0;
                alu_m1_sel = pc_out;
                alu_m2_sel = imm_out;
                aluop = alu_op_add;
                CDB_ind = alu;
            end
            op_b_load:  begin
                imm = i_imm;
                imm_use = 1'b1;
                // regf_we = 1'b1;
                rd_use = 1'b1;
                rs1_use = 1'b1;
                rs2_use = 1'b1;
                alu_m1_sel = rs1_out;
                alu_m2_sel = imm_out;
                ls_sel = '0;
                aluop = alu_op_add;
                CDB_ind = ls;
            end
            op_b_store: begin
                imm = s_imm;
                imm_use = 1'b1;
                // regf_we = 1'b0;
                rd_use = 1'b0;
                rs1_use = 1'b1;
                rs2_use = 1'b1; // used to compute wdata in ex_stage
                alu_m1_sel = rs1_out;
                alu_m2_sel = imm_out;
                ls_sel = '1;
                aluop = alu_op_add;
                CDB_ind = ls;
            end
            op_b_imm: begin
                imm = i_imm;
                imm_use = 1'b1;
                // regf_we = 1'b1;
                rd_use = 1'b1;
                rs1_use = 1'b1;
                rs2_use = 1'b0;
                alu_m1_sel = rs1_out;
                alu_m2_sel = imm_out;
                if (funct3 == arith_f3_sr) begin
                    aluop = {funct3, funct7[5]};
                end else begin 
                    aluop = {funct3, 1'b0};
                end
                CDB_ind = alu;
            end
            op_b_reg: begin
                imm = 32'b0;
                imm_use = 1'b0;
                // regf_we = 1'b1;
                rd_use = 1'b1;
                rs1_use = 1'b1;
                rs2_use = 1'b1;
                alu_m1_sel = rs1_out;
                alu_m2_sel = rs2_out;
                if (funct7[0]) begin // MUL, DIV, REM
                    aluop = '0;
                    mul_sel = funct3[1:0];
                    div_sel = funct3[1:0]; 
                    CDB_ind = funct3[2] ? div : mul;               
                end else begin
                    aluop = {funct3, funct7[5]};
                    CDB_ind = alu;
                end
            end
            op_b_jal: begin
                imm = j_imm;
                imm_use = 1'b1;
                // regf_we = 1'b1;
                rd_use = 1'b1;
                rs1_use = 1'b0;
                rs2_use = 1'b0;
                alu_m1_sel = pc_out;  // pc_next = pc+j_imm
                alu_m2_sel = imm_out;
                aluop = alu_op_add;
                CDB_ind = br;
                mul_sel = 2'b00;
            end
            op_b_jalr: begin
                imm = i_imm;
                imm_use = 1'b1;
                // regf_we = 1'b1;
                rd_use = 1'b1;
                rs1_use = 1'b1;
                rs2_use = 1'b0;
                alu_m1_sel = rs1_out;  // pc_next = (rs1_v+i_imm) & 32'hfffffffe
                alu_m2_sel = imm_out;
                aluop = alu_op_add;
                CDB_ind = br;
                mul_sel = 2'b01;
            end
            op_b_br: begin
                imm = b_imm;
                imm_use = 1'b1;
                // regf_we = 1'b0;
                rd_use = 1'b0;
                rs1_use = 1'b1;
                rs2_use = 1'b1;
                mul_sel = 2'b10;
                alu_m1_sel = rs1_out;  // pc_next = (pc+b_imm)
                alu_m2_sel = rs2_out;
                aluop = '0;
                CDB_ind = br;
            end
            default: begin
                valid = 1'b0;
                imm = 32'b0;
                imm_use = 1'b0;
                // regf_we = 1'b0;
                rd_use = 1'b0;
                rs1_use = 1'b0;
                rs2_use = 1'b0;
                alu_m1_sel = rs1_out;
                alu_m2_sel = rs2_out;
                aluop = '0;
                mul_sel = '0;
                div_sel = '0;
                ls_sel = '0;
                CDB_ind = other;
            end
        endcase
    end

endmodule