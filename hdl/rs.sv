module rs 
import rv32i_types::*; 
import params::*;
(   
    input logic      clk,
    input logic      rst,

    input RS_t       DISPATCH, // dispatch
    input CDB_t      CDB    [CDB_SIZE],
    input logic      dispatch_enqueu, // denote new instr from dispatch

    input logic      doing_mul, // input from func wrapper? or internal tracking?
    input logic      doing_div, // input from func wrapper? or internal tracking?
    // input logic      ls_fifo_full, // denote ls fifo full
    // input logic      doing_br, // input from func wrapper? or internal tracking?

    output logic     start_mul, // denote mul start for func 
    output logic     start_div, // denote div start for func
    // output logic     ls_fifo_en, // high when a mem should be enqueue to ls fifo
    // output logic     start_br, // denote br start for func

    output RS_t      ALU_IN,    // -> ALU
    output RS_t      MUL_IN,    // -> MUL
    output RS_t      DIV_IN,    // -> DIV
    // output RS_t      MEM_IN,    // -> MEM (ls)
    output RS_t      BR_IN,     // -> BR
    output logic     rs_full,    // denote if RS is full

    input  logic     flush
);

    // internal signals
    logic [$clog2(RS_DEPTH)-1:0] RS_index; // the "empty" entry index in RS
    logic   MUL_begin; // high when a mul start
    logic   DIV_begin, test; // high when a div start

    // define the whole RS table
    RS_t RS[RS_DEPTH];
    RS_t RS_next[RS_DEPTH];
    always_ff @(posedge clk) begin
        if (rst||flush) begin
            for (integer unsigned i = 0; i < RS_DEPTH; i = i + 1) begin
                RS[i].valid <= '0;
                RS[i].rvfi <= '0;
            end
            test <= '0;
        end else begin
            RS <= RS_next;
            test <= '1;
        end
    end
    integer testing;

    // check if RS is full
    always_comb begin
        ALU_IN = RS[0];
        ALU_IN.valid = '0;
        MUL_IN = RS[0];
        MUL_IN.valid = '0;
        DIV_IN =  RS[0];
        DIV_IN.valid = '0;
        BR_IN = RS[0];
        BR_IN.valid = '0;
        // MEM_IN =  RS[0];
        // MEM_IN.valid = '0;
        rs_full = 1'b1;
        RS_index = 'x;
        for (integer unsigned i = 0; i< RS_DEPTH; i++) begin
            if (RS[i].valid == 0) begin
                rs_full = '0;
                RS_index = $clog2(RS_DEPTH)'(i);  // cast to proper width
                break;
            end
        end 
    // end

    // // parpare RS_next for updating RS 
    // always_comb begin
        RS_next = RS;
        if (dispatch_enqueu && DISPATCH.valid) begin
            RS_next[RS_index] = DISPATCH; // enqueue RS entry from dispatch
        end

        // check CDB and set register ready
        for (integer CDB_index = 0; CDB_index< CDB_SIZE; CDB_index++) begin
            if (CDB[CDB_index].valid) begin
                for (integer i = 0; i< RS_DEPTH; i++) begin
                    // check rs1
                    if (RS[i].valid && !RS[i].p1_rdy && RS[i].rs1_use && CDB[CDB_index].rd_paddr == RS[i].rs1_paddr) begin
                        RS_next[i].p1_rdy = 1'b1;
                    end
                    // check rs2
                    if (RS[i].valid && !RS[i].p2_rdy && RS[i].rs2_use && CDB[CDB_index].rd_paddr == RS[i].rs2_paddr) begin
                        RS_next[i].p2_rdy = 1'b1;
                    end
                end
            end
        end        
    // end

    // // parpare for functional units
    // always_comb begin
        start_mul = '0;
        start_div = '0;
        // start_br  = '0;
        // ls_fifo_en = '0;

        // ALU           
        for (integer i = 0; i< RS_DEPTH; i++) begin
            if (RS[i].valid && RS[i].CDB_ind == alu && (!RS[i].rs1_use || RS[i].p1_rdy) && (!RS[i].rs2_use || RS[i].p2_rdy)) begin
                ALU_IN = RS[i];
                RS_next[i].valid = '0;
                break;
            end
            // break;
        end
        
        // MUL
        if (!doing_mul) begin // mul function unit is available
            for (integer i = 0; i< RS_DEPTH; i++) begin
                if (RS[i].valid && RS[i].CDB_ind == mul && RS[i].p1_rdy && RS[i].p2_rdy) begin // all mul operation uses rs1 and rs2
                    MUL_IN = RS[i];
                    RS_next[i].valid = '0;
                    start_mul = '1;
                    // MUL_index_next = i[$clog2(RS_DEPTH)-1:0];
                    // RS_next[MUL_index].valid = '0;
                    // MUL_OUT = RS[MUL_index];
                    break;
                end
            end
        end
        
        // DIV
        if (!doing_div) begin // div function unit is available
            for (integer i = 0; i< RS_DEPTH; i++) begin
                if (RS[i].valid && RS[i].CDB_ind == div && RS[i].p1_rdy && RS[i].p2_rdy) begin // all mul operation uses rs1 and rs2
                    DIV_IN = RS[i];
                    RS_next[i].valid = '0;
                    start_div = '1;
                    // DIV_index_next = i[$clog2(RS_DEPTH)-1:0];
                    // RS_next[DIV_index].valid = '0;
                    // DIV_OUT = RS[DIV_index];
                    break;
                end
            end
        end

        // // MEM     
        // if (!ls_fifo_full) begin // ls fifo is not full (can still enqueue)
        //     for (integer i = 0; i< RS_DEPTH; i++) begin
        //         if (RS[i].valid && RS[i].CDB_ind == ls && (!RS[i].rs1_use || RS[i].p1_rdy) && (!RS[i].rs2_use || RS[i].p2_rdy)) begin
        //             MEM_IN = RS[i];
        //             RS_next[i].valid = '0;
        //             testing = i;
        //             ls_fifo_en = '1;
        //             break;
        //         end
        //         // break;
        //     end
        // end

        // BR
        // if (!doing_br) begin // ls fifo is not full (can still enqueue)
            for (integer i = 0; i < RS_DEPTH; i++) begin
                if (RS[i].valid && RS[i].CDB_ind == br && (!RS[i].rs1_use || RS[i].p1_rdy) && (!RS[i].rs2_use || RS[i].p2_rdy)) begin
                    BR_IN = RS[i];
                    RS_next[i].valid = '0;
                    testing = i;
                    break;
                end
            // break;
            end
        // end
        
    end

    // testing
    // wire [31:0] RS_0 = RS[0].rvfi.inst;
    // wire [31:0] RS_1 = RS[1].rvfi.inst;
    // wire [31:0] RS_2 = RS[2].rvfi.inst;
    // wire [31:0] RS_3 = RS[3].rvfi.inst;
    // wire [31:0] RS_4 = RS[4].rvfi.inst;
    wire [31:0] RS_in = DISPATCH.rvfi.inst;
    wire RS_IN_check = DISPATCH.ls_sel;
endmodule