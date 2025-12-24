module cache_adapter (
    input   logic               clk,
    input   logic               rst,

    input   logic               read,
    input   logic    [31:0]     addr_cpu,
    // input   logic               write,
    // input   logic    [31:0]     waddr_cpu,
    

    output logic                bmem_read, // tel bmem read
    output logic    [31:0]      bmem_addr, // address to r/w from in bmem

    output logic                bmem_write, // tell bmem write


    // for when reading from dram
    input   logic   [63:0]      rdata_in,
    input   logic   [31:0]      raddr_in, // addr from bmem
    input   logic               r_valid,  // indicate that data is ready (r_valid & ready) from bmem
    output  logic   [255:0]     rdata_out,
    output  logic               r_resp,     // indicate to cache that a read is finished
    output  logic   [31:0]      raddr_out,

    // for writing to dram
    input   logic   [255:0]     wdata_in, // MIGHT NEED TO REGISTER
    // input   logic   [31:0]      waddr_in,
    input   logic               w_valid,
    output  logic   [63:0]      wdata_out,
    output  logic               w_resp,
    output  logic   [31:0]      waddr_out


);

logic   [255:0]   data, data_next, wdata_in_reg;
logic   [1:0]     counter, counter_next;
logic   [31:0]    addr;
logic   [63:0]    wdata_out_next;
// logic           rvalid;

// logic
logic   [31:0]    bmem_addr_next;
logic   bmem_read_next, bmem_write_next, in_use, in_use_next;


always_ff @(posedge clk) begin
    if(rst) begin
        bmem_read_next <= '0;
        bmem_addr_next <= '0;
        // bmem_waddr_next <= '0;
    end else begin
        bmem_read_next <= read;
        in_use_next <= in_use;
        if(read) begin
            bmem_addr_next <= addr_cpu;
        end 
        else if(w_valid) begin
            bmem_addr_next <= addr_cpu; 
            wdata_in_reg <= wdata_in; // register the write data
        end
        // bmem_addr_next <= raddr;
        // bmem_waddr_next <= waddr;
    end
end
    
assign bmem_read = (!bmem_read_next) && (read) ; // ensure high for 1 cycle
// assign bmem_write = (!bmem_write_next) && (write); // ensure high for 1 cycle
// assign bmem_addr = bmem_addr_next; // address to read from backend memory

always_comb begin
    data = data_next;
    wdata_out_next = '0;
    bmem_write = '0;
    bmem_addr = '0;
    // not_used = '0;
    in_use = in_use_next;
    if(read) begin
        bmem_addr = addr_cpu;
        in_use = 1'b1; // not used
    end 
    else if(w_valid) begin
        bmem_addr = addr_cpu; 
        in_use = 1'b1; // not used
    end
    counter_next = counter;
    if(r_valid) begin
        // data = data_next;
        case (counter)
            2'd0: data[63:0]     = rdata_in;
            2'd1: data[127:64]   = rdata_in;
            2'd2: data[191:128]  = rdata_in;
            2'd3: begin 
                data[255:192]  = rdata_in;
                in_use = '0;
            end
        endcase
        counter_next = counter + 1'b1;
        // raddr_out = addr;
    end

    if(w_valid) begin
        case (counter)
            2'd0: wdata_out_next  = wdata_in[63:0];
            2'd1: wdata_out_next  = wdata_in_reg[127:64] ;
            2'd2: wdata_out_next  = wdata_in_reg[191:128];
            2'd3: begin 
                wdata_out_next  = wdata_in_reg[255:192];
                in_use = '0;
            end
        endcase
        counter_next = counter + 1'b1;
        bmem_write = 1'b1; // signal to backend memory to write
    end
    // counter_next = counter + 1'b1;
    if(counter == 2'h3)
        counter_next = '0;
end

assign wdata_out = wdata_out_next;

always_ff @(posedge clk) begin
    if(rst) begin
        // data    <= 256'b0;
        counter <= 2'b0;
        r_resp   <= 1'b0;
        w_resp <= 1'b0;
        addr    <= 32'b0;
        data_next <= '0;
    end else begin
        // wdata_out <= wdata_out_next;
        if (r_valid) begin // CHANGE TO R VALID

            data_next <= data;

            if(counter_next == 2'd0) begin
                addr <= raddr_in;
            end
            counter <= counter_next;
            if(counter_next == 2'd3) begin // only set valid after counter is finished
                r_resp   <= 1'b1; //CHANGE TO RESP
                // counter <= 2'd0;
            end else begin
                r_resp   <= 1'b0;
                // counter <= counter + 2'b1;
            end
        end 

        else if (w_valid) begin
            counter <= counter_next;
            // wdata_out <= wdata_out_next;
            if(counter_next == 2'd0) begin
                addr <= addr_cpu;
                // w_resp   <= 1'b1;
            end

            if(counter == 2'd3) begin // only set valid after counter is finished
                w_resp   <= 1'b1;
                // counter <= 2'd0;
            end else begin
                w_resp   <= 1'b0;
                // counter <= counter + 2'b1;
            end
        end 
        
        else begin
            r_resp <= 1'b0;
            w_resp <= 1'b0;
        end
    end
end



assign  rdata_out = data;
assign  raddr_out = addr;
assign  waddr_out = addr;

endmodule