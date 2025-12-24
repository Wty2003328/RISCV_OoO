covergroup instr_cg with function sample (instr_t instr);
  // Easy covergroup to see that we're at least exercising
  // every opcode. Since opcode is an enum, this makes bins
  // for all its members.
  all_opcodes: coverpoint instr.s_type.opcode {
    bins imms = {7'b0010011}; bins regs = {7'b0110011}; bins luis = {7'b0110111};
    bins auipcs = {7'b0010111};
  }

  

  // Some simple coverpoints on various instruction fields.
  // Recognize that these coverpoints are inherently less useful
  // because they really make sense in the context of the opcode itself.
  all_funct7: coverpoint funct7_t'(instr.r_type.funct7);

  // TODO: Write the following coverpoints:

  // Check that funct3 takes on all possible values.
  // all_funct3 : coverpoint ... ;

  // Check that the rs1 and rs2 fields across instructions take on
  // all possible values (each register is touched).
  // all_regs_rs1 : coverpoint ... ;
  // all_regs_rs2 : coverpoint ... ;

  all_funct3: coverpoint instr.r_type.funct3 {
    bins all_vals[] = {[0 : 7]};
  }

  all_regs_rs1: coverpoint instr.r_type.rs1 {bins all_regs[] = {[0 : 31]};}

  all_regs_rs2: coverpoint instr.r_type.rs2 {bins all_regs[] = {[0 : 31]};}

  // Now, cross coverage takes in the opcode context to correctly
  // figure out the /actual/ coverage.
  // funct3_cross : cross instr.i_type.opcode, instr.i_type.funct3{

  //   // We want to ignore the cases where funct3 isn't relevant.

  //   // For example, for JAL, funct3 doesn't exist. Put it in an ignore_bins.
  //   ignore_bins JAL_FUNCT3 = funct3_cross with (instr.i_type.opcode == op_b_jal);

  //   // TODO:    What other opcodes does funct3 not exist for? Put those in
  //   // ignore_bins.
  //   ignore_bins LUI_FUNCT3 = funct3_cross with (instr.i_type.opcode == op_b_lui);
  //   ignore_bins AUIPC_FUNCT3 = funct3_cross with (instr.i_type.opcode == op_b_auipc);

  //   // Branch instructions use funct3, but only 6 of the 8 possible values
  //   // are valid. Ignore the other two -- don't add them into the coverage
  //   // report. In fact, if they're generated, that's an illegal instruction.
  //   illegal_bins BR_FUNCT3 = funct3_cross with
  //       (instr.i_type.opcode == op_b_br
  //       && !(instr.i_type.funct3 inside {branch_f3_beq, branch_f3_bne, branch_f3_blt, branch_f3_bge, branch_f3_bltu, branch_f3_bgeu}));

  //   // TODO: You'll also have to ignore some funct3 cases in JALR, LOAD, and
  //   // STORE. Write the illegal_bins/ignore_bins for those cases.
  //   illegal_bins JALR_FUNCT3 = funct3_cross with
  //       (instr.i_type.opcode == op_b_jalr && instr.i_type.funct3 != 3'b000);

  //   illegal_bins LOAD_FUNCT3 = funct3_cross with
  //           (instr.i_type.opcode == op_b_load &&
  //            !(instr.i_type.funct3 inside {
  //              load_f3_lb, load_f3_lh, load_f3_lw,
  //              load_f3_lbu, load_f3_lhu }));
  //   illegal_bins STORE_FUNCT3 = funct3_cross with
  //           (instr.i_type.opcode == op_b_store &&
  //            !(instr.i_type.funct3 inside {
  //              store_f3_sb, store_f3_sh, store_f3_sw }));
  // }

  // Coverpoint to make separate bins for funct7.
  coverpoint instr.r_type.funct7 {
    bins range[] = {[0 : $]}; ignore_bins not_in_spec = {[2 : 31], [33 : 127]};
  }

  // Cross coverage for funct7.
  funct7_cross : cross instr.r_type.opcode, instr.r_type.funct3, instr.r_type.funct7{

    // No opcodes except op_b_reg and op_b_imm use funct7, so ignore the rest.
    ignore_bins OTHER_INSTS = funct7_cross with
        (!(instr.r_type.opcode inside {op_b_reg, op_b_imm}));

    // TODO: Get rid of all the other cases where funct7 isn't necessary, or cannot
    // take on certain values.
    // op_b_imm only sll/sr use funct7
    ignore_bins IMM_OTHERS = funct7_cross with
            (instr.r_type.opcode == op_b_imm &&
             !( (instr.r_type.funct3 == arith_f3_sll && instr.r_type.funct7 == base)
             || (instr.r_type.funct3 == arith_f3_sr && instr.r_type.funct7 inside {base, variant})
             ));

    //   add/sub (funct3=000, base/variant)
    //   sll     (funct3=001, base)
    //   slt     (funct3=010, base)
    //   sltu    (funct3=011, base)
    //   xor     (funct3=100, base)
    //   srl/sra (funct3=101, base/variant)
    //   or      (funct3=110, base)
    //   and     (funct3=111, base)
    ignore_bins REG_OTHERS = funct7_cross with
            (instr.r_type.opcode == op_b_reg &&
             !(
               // add/sub
               ((instr.r_type.funct3 == arith_f3_add) &&
                (instr.r_type.funct7 inside {base, variant,extension})) ||
               // sll
               ((instr.r_type.funct3 == arith_f3_sll) &&
                (instr.r_type.funct7 inside {base,extension})) ||
               // slt
               ((instr.r_type.funct3 == arith_f3_slt) &&
                (instr.r_type.funct7 inside {base,extension})) ||
               // sltu
               ((instr.r_type.funct3 == arith_f3_sltu) &&
                (instr.r_type.funct7 inside {base,extension})) ||
               // xor
               ((instr.r_type.funct3 == arith_f3_xor) &&
                (instr.r_type.funct7 inside {base,extension})) ||
               // srl/sra
               ((instr.r_type.funct3 == arith_f3_sr) &&
                (instr.r_type.funct7 inside {base, variant,extension})) ||
               // or
               ((instr.r_type.funct3 == arith_f3_or) &&
                (instr.r_type.funct7 inside {base,extension})) ||
               // and
               ((instr.r_type.funct3 == arith_f3_and) &&
                (instr.r_type.funct7 inside {base,extension}))
             )
            );
  }

endgroup : instr_cg