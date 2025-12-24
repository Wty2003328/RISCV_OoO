module if_stage 
  import rv32i_types::*;
(
    input  logic         rst,
    input  logic [31:0]  pc,

    input  logic         flush,            // flush coming from ROB
    input  logic         FIFO_full,        // back-pressure from dispatch queue
    input  logic         imem_resp,        // instruction memory responded

    output logic [31:0]  pc_next,
    output logic [31:0]  imem_addr,
    output logic [3:0]   imem_rmask,
    output logic         enq,              // enqueue into FIFO
    output logic         stalling_if      // overall stall for IF stage
    // new predictor ports
    // input  logic         predictor_stall,  // one-cycle stall from predictor
    // input  logic         predict_taken,    // valid when predictor_stall deasserts
    // input  logic [31:0]  pc_target        // branch target from predictor
);

    always_comb begin
        // defaults
        imem_rmask    = 4'b1111;
        imem_addr     = pc;
        enq           = 1'b0;
        stalling_if   = 1'b1;
        pc_next       = pc;      // hold by default

        if (rst) begin
            // on reset, point PC at RESET vector and stay stalled
            imem_addr   = 32'hAAAAA000;
            pc_next     = 32'hAAAAA000;
            stalling_if = 1'b1;
        end
        // else if (predictor_stall) begin
        //     // waiting the extra cycle for predictor SRAM
        //     stalling_if = 1'b1;
        // end
        else if (imem_resp && !FIFO_full && !flush) begin
            // fetch succeeded, no back-pressure, and not flushing
            stalling_if = 1'b0;
            enq         = 1'b1;

            // update PC based on prediction
            // if (predict_taken)
            //     pc_next = pc_target;
            // else
            pc_next = pc + 4;
        end
        else begin
            // either no response yet, FIFO full, or flush
            stalling_if = 1'b1;
        end
    end

endmodule
