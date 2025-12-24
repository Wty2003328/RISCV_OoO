// load and store
module ls
import rv32i_types::*; 
import params::*;
(
    // to cpu top level (cache/bmem)
    input logic           clk,
    input logic           rst,

    input logic             dmem_resp,
    input  logic    [255:0] dmem_rdata,     // 256 read data

    output  logic   [31:0]  dmem_addr,
    output  logic   [3:0]   dmem_rmask,
    output  logic   [3:0]   dmem_wmask,
    output  logic   [31:0]  dmem_wdata,

    output  logic           stalling_ls,
    output  logic   [31:0]  rd_v,           // load output
    // output  logic   [P_WIDTH - 1: 0]  rd_paddr_RAT,
    
    // to RS
    input   RS_t            LS_RS_next,
    input   logic           ls_fifo_en,     // IS THIS NECESSARY? CAN PROB USE LS_RS
    output  logic           ls_fifo_full,   // denote the ls fifo is full
    output  RS_t            LS_RS_out,

    // to PRF
    output  logic   [P_WIDTH - 1: 0]    rs1_paddr,
    output  logic   [P_WIDTH - 1: 0]    rs2_paddr,
    input   logic   [31:0]  p1_data,    // LS operations only uses rs1
    input   logic   [31:0]  p2_data,
    // input   CDB_t      CDB [CDB_SIZE], // CDB from PRF
    // output  logic   [4: 0]    rs1_addr,
    // output  logic   [4: 0]    rs2_addr,

    // input   logic           p1_valid,
    // input   logic           p2_valid,

    // from ROB
    input   logic   ls_fifo_dequeue_rob,        // if the head in ROB is ls operation
    input   logic [ROB_WIDTH-1:0]   ROB_head_entry, // head index
    input   logic   flush
);
    // assign rs1_addr = LS_RS_next.rs1_use ? LS_RS_next.rs1_addr : '0;
    // assign rs2_addr = LS_RS_next.rs2_use ? LS_RS_next.rs2_addr : '0;
    // logic test;
    // always_comb begin
    //     test = p1_valid && p2_valid;
    // end
    logic   [2:0]   funct3;
    logic   [31:0]  imm;
    logic           FIFO_empty;
    logic           FIFO_rst;
    logic           FIFO_de;
    RS_t            FIFO_in; 
    RS_t            FIFO_out;                // the ls operation gonna be executed
    logic           ls_sel;                  // select load or store
    logic   [31:0]  mem_addr;                // internal signal used for calculation
    logic   [31:0]  mem_rdata;               // 32 read data
    logic   [3:0]  dmem_wmask_reg;               // output to memory interface (aligned)
    logic   [3:0]   dmem_rmask_reg;              // read mask
    logic   [31:0]  dmem_wdata_reg;              // write data to memory
    // logic   [31:0]  p1_data_sa
    RS_t    LS_RS_reg;               // keep the FIFO head value
    always_comb begin
        FIFO_in = LS_RS_next;
        FIFO_in.valid = 1'b0;
    end
    // assign LS_RS_out = (FIFO_de) ? FIFO_out : LS_RS_reg;
    always_comb begin
        LS_RS_out = (FIFO_de) ? FIFO_out : LS_RS_reg;
        if (dmem_resp) begin
            LS_RS_out.valid = 1'b1;
            LS_RS_out.rvfi.mem_rdata = mem_rdata;
            LS_RS_out.rvfi.rd_wdata = ls_sel ? rd_v : mem_rdata;
            LS_RS_out.rvfi.rs1_rdata = p1_data;
            LS_RS_out.rvfi.rs2_rdata = p2_data;
        end
    end

    assign funct3 = LS_RS_out.funct3;
    assign imm = LS_RS_out.imm;
    assign ls_sel = LS_RS_out.ls_sel;

    assign rs1_paddr = LS_RS_out.rs1_use ? LS_RS_out.rs1_paddr : '0;
    assign rs2_paddr = LS_RS_out.rs2_use ? LS_RS_out.rs2_paddr : '0;

    assign FIFO_rst =  rst || flush;   
    
    wire [4:0] offset = { mem_addr[4:2], 2'b00 };
    // assign mem_rdata = (dmem_resp) ? dmem_rdata[offset * 8 +: 32] : 32'b0;
    assign mem_rdata = dmem_rdata[offset * 8 +: 32];

    logic can_dequeue;
    always_ff @(posedge clk) begin
        if (rst) begin
            can_dequeue <= 1'b1;
        end else if (FIFO_de) begin
            can_dequeue <= 1'b0;  // block further dequeues until mem_resp
        end else if (dmem_resp) begin
            can_dequeue <= 1'b1;  // ready to dequeue the next instruction
        end
    end
    assign FIFO_de = ls_fifo_dequeue_rob && can_dequeue && (FIFO_out.ROB_entry == ROB_head_entry) && !FIFO_empty;

    // LS FIFO (RS_t queue)
    FIFO_RS FIFO_LS( 
        .clk(clk),
        .rst(FIFO_rst),
        .enq(ls_fifo_en),           // enqueue enable when RS has a LS operation ready
        .deq(FIFO_de),              // dequeue enable when LS not stalling and the ROB head is a LS operation
        .data_in(FIFO_in),
        .data_out(FIFO_out),
        .full(ls_fifo_full),
        .empty(FIFO_empty)
    );

    // register holding the current ls operation
    always_ff @(posedge clk) begin
        if(rst) begin
            LS_RS_reg <= '0;
        end
        else if (FIFO_de) begin
            LS_RS_reg <= FIFO_out;
            LS_RS_reg.rvfi.mem_addr <= mem_addr;
            LS_RS_reg.rvfi.mem_rmask <= dmem_rmask;
            LS_RS_reg.rvfi.mem_wmask <= dmem_wmask;
            LS_RS_reg.rvfi.mem_wdata <= dmem_wdata;
        end
        // else LS_RS_reg should hold value
    end

    always_ff @(posedge clk) begin
        if (rst | dmem_resp) begin
            dmem_wmask_reg <= '0;
            dmem_rmask_reg <= '0;
            dmem_wdata_reg <= '0;
        end
        if (FIFO_de) begin
            dmem_wmask_reg <= dmem_wmask;
            dmem_rmask_reg <= dmem_rmask;
            dmem_wdata_reg <= dmem_wdata;
        end
    end

    // set addr and mask
    always_comb begin
        mem_addr = p1_data + imm;                 // ls all calculate addr using p1 and imm
        dmem_addr =  mem_addr & 32'hFFFFFFFC;     // output to memory interface (aligned)
        dmem_rmask = dmem_rmask_reg;
        dmem_wmask = dmem_wmask_reg;
        dmem_wdata = dmem_wdata_reg;
        if (FIFO_de) begin
            unique case (ls_sel)
                // load
                1'b0: begin
                    unique case (funct3)
                        load_f3_lb, load_f3_lbu: dmem_rmask = 4'b0001 << mem_addr[1:0];
                        load_f3_lh, load_f3_lhu: dmem_rmask = 4'b0011 << mem_addr[1:0];
                        load_f3_lw             : dmem_rmask = 4'b1111;
                        default                : dmem_rmask = '0;
                    endcase
                end
                // store
                1'b1: begin
                    unique case (funct3)
                        store_f3_sb: dmem_wmask = 4'b0001 << mem_addr[1:0];
                        store_f3_sh: dmem_wmask = 4'b0011 << mem_addr[1:0];
                        store_f3_sw: dmem_wmask = 4'b1111;
                        default    : dmem_wmask = '0;
                    endcase
                    unique case (funct3)
                        store_f3_sb: dmem_wdata[8 *mem_addr[1:0] +: 8 ] = p2_data[7 :0];
                        store_f3_sh: dmem_wdata[16*mem_addr[1]   +: 16] = p2_data[15:0];
                        store_f3_sw: dmem_wdata = p2_data;
                        default    : dmem_wdata = '0;
                    endcase
                end
                default: begin
                    mem_addr = '0;
                    dmem_addr =  '0;
                    dmem_rmask = '0;
                    dmem_wmask = '0;
                    dmem_wdata = '0;
                end
            endcase
        end
    end

    // set rd_v and stalling_ls
    always_comb begin
        rd_v = 'x; 
        stalling_ls = 1'b0;
        if (!can_dequeue) begin
            unique case (ls_sel)
                // load
                1'b0: begin
                    if (dmem_resp) begin
                        stalling_ls = 1'b0;
                        unique case (funct3)
                            load_f3_lb : rd_v = {{24{mem_rdata[7 +8 *mem_addr[1:0]]}}, mem_rdata[8 *mem_addr[1:0] +: 8 ]};
                            load_f3_lbu: rd_v = {{24{1'b0}}                          , mem_rdata[8 *mem_addr[1:0] +: 8 ]};
                            load_f3_lh : rd_v = {{16{mem_rdata[15+16*mem_addr[1]  ]}}, mem_rdata[16*mem_addr[1]   +: 16]};
                            load_f3_lhu: rd_v = {{16{1'b0}}                          , mem_rdata[16*mem_addr[1]   +: 16]};
                            load_f3_lw : rd_v = mem_rdata;
                            default    : rd_v = 'x;
                        endcase
                    end else begin
                        stalling_ls = 1'b1;
                    end
                end
                // store
                1'b1: begin
                    if (dmem_resp) begin
                        stalling_ls = 1'b0;
                        rd_v = 'x;
                    end else begin
                        stalling_ls = 1'b1;
                    end
                end
                default: begin
                    stalling_ls = 1'b0;
                    rd_v = 'x;
                end
            endcase
        end
    end

    // // test
    // wire RS_IN_LS_SEL = LS_RS_next.ls_sel;

endmodule