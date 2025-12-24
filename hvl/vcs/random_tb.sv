//-----------------------------------------------------------------------------
// Title                 : random_tb
// Project               : ECE 411 mp_verif
//-----------------------------------------------------------------------------
// File                  : random_tb.sv
// Author                : ECE 411 Course Staff
//-----------------------------------------------------------------------------
// IMPORTANT: If you don't change the random seed, every time you do a `make run`
// you will run the /same/ random test. SystemVerilog calls this "random stability",
// and it's to ensure you can reproduce errors as you try to fix the DUT. Make sure
// to change the random seed or run more instructions if you want more extensive
// coverage.
//------------------------------------------------------------------------------
module random_tb
  import rv32i_types::*;
(
    mem_itf_banked.mem itf
);

  `include "randinst.svh"

  RandInst        gen = new();
  RandInst        gen2 = new();
  RandInst        gen3 = new();
  RandInst        gen4 = new();
  RandInst        gen5 = new();
  RandInst        gen6 = new();
  RandInst        gen7 = new();
  RandInst        gen8 = new();

  logic    [31:0] addr;


  assign itf.ready = '1;
  int burst_count = 0;

  // Do a bunch of LUIs to get useful register state.
  task init_register_state();
    itf.rvalid = 1'b0;

    for (int i = 0; i < 8; ++i) begin
      @(posedge itf.clk iff |itf.read);
      addr <= itf.addr;
      @(posedge itf.clk);
      @(posedge itf.clk);
      @(posedge itf.clk);
      gen.randomize() with {
        instr.j_type.opcode == op_b_lui;
        instr.j_type.rd == 5'(i * 8);
      };
      gen2.randomize() with {
        instr.i_type.opcode == op_b_imm;
        instr.i_type.rs1 == 5'(i * 8);
        instr.i_type.funct3 == arith_f3_add;
        instr.i_type.rd == 5'(i * 8);
      };
      itf.rdata[31:0] <= gen.instr.word;
      itf.rdata[63:32] <= gen2.instr.word;
      itf.rvalid <= 1'b1;
      itf.raddr <= addr;
      @(posedge itf.clk);
      gen3.randomize() with {
        instr.j_type.opcode == op_b_lui;
        instr.j_type.rd == 5'(i * 8 + 1);
      };
      gen4.randomize() with {
        instr.i_type.opcode == op_b_imm;
        instr.i_type.rs1 == 5'(i * 8 + 1);
        instr.i_type.funct3 == arith_f3_add;
        instr.i_type.rd == 5'(i * 8 + 1);
      };
      itf.rdata[31:0] <= gen3.instr.word;
      itf.rdata[63:32]  <= gen4.instr.word;

      @(posedge itf.clk);
      gen5.randomize() with {
        instr.j_type.opcode == op_b_lui;
        instr.j_type.rd == 5'(i * 8 + 2);
      };
      gen6.randomize() with {
        instr.i_type.opcode == op_b_imm;
        instr.i_type.rs1 == 5'(i * 8 + 2);
        instr.i_type.funct3 == arith_f3_add;
        instr.i_type.rd == 5'(i * 8 + 2);
      };
      itf.rdata[31:0] <= gen5.instr.word;
      itf.rdata[63:32]  <= gen6.instr.word;

      @(posedge itf.clk);
      gen7.randomize() with {
        instr.j_type.opcode == op_b_lui;
        instr.j_type.rd == 5'(i * 8 + 3);
      };
      gen8.randomize() with {
        instr.i_type.opcode == op_b_imm;
        instr.i_type.rs1 == 5'(i * 8 + 3);
        instr.i_type.funct3 == arith_f3_add;
        instr.i_type.rd == 5'(i * 8 + 3);
      };
      itf.rdata[31:0] <= gen7.instr.word;
      itf.rdata[63:32]  <= gen8.instr.word;

      @(posedge itf.clk) 
      itf.rvalid <= 1'b0;
      itf.raddr <= 'x;
      itf.rdata <= 'x;
    end
  endtask : init_register_state

  // Note that this memory model is not consistent! It ignores
  // writes and always reads out a random, valid instruction.
  task run_random_instrs();
    itf.rvalid = 1'b0;
    repeat (5000) begin
      // If no burst is happening, wait for read signal

      @(posedge itf.clk iff |itf.read);
      addr <= itf.addr;


      @(posedge itf.clk);
      @(posedge itf.clk);
      @(posedge itf.clk);
      @(posedge itf.clk);
      @(posedge itf.clk);
      @(posedge itf.clk);
      @(posedge itf.clk);

      // Always read out a valid instruction.
      gen.randomize();
      itf.rdata[31:0] <= gen.instr.word;
      gen2.randomize();
      itf.rdata[63:32] <= gen2.instr.word;

      itf.raddr <= addr;
      itf.rvalid <= 1'b1;

      // Once full burst is sent, clock and iterate to next burst
      @(posedge itf.clk);
      gen3.randomize();
      itf.rdata[31:0] <= gen3.instr.word;
      gen4.randomize();
      itf.rdata[63:32] <= gen4.instr.word;

      @(posedge itf.clk);
      gen5.randomize();
      itf.rdata[31:0] <= gen5.instr.word;
      gen6.randomize();
      itf.rdata[63:32] <= gen6.instr.word;

      @(posedge itf.clk);
      gen7.randomize();
      itf.rdata[31:0] <= gen7.instr.word;
      gen8.randomize();
      itf.rdata[63:32] <= gen8.instr.word;

      @(posedge itf.clk);
      itf.rvalid <= 1'b0;
      itf.rdata <= 'x;
      itf.raddr <= 'x;
    end
  endtask : run_random_instrs

  always @(posedge itf.clk iff !itf.rst) begin
    if ((|itf.read) || (|itf.write)) begin
      if ($isunknown(itf.addr)) begin
        $error("Memory Error: Address contained 'x");
        itf.error <= 1'b1;
      end
      // Only check for 16-bit alignment since instructions are
      // allowed to be at 16-bit boundaries due to JALR.
      if (itf.addr[0] != 1'b0) begin
        $error("Memory Error: Address is not 16-bit aligned");
        itf.error <= 1'b1;
      end
    end
  end

  // A single initial block ensures random stability.
  initial begin
    itf.rvalid = 1'b0;
    // Wait for reset.
    @(posedge itf.clk iff itf.rst == 1'b0);

    // Get some useful state into the processor by loading in a bunch of state.
    init_register_state();

    // Run!
    run_random_instrs();

    // Finish up
    $display("Random testbench finished!");
    $finish;
  end

endmodule : random_tb