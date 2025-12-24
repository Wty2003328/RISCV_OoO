// This class generates random valid RISC-V instructions to test your
// RISC-V cores.

class RandInst;
    // You will increment this number as you generate more random instruction
    // types. Once finished, NUM_TYPES should be 9, for each opcode type in
    // rv32i_opcode.
    localparam NUM_TYPES = 4;

    // Note that the 'instr_t' type is from ../pkg/types.sv, there are TODOs
    // you must complete there to fully define 'instr_t'.
    rand instr_t instr;
    rand bit [NUM_TYPES-1:0] instr_type;

    // Make sure we have an even distribution of instruction types.
    constraint solve_order_c { solve instr_type before instr; }

    // Hint/TODO: you will need another solve_order constraint for funct3
    // to get 100% coverage with 500 calls to .randomize().
    rand bit [2:0] funct3_temp;
    constraint solve_order_funct3_c { solve funct3_temp before instr; }
    constraint funct3_assignment_c {
        instr.i_type.funct3 == funct3_temp;
    }
    // Pick one of the instruction types.
    constraint instr_type_c {
        $countones(instr_type) == 1; // Ensures one-hot.
    }

    // Constraints for actually generating instructions, given the type.
    // Again, see the instruction set listings to see the valid set of
    // instructions, and constrain to meet it. Refer to ../pkg/types.sv
    // to see the typedef enums.
    rand bit [31:0] sum;
    rand bit [31:0] reg_data [32];
    rand bit [31:0] rs1_val;
    constraint instr_c {
        // Reg-imm instructions
        instr_type[0] -> {
            instr.i_type.opcode == op_b_imm;
            // Implies syntax: if funct3 is arith_f3_sr, then funct7 must be
            // one of two possibilities.
            instr.i_type.funct3 == arith_f3_sr -> {
                // Use r_type here to be able to constrain funct7.
                instr.r_type.funct7 inside {base, variant};
            }

            // This if syntax is equivalent to the implies syntax above
            // but also supports an else { ... } clause.
            if (instr.i_type.funct3 == arith_f3_sll) { // slli
                instr.r_type.funct7 == base;
            }
        }

        // Reg-reg instructions
        instr_type[1] -> {
                // TODO: Fill this out!
            instr.r_type.opcode == op_b_reg;
            // instr.r_type.funct3 inside {}
            instr.r_type.funct3 inside {arith_f3_sll, arith_f3_slt, arith_f3_sltu, 
            arith_f3_xor, arith_f3_or, arith_f3_and} -> {
                // Use r_type here to be able to constrain funct7.
                instr.r_type.funct7 inside {base, extension};
            }
        
            instr.r_type.funct3 inside {arith_f3_add, arith_f3_sr} -> {
                instr.r_type.funct7 inside {base, variant, extension};
            }
        }

        // Store instructions -- these are easy to constrain!
        // instr_type[2] -> {
        //     instr.s_type.opcode == op_b_store;
        //     instr.s_type.funct3 inside {store_f3_sb, store_f3_sh, store_f3_sw};
        //     // instr.s_type.rs1 == 5'b0;
        //     // instr.s_type.imm_s_bot % 4 == 0;
        //     if(instr.s_type.funct3 == store_f3_sh){
        //         rs1_val == reg_data[instr.s_type.rs1];
                
        //         (instr.s_type.imm_s_bot + rs1_val) & 32'b1 == 32'b0;
        //         sum == {instr.s_type.imm_s_top,instr.s_type.imm_s_bot} + rs1_val ;
        //     }
        //     if(instr.s_type.funct3 == store_f3_sw){
        //         rs1_val == reg_data[instr.s_type.rs1];
                
        //         (instr.s_type.imm_s_bot + rs1_val) & 32'h3 == 32'b0;
        //         sum == {instr.s_type.imm_s_top,instr.s_type.imm_s_bot} + rs1_val ;
        //     }
        // }

        // // // Load instructions
        // instr_type[3] -> {
        //     instr.i_type.opcode == op_b_load;
        // // TODO: Constrain funct3 as well.
        //     instr.i_type.funct3 inside {load_f3_lh, load_f3_lb, load_f3_lw, load_f3_lbu, load_f3_lhu};
        //     // instr.i_type.rs1 == 5'b0;
        //     // instr.i_type.i_imm % 4 == 0;
        //     if(instr.i_type.funct3 inside {load_f3_lh, load_f3_lhu}){
        //         rs1_val == reg_data[instr.i_type.rs1];
        //         (instr.i_type.i_imm  + rs1_val) & 32'h1 == 32'h0;
        //         sum == instr.i_type.i_imm  + rs1_val;
        //     }
        //     if(instr.i_type.funct3 inside {load_f3_lw}){
        //         rs1_val == reg_data[instr.i_type.rs1];
        //         (instr.i_type.i_imm  + rs1_val) & 32'h3 == 32'h0;
        //         sum == instr.i_type.i_imm  + rs1_val;
        //     }
        //     // // else{
        //     //     instr.i_type.rs1 == 5'b0;
        //     // instr.i_type.i_imm % 4 == 0;
        //     // // }
        // }

        // // TODO: Do all 9 types!
        // instr_type[4] -> {
        //     instr.b_type.opcode == op_b_br;
        //     instr.b_type.funct3 inside {branch_f3_beq, branch_f3_bne, branch_f3_blt, branch_f3_bge, branch_f3_bltu, branch_f3_bgeu};
        // }

        // instr_type[5] -> {
        //     instr.i_type.opcode == op_b_jalr;
        //     instr.i_type.funct3 inside {3'b000};
        // }

        // instr_type[6] -> {
        //     instr.j_type.opcode == op_b_jal;
        // }

        instr_type[2] -> {
            instr.j_type.opcode ==op_b_auipc;
        }

        instr_type[3] -> {
            instr.j_type.opcode == op_b_lui;
        }
    }

    `include "instr_cg.svh"

    // Constructor, make sure we construct the covergroup.
    function new();
        instr_cg = new();
    endfunction : new

    // Whenever randomize() is called, sample the covergroup. This assumes
    // that every generated random instruction are send it into the CPU.
    function void post_randomize();
        instr_cg.sample(this.instr);
    endfunction : post_randomize

    // A nice part of writing constraints is that we get constraint checking
    // for free -- this function will check if a bitvector is a valid RISC-V
    // instruction (assuming you have written all the relevant constraints).
    function bit verify_valid_instr(instr_t inp);
        bit valid = 1'b0;
        this.instr = inp;
        for (int i = 0; i < NUM_TYPES; ++i) begin
            this.instr_type = NUM_TYPES'(1 << i);
            if (this.randomize(null)) begin
                valid = 1'b1;
                break;
            end
        end
        return valid;
    endfunction : verify_valid_instr

    function void set_reg_data(input logic [31:0] ext_reg_data[32]);
      for (int i = 0; i < 32; i++) begin
         reg_data[i] = ext_reg_data[i];
      end
   endfunction

endclass : RandInst