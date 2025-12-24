module DW_mul_seq_inst
import rv32i_types::*;
import params::*;
(
    input   logic             clk,
    input   logic             rst,       // Active-high reset (to be inverted for DW_div_seq)
    input   logic             hold,
    input   logic             start,
    input   logic   [32:0]    a,         // FROM CPU, CPU NEEDS TO DO SIGN EXTENTION
    input   logic   [32:0]    b,
    input   RS_t              MUL_RS_next,

    // give to PRF
    output  logic   [P_WIDTH - 1: 0]    rs1_paddr,
    output  logic   [P_WIDTH - 1: 0]    rs2_paddr,

    output  logic             complete,
    output  logic   [65:0]    mul_out,
    output  RS_t              MUL_RS_out,
    output  logic             sent_valid           
);

    logic rst_n;
    // logic RS_t DIV_RS;
    // logic [31:0]  rs1_paddr, rs2_paddr;
    assign rst_n = ~rst;  // activate low rst
    assign rs1_paddr = (start && MUL_RS_next.rs1_use) ? MUL_RS_next.rs1_paddr : '0;
    assign rs2_paddr = (start && MUL_RS_next.rs2_use) ? MUL_RS_next.rs2_paddr : '0;

    // assign MUL_RS_out.rvfi.rs1_rdata = a[31:0];
    // assign MUL_RS_out.rvfi.rs2_rdata = b[31:0];

    always_ff @(posedge clk) begin
        if(rst) begin
            MUL_RS_out <= '0;
            // waiting <= '0;
            sent_valid <= '1;
        end
        else begin
            if(start) begin
                MUL_RS_out <= MUL_RS_next;
                sent_valid <= '0;
                MUL_RS_out.rvfi.rs1_rdata <= a[31:0];
                MUL_RS_out.rvfi.rs2_rdata <= b[31:0];
                // waiting <= '1;
            end
            // DIV out valid is high only for one cycle and only if complete
            if(complete && !sent_valid) begin
                MUL_RS_out.valid <= '1;
                sent_valid <= '1;
                // MUL_RS_out.rvfi.rs1_rdata <= a[31:0];
                // MUL_RS_out.rvfi.rs2_rdata <= b[31:0];
            end
            else
                MUL_RS_out.valid <= '0;
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
    DW_mult_seq #(33, 33, 1, MULT_CYCLES) U1 (
        .clk(clk),
        .rst_n(rst_n),
        .hold(hold),
        .start(start),
        .a(a),
        .b(b),
        .complete(complete),
        .product(mul_out)
    );

endmodule
