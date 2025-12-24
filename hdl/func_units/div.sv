module DW_div_seq_inst
import rv32i_types::*;
import params::*;
(
    input   logic             clk,
    input   logic             rst,       // Active-high reset (to be inverted for DW_div_seq)
    input   logic             hold,
    input   logic             start,
    input   logic   [32:0]    a,         // FROM CPU, CPU NEEDS TO DO SIGN EXTENTION
    input   logic   [32:0]    b,
    input   RS_t              DIV_RS_next,

     // give to PRF
    output  logic   [P_WIDTH - 1: 0]    rs1_paddr,
    output  logic   [P_WIDTH - 1: 0]    rs2_paddr,


    output  logic             complete,
    output  logic             divide_by_0,
    output  logic   [32:0]    quotient,
    output  logic   [32:0]    remainder,
    output  RS_t              DIV_RS_out,
    output  logic             sent_valid           
      
);

    logic rst_n;
    // logic RS_t DIV_RS;
    // logic [31:0]  a_in,b_in;
    assign rst_n = ~rst;  // activate low rst
    assign rs1_paddr = (start && DIV_RS_next.rs1_use) ? DIV_RS_next.rs1_paddr : '0;
    assign rs2_paddr = (start && DIV_RS_next.rs2_use) ? DIV_RS_next.rs2_paddr : '0;

    // assign DIV_RS_out.rvfi.rs1_rdata = a[31:0];
    // assign DIV_RS_out.rvfi.rs2_rdata = b[31:0];

    always_ff @(posedge clk) begin
        if(rst) begin
            DIV_RS_out <= '0;            
            sent_valid <= '1; // sent valid should be ~doing_div
        end
        else begin
            if(start) begin
                DIV_RS_out <= DIV_RS_next;
                sent_valid <= '0;
                // waiting <= '1;
                DIV_RS_out.rvfi.rs1_rdata <= a[31:0];
                DIV_RS_out.rvfi.rs2_rdata <= b[31:0];
            end
            // DIV out valid is high only for one cycle and only if complete
            if(complete && !sent_valid && !start) begin // might not need !start
                DIV_RS_out.valid <= '1;
                sent_valid <= '1;
            end
            else
                DIV_RS_out.valid <= '0;
        end
    end

    // always_comb begin
    //     waiting = '0;
    //     if(start)
    //         waiting = '1;
        
    // end
    // 33 bits for a/b input 
    // using two's complement, default cycles = 3, asynch rst
    // registereed inputs, 
    DW_div_seq #(33, 33, 1, DIV_CYCLES) U1 (
        .clk(clk),
        .rst_n(rst_n),
        .hold(hold),
        .start(start),
        .a(a),
        .b(b),
        .complete(complete),
        .divide_by_0(divide_by_0),
        .quotient(quotient),
        .remainder(remainder)
    );

endmodule
