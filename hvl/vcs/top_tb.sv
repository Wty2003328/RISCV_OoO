module top_tb;

  timeunit 1ps; timeprecision 1ps;

  int clock_half_period_ps;
  initial begin
    $value$plusargs("CLOCK_PERIOD_PS_ECE411=%d", clock_half_period_ps);
    clock_half_period_ps = clock_half_period_ps / 2;
  end

  bit clk;
  always #(clock_half_period_ps) clk = ~clk;
  bit rst;

  initial begin
    $fsdbDumpfile("dump.fsdb");
    if ($test$plusargs("NO_DUMP_ALL_ECE411")) begin
      $fsdbDumpvars(0, dut, "+all");
      $fsdbDumpoff();
    end else begin
      $fsdbDumpvars(0, "+all");
    end
    rst = 1'b1;
    repeat (2) @(posedge clk);
    rst <= 1'b0;
  end

  `include "top_tb.svh"

endmodule

// module top_tb;
//   //---------------------------------------------------------------------------------
//   // Waveform generation
//   //---------------------------------------------------------------------------------
//   initial begin
//     $fsdbDumpfile("dump.fsdb");
//     $fsdbDumpvars(0, "+all");
//   end

//   //---------------------------------------------------------------------------------
//   // DUT I/O signals
//   //---------------------------------------------------------------------------------
//   logic clk;
//   logic rst;
//   logic enq;
//   logic deq;
//   logic [7:0] data_in;
//   logic [7:0] data_out;
//   logic full;
//   logic empty;

//   //---------------------------------------------------------------------------------
//   // Reference model (scoreboard): a SystemVerilog dynamic array
//   //---------------------------------------------------------------------------------
//   byte ref_queue[$];

//   //---------------------------------------------------------------------------------
//   // Clock generation: 10ns period
//   //---------------------------------------------------------------------------------
//   initial clk = 1'b0;
//   always #5 clk = ~clk;

//   //---------------------------------------------------------------------------------
//   // Reset generation
//   //---------------------------------------------------------------------------------
//   initial begin
//     rst     = 1'b1;
//     enq     = 1'b0;
//     deq     = 1'b0;
//     data_in = '0;

//     // Release reset after a few clock edges
//     repeat (5) @(posedge clk);
//     rst = 1'b0;
//   end

//   //---------------------------------------------------------------------------------
//   // Instantiate the DUT
//   //---------------------------------------------------------------------------------
//   FIFO #(
//       .WIDTH     (8),
//       .DEPTH     (16),
//       .ADDR_WIDTH($clog2(16))
//   ) dut (
//       .clk     (clk),
//       .rst     (rst),
//       .enq     (enq),
//       .deq     (deq),
//       .data_in (data_in),
//       .data_out(data_out),
//       .full    (full),
//       .empty   (empty)
//   );

//   //---------------------------------------------------------------------------------
//   // Revised Tasks
//   // 
//   // The main change: we wait one clock cycle before checking `full` or `empty`
//   // to ensure the DUT's internal pointers have already settled.
//   //---------------------------------------------------------------------------------

//   // Push one byte when not full
//   task do_push(byte data);
//     begin
//       // Wait *one* clock edge so that 'full' is updated from any previous operation
//       @(posedge clk);

//     //   if (!full) begin
//         enq     <= 1'b1;
//         data_in <= data;
//         @(posedge clk);  // drive the enqueue on this clock
//         enq     <= 1'b0;
//         data_in <= 'X;

//         // Update reference queue
//         if (!full) begin
//             $display("[TB] Attempted push while FULL. DUT should reject, reference will not store.");
//             ref_queue.push_back(data);
//         end

//     end
//   endtask : do_push


//   // Pop one byte when not empty
//   task do_pop();
//     byte expected;
//     begin
//       // Again, wait one clock so 'empty' is stable from the last update
//       @(posedge clk);

//       if (!empty) begin
//         // The expected data is the front of the reference queue
//         expected = ref_queue[0];

//         deq <= 1'b1;
//         @(posedge clk);  // do the actual dequeue
//         deq <= 1'b0;

//         // Check data_out vs. reference
//         if (data_out !== expected) begin
//           $error("[TB] DUT data_out = 0x%0h, but expected = 0x%0h", data_out, expected);
//           $fatal;
//         end
//         ref_queue.pop_front();
//       end else begin
//         $display("[TB] Attempted pop while EMPTY. Data_out is don't care, no check performed.");
//         deq <= 1'b1;
//         @(posedge clk);
//         deq <= 1'b0;
//       end
//     end
//   endtask : do_pop

//   //---------------------------------------------------------------------------------
//   // 1) PUSH-ONLY test
//   //---------------------------------------------------------------------------------
//   task push_only_test(int num_pushes);
//     begin
//       $display("[TB] Starting push_only_test with %0d pushes.", num_pushes);
//       for (int i = 0; i < num_pushes; i++) begin
//         byte rand_data;
//         std::randomize(rand_data);
//         do_push(rand_data);
//       end
//       $display("[TB] Completed push_only_test.");
//     end
//   endtask : push_only_test

//   //---------------------------------------------------------------------------------
//   // 2) POP-ONLY test
//   //---------------------------------------------------------------------------------
//   task pop_only_test(int num_to_fill, int num_to_pop);
//     begin
//       $display("[TB] Starting pop_only_test. Filling with %0d items, then popping %0d.",
//                num_to_fill, num_to_pop);

//       // Fill FIFO first
//       for (int i = 0; i < num_to_fill; i++) begin
//         byte rand_data;
//         std::randomize(rand_data);
//         do_push(rand_data);
//       end

//       // Now pop
//       for (int j = 0; j < num_to_pop; j++) begin
//         do_pop();
//       end
//       $display("[TB] Completed pop_only_test.");
//     end
//   endtask : pop_only_test

//   //---------------------------------------------------------------------------------
//   // 3) ALTERNATING push/pop test
//   //---------------------------------------------------------------------------------
//   task alternating_test(int iterations);
//     begin
//       $display("[TB] Starting alternating_test with %0d iterations (push+pop).", iterations);
//       for (int i = 0; i < iterations; i++) begin
//         byte rand_data;
//         std::randomize(rand_data);

//         // Push
//         do_push(rand_data);

//         // Pop
//         do_pop();
//       end
//       $display("[TB] Completed alternating_test.");
//     end
//   endtask : alternating_test

//   //---------------------------------------------------------------------------------
//   // 4) RANDOM push/pop test
//   //---------------------------------------------------------------------------------
//   task random_test(int operations);
//     begin
//       $display("[TB] Starting random_test with %0d operations.", operations);
//       for (int i = 0; i < operations; i++) begin
//         // static bit rand_dir = 1'($urandom_range(0, 1));  // 0=pop, 1=push
//         bit rand_dir;
//         byte rand_data;
//         std::randomize(rand_dir);
//         // byte rand_data;

//         if (rand_dir) begin
//             // $display("pushed");
//           // do_push
//           std::randomize(rand_data);
//           do_push(rand_data);
//         end else begin
//           // do_pop
//           do_pop();
//         end

//         // $display("[TB] ref_queue size: %0d", ref_queue.size());
//       end
//       $display("[TB] Completed random_test.");
//     end
//   endtask : random_test

//   //---------------------------------------------------------------------------------
//   // 5) EDGE-CASE #1: Attempt to push into a full FIFO
//   //---------------------------------------------------------------------------------
//   task edge_case_full();
//     begin
//       $display("[TB] Starting edge_case_full test.");

//       // Fill FIFO completely (16 entries)
//       while (!full) begin
//         byte rand_data;
//         std::randomize(rand_data);
//         do_push(rand_data);
//       end

//     //   $display("[TB] ref_queue size before extra pushes: %0d", ref_queue.size());
//       $display("[TB] FIFO is now full. Attempting to push 5 more times...");

//       // Attempt extra pushes
//       for (int i = 0; i < 5; i++) begin
//         byte rand_data;
//         std::randomize(rand_data);
//         do_push(rand_data);
//       end

//       // Check scoreboard
//     //   $display("[TB] ref_queue size: %0d", ref_queue.size());
//       if (ref_queue.size() != 16) begin
//         $error("[TB] Reference queue size = %0d, should remain at 16. Something is wrong!",
//                ref_queue.size());
//         $fatal;
//       end
//       $display("[TB] edge_case_full test completed. FIFO remained full, as expected.");
//     end
//   endtask : edge_case_full

//   //---------------------------------------------------------------------------------
//   // 6) EDGE-CASE #2: Attempt to pop from an empty FIFO
//   //---------------------------------------------------------------------------------
//   task edge_case_empty();
//     begin
//       $display("[TB] Starting edge_case_empty test.");

//       // First, empty out the FIFO
//       while (!empty) begin
//         do_pop();
//       end

//       $display("[TB] FIFO is now empty. Attempting to pop 5 more times...");
//       for (int i = 0; i < 5; i++) begin
//         do_pop();  // data_out is don't care
//       end

//       // Check reference queue is truly empty
//       if (ref_queue.size() != 0) begin
//         $error("[TB] Reference queue is not empty? Something is wrong!");
//         $fatal;
//       end

//       $display("[TB] edge_case_empty test completed. FIFO remained empty, as expected.");
//     end
//   endtask : edge_case_empty

//   //---------------------------------------------------------------------------------
//   // Main test sequence
//   //---------------------------------------------------------------------------------
//   initial begin
//     // Wait for reset de-assertion
//     @(negedge rst);
//     $display("[TB] Reset de-asserted. Beginning tests...");

//     // 1) Simple push-only test
//     push_only_test(10);

//     // 2) Pop-only test (fill and then pop)
//     pop_only_test(10, 5);
//     // $display("[TB] ref_queue size: %0d", ref_queue.size());

//     // 3) Alternating push/pop
//     alternating_test(10);
//     // $display("[TB] after alt tests, ref_queue size: %0d", ref_queue.size());

//     // 4) Random push/pop
//     random_test(50);

//     // 5) Edge case: push when full
//     edge_case_full();

//     // 6) Edge case: pop when empty
//     edge_case_empty();

//     // 7) Finish
//     $display("[TB] All tests completed successfully!");
//     $finish;
//   end

// endmodule : top_tb
