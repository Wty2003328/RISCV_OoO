module FIFO
import rv32i_types::*; 
import params::*;
// #(
//     parameter WIDTH = 8,
//     parameter DEPTH = 16,
//     parameter ADDR_WIDTH = $clog2(DEPTH)
// ) 
(
    input  logic             clk,
    input  logic             rst,
    input  logic             enq,       // enqueue enable
    input  logic             deq,       // dequeue enable
    input  fetch_pkt_t data_in,
    output fetch_pkt_t data_out,
    output logic             full,
    output logic             empty
);

  localparam ADDR_WIDTH = $clog2(FIFO_SIZE);

  fetch_pkt_t queue[0:FIFO_SIZE-1];
  logic [ADDR_WIDTH:0] head, tail;  

  wire [ADDR_WIDTH-1:0] head_i = head[ADDR_WIDTH-1:0];
  wire [ADDR_WIDTH-1:0] tail_i = tail[ADDR_WIDTH-1:0];

  assign data_out = (empty || !deq) ? '1 : queue[head_i];
  
  assign empty    = (head[ADDR_WIDTH] == tail[ADDR_WIDTH]) && (head_i == tail_i);
  assign full     = (head[ADDR_WIDTH] != tail[ADDR_WIDTH]) && (head_i == tail_i);

  always_ff @(posedge clk) begin
    if (rst) begin
      head <= '0;
      tail <= '0;
    end else begin
      if (enq && !full) begin  // enq
        queue[tail_i] <= data_in;
        tail <= tail + 1'b1;
      end
      if (deq && !empty) begin  // deq
        head <= head + 1'b1;
      end
    end
  end

endmodule

