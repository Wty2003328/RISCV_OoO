module free_list
  import rv32i_types::*;
  import params::*;
(
    input logic clk,
    input logic rst,
    input logic flush,
    input logic fl_enque,
    input logic fl_deque,
    input logic [P_REG_SIZE-1:0] backup_free_list,  //from rrat
    input logic [P_WIDTH-1:0] freed_reg_phys,  // Freed physical register index (7 bits)
    output logic [P_WIDTH-1:0] pd_fl,  // Allocated physical register index
    output logic is_empty_fl  // Indicates if no free register is available
);

  // Internal free list: 1 indicates free, 0 indicates taken
  logic [P_REG_SIZE-1:0] free_list;      
  logic [P_REG_SIZE-1:0] free_list_next; 

  //---------------------------------------------------------------------
  // Sequential update: register the free list state on the clock edge
  //---------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
      // On reset, reserve registers 0-31 (taken) and free registers 32-127.
      for (integer unsigned i = 0; i < 32; i++) begin
        free_list[i] <= 1'b0;
      end
      for (integer unsigned i = 32; i < P_REG_SIZE; i++) begin
        free_list[i] <= 1'b1;
      end
    end else begin
      free_list <= free_list_next;
    end
  end

  //---------------------------------------------------------------------
  // Combinational update: determine next state and allocate free register
  //---------------------------------------------------------------------
  // always_comb begin
  //   // By default, maintain the current state.
  //   free_list_next = free_list;
  //   pd_fl = 'x;

  //   // If a physical register is freed, mark that entry as free.
  //   if (fl_enque) begin
  //     free_list_next[freed_reg_phys] = 1'b1;
  //   end

  //   // On a dequeue request, search for the first free register.
  //   if (fl_deque) begin
  //     for (integer unsigned i = 0; i < P_REG_SIZE; i++) begin
  //       if (free_list[i] == 1'b1) begin
  //         free_list_next[i] = 1'b0;
  //         pd_fl = P_WIDTH'(i);
  //         break;
  //       end
  //     end
  //   end

  // end

  always_comb begin
    free_list_next = free_list;
    pd_fl = 'x;

    if (flush) begin
      free_list_next = backup_free_list;
    end else begin
      if (fl_enque) free_list_next[freed_reg_phys] = 1'b1;
      if (fl_deque) begin
        for (integer unsigned i = 0; i < P_REG_SIZE; i++) begin
          if (free_list[i]) begin
            free_list_next[i] = 1'b0;
            pd_fl = P_WIDTH'(i);
            break;
          end
        end
      end
    end
  end
  //---------------------------------------------------------------------
  // Determine if the free list is empty by checking for any free entry.
  //---------------------------------------------------------------------
  always_comb begin
    is_empty_fl = 1'b1;
    for (integer unsigned i = 0; i < P_REG_SIZE; i++) begin
      if (free_list[i] == 1'b1) begin
        is_empty_fl = 1'b0;
      end
    end
  end

endmodule : free_list