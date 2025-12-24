module ROB
  import rv32i_types::*;
  import params::*;
(
    input logic clk,
    input logic rst,

    // Dispatch inputs for enqueuing a new entry into the ROB
    input logic               ROB_enque,
    input logic [P_WIDTH-1:0] ROB_pd_dispatch,  // New physical register (7 bits for 128 regs)
    input logic [        4:0] ROB_rd_dispatch,  // Destination architectural register
    input logic               ROB_is_ls,  // Indicates if the instruction is a load/store
    input logic [63:0]        ROB_order_dispatch,
    // Inputs from the Common Data Bus (CDB)
    input CDB_t CDB[CDB_SIZE],  // CDB_SIZE = 5

    output logic flush,
    output logic [31:0] flush_addr,  // Flush address for the instruction
    output logic [63:0] flush_order,

    // ROB outputs for downstream modules
    output logic [ROB_WIDTH-1:0]   dispatch_ROB_Entry_ROB, // ROB index allocated for the dispatching instruction
    output logic [4:0] commit_rd_ROB,  // Architectural destination register at commit
    output logic [P_WIDTH-1:0] commit_pd_ROB,  // Committed physical register (7 bits)
    output rvfi_t commit_rvfi_ROB,  // RVFI info for committed instruction
    output logic is_full_ROB,  // Indicates if the ROB is full
    output logic commit_ROB_use_rd,
    output logic ROB_head_LS,
    output logic [ROB_WIDTH-1:0]  ROB_head_entry,
    input logic predict_taken,
    input logic [31:0] pc_target,

    output logic        commit_br,        // commit is a branch
    // output logic [31:0] commit_br_target, // resolved target
    output logic [ROB_WIDTH-1:0] commit_br_id
);

  localparam logic [1:0] IDLE = 2'b00;
  localparam logic [1:0] QUE_WR = 2'b10;  // Enqueue only (enque=1, deque=0)
  localparam logic [1:0] QUE_RD = 2'b01;  // Dequeue only (enque=0, deque=1)
  localparam logic [1:0] QUE_RD_WR = 2'b11;  // Simultaneous dequeue and enqueue

  //-------------------------------------------------------------------------
  // ROB pointer and counter signals
  //-------------------------------------------------------------------------
  // Use 5 bits for head and tail (since ROB_SIZE=64)
  logic [ROB_WIDTH-1:0] head_reg, tail_reg;
  logic [ROB_WIDTH-1:0] head_next, tail_next;
  logic [ROB_WIDTH:0] counter_reg, counter_next;

  assign ROB_head_entry = head_reg; // head index

  // Flags for enqueue and dequeue operations
  logic enque, deque;
  logic empty;
  // assign commit_ROB = deque;
  //-------------------------------------------------------------------------
  // ROB entry storage (assumes type ROB_t is defined in rv32i_types)
  //-------------------------------------------------------------------------
  ROB_t ROB_data_reg [0:ROB_SIZE-1];
  ROB_t ROB_data_next[0:ROB_SIZE-1];

//   // Flags for enqueue and dequeue operations
//   logic enque, deque;
//   logic empty;
  assign commit_ROB_use_rd = deque && (commit_rd_ROB != '0);
//   assign ROB_head_LS = ROB_data_reg[head_reg].ls;
  //-------------------------------------------------------------------------
  // ROB entry storage (assumes type ROB_t is defined in rv32i_types)
  //-------------------------------------------------------------------------
//   ROB_t ROB_data_reg [0:ROB_SIZE-1];
//   ROB_t ROB_data_next[0:ROB_SIZE-1];

  //-------------------------------------------------------------------------
  // Main combinational block: Update ROB entry values and generate commit signals
  //-------------------------------------------------------------------------
  integer j, i;
  integer unsigned flush_count, predicted_correct, total_branch, mispredict_jump;
  always_ff @(posedge clk) begin
    if(rst) begin
      flush_count <= 0; // Reset flush count on clock edge
      predicted_correct <= 0;
      total_branch <= 0;
      mispredict_jump <= 0;
    end
    if(flush)
      flush_count <= flush_count + 1; // Increment flush count on flush signal
    // if(ROB_data_reg[head_reg].Commit_Ready && ROB_data_reg[head_reg].branch_taken && !ROB_data_reg[head_reg].flush)
      // predicted_correct <= predicted_correct + 1; // Increment correct prediction count
    if(ROB_data_reg[head_reg].Commit_Ready && ROB_data_reg[head_reg].is_branch) begin
      if(!ROB_data_reg[head_reg].flush)
        predicted_correct <= predicted_correct + 1; // Increment correct prediction count
      if(ROB_data_reg[head_reg].branch_taken && ROB_data_reg[head_reg].flush)
        mispredict_jump <= mispredict_jump + 1; // Increment misprediction count
      // else
      //   predicted_correct <= predicted_correct - 1; // Decrement if prediction is incorrect
      total_branch <= total_branch + 1; // Increment total branch count
    end

  end

  always_comb begin
    // Default assignments for commit signals and ROB outputs.
    ROB_data_next          = ROB_data_reg;
    enque                  = 1'b0;
    dispatch_ROB_Entry_ROB = 'x;
    deque                  = 1'b0;
    commit_rd_ROB          = 'x;
    commit_pd_ROB          = 'x;
    commit_rvfi_ROB        = '0;
    flush                  = 1'b0;
    flush_addr = '0;
    flush_order = '0;
    commit_br        = '0;    // you’ll need to stash is_branch at enqueue
    // commit_br_target = '0;      // set from CDB’s pc_wdata 
    commit_br_id     = '0;

    // Process store-queue enqueue update



    // Check if the head entry is ready to commit.
    if (ROB_data_reg[head_reg].Commit_Ready) begin
      deque                   = 1'b1;  // Signal to dequeue the head element.
      commit_rd_ROB           = ROB_data_reg[head_reg].Arch_Register;
      commit_pd_ROB           = ROB_data_reg[head_reg].Phys_Register;
      commit_rvfi_ROB         = ROB_data_reg[head_reg].rvfi;


      commit_br        = ROB_data_reg[head_reg].is_branch;    // you’ll need to stash is_branch at enqueue
      // commit_br_target = ROB_data_reg[head_reg].pc_next;      // set from CDB’s pc_wdata 
      commit_br_id     = head_reg;
      flush_addr = ROB_data_reg[head_reg].pc_next;
      // Clear the  committed entry.
      // || (ROB_data_reg[head_reg].pc_next) != ROB_data_reg[head_reg].branch_target
      // if (ROB_data_reg[head_reg].flush != ROB_data_reg[head_reg].branch_taken || (ROB_data_reg[head_reg].flush && ROB_data_reg[head_reg].pc_next != ROB_data_reg[head_reg].branch_target)) begin
      if(ROB_data_reg[head_reg].flush) begin
        flush = 1'b1;
        // flush_addr = ROB_data_reg[head_reg].pc_next;
        flush_order = ROB_data_reg[head_reg].order + 1;
        for (integer unsigned  i = 0; i < ROB_SIZE; i++) begin
          ROB_data_next[i] = '0;
        end
      end
      // for (integer unsigned  i = 0; i < ROB_WIDTH; i++) begin
      //     ROB_data_next[i] = '0;
      //   end
      // Clear the committed entry.
      ROB_data_next[head_reg] = '0;
    end

    // Enqueue a new entry if requested.
    if (ROB_enque) begin
      enque                                 = 1'b1;
      dispatch_ROB_Entry_ROB                = tail_reg;
      ROB_data_next[tail_reg].Commit_Ready  = 1'b0;
      ROB_data_next[tail_reg].Arch_Register = ROB_rd_dispatch;
      ROB_data_next[tail_reg].Phys_Register = ROB_pd_dispatch;
      ROB_data_next[tail_reg].rvfi          = '0;  // Default value
      ROB_data_next[tail_reg].flush         = 1'b0;
      ROB_data_next[tail_reg].pc_next       = '0;  // Default value
      ROB_data_next[tail_reg].order         = ROB_order_dispatch;
      ROB_data_next[tail_reg].is_ls         =  ROB_is_ls;
      ROB_data_next[tail_reg].branch_taken  = predict_taken;
      ROB_data_next[tail_reg].branch_target = pc_target;
    end

    // Process updates from the CDB.
    for (j = 0; j < CDB_SIZE; j++) begin
      if (CDB[j].valid) begin
        ROB_data_next[CDB[j].ROB_entry].Commit_Ready = 1'b1;
        ROB_data_next[CDB[j].ROB_entry].rvfi         = CDB[j].rvfi;
        ROB_data_next[CDB[j].ROB_entry].flush        = CDB[j].flush;
        ROB_data_next[CDB[j].ROB_entry].pc_next      = CDB[j].pc_wdata;
        ROB_data_next[CDB[j].ROB_entry].is_branch     = CDB[j].is_branch;
      end
    end
    head_next    = head_reg;
    tail_next    = tail_reg;
    counter_next = counter_reg;
    unique case ({
      enque, deque
    })
      IDLE: begin
        if (rst) begin
          head_next    = '0;
          tail_next    = '0;
          counter_next = '0;
        end
      end
      QUE_WR: begin
        // Enqueue only: increment tail pointer and counter.
        tail_next    = tail_reg + 1'b1;
        counter_next = counter_reg + 1'b1;
      end
      QUE_RD: begin
        // Dequeue only: increment head pointer and decrement counter.
        head_next    = head_reg + 1'b1;
        counter_next = counter_reg - 1'b1;
      end
      QUE_RD_WR: begin
        // Both enqueue and dequeue: increment both pointers.
        head_next = head_reg + 1'b1;
        tail_next = tail_reg + 1'b1;
      end
      default: begin
        counter_next = '0;
      end
    endcase
  end

  //-------------------------------------------------------------------------
  // Sequential update: Register ROB state and pointers on clock edge.
  //-------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst || flush) begin
      counter_reg <= '0;
      head_reg    <= '0;
      tail_reg    <= '0;
      for (i = 0; i < ROB_SIZE; i++) begin
        ROB_data_reg[i] <= '0;
      end
    end else begin
      counter_reg <= counter_next;
      head_reg    <= head_next;
      tail_reg    <= tail_next;
      ROB_data_reg<= ROB_data_next;
    end
  end

  //-------------------------------------------------------------------------
  // Update pointers and counter based on enqueue/dequeue events.
  //-------------------------------------------------------------------------
  // always_comb begin
  //     head_next    = head_reg;
  //     tail_next    = tail_reg;
  //     counter_next = counter_reg;
  //     unique case ({enque, deque})
  //         IDLE: begin
  //             if (rst) begin
  //                 head_next    = '0;
  //                 tail_next    = '0;
  //                 counter_next = '0;
  //             end
  //         end
  //         QUE_WR: begin
  //             // Enqueue only: increment tail pointer and counter.
  //             tail_next    = tail_reg + 1'b1;
  //             counter_next = counter_reg + 1'b1;
  //         end
  //         QUE_RD: begin
  //             // Dequeue only: increment head pointer and decrement counter.
  //             head_next    = head_reg + 1'b1;
  //             counter_next = counter_reg - 1'b1;
  //         end
  //         QUE_RD_WR: begin
  //             // Both enqueue and dequeue: increment both pointers.
  //             head_next = head_reg + 1'b1;
  //             tail_next = tail_reg + 1'b1;
  //         end
  //         default: begin
  //             counter_next = '0;
  //         end
  //     endcase
  // end

  //-------------------------------------------------------------------------
  // Determine if the ROB is full or empty.
  //-------------------------------------------------------------------------
  always_comb begin
    is_full_ROB = 1'b0;
    empty       = 1'b0;
    // If the MSB of the counter is set and head equals tail, the ROB is full.
    if (counter_reg[ROB_WIDTH] && (head_reg == tail_reg)) is_full_ROB = 1'b1;
    // If the MSB is clear and head equals tail, the ROB is empty.
    if (!counter_reg[ROB_WIDTH] && (head_reg == tail_reg)) empty = 1'b1;
  end

  //-------------------------------------------------------------------------
  // Determine if the ROB head is LS.
  //-------------------------------------------------------------------------
  assign ROB_head_LS = empty ? 1'b0 : ROB_data_reg[head_reg].is_ls;
  // always_comb begin
  //   ROB_head_LS = 1'b0;
  //   if (!empty) begin
  //     ROB_head_LS = ROB_data_reg[head_reg].is_ls;
  //   end
  // end
  // always_comb begin
  //   // 
  // end

endmodule : ROB