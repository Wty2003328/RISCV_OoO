module regfile
(
    input   logic           clk,
    input   logic           rst,
    input   logic           regf_we,
    input   logic   [31:0]  rd_v,
    input   logic   [4:0]   rs1_s, rs2_s, rd_s,
    output  logic   [31:0]  rs1_v, rs2_v
);

    logic   [31:0]  data [32];
    logic   [31:0]  rs1_data, rs2_data;


    always_ff @(posedge clk) begin
        if (rst) begin
            for (integer i = 0; i < 32; i++) begin
                data[i] <= '0;
            end
        end else if (regf_we && (rd_s != 5'd0)) begin
            data[rd_s] <= rd_v;
        end
    end

    always_comb begin
        rs1_data = (rs1_s == rd_s && regf_we) ? rd_v : data[rs1_s];
        rs2_data = (rs2_s == rd_s && regf_we) ? rd_v : data[rs2_s];
        if (rst) begin
            rs1_v = '0;
            rs2_v = '0;
        end else begin
            rs1_v = (rs1_s != 5'd0) ? rs1_data : '0;
            rs2_v = (rs2_s != 5'd0) ? rs2_data : '0;
        end
    end

endmodule : regfile
