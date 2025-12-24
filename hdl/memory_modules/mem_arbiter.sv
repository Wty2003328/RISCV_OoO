module mem_arbiter (
    input  logic         clk,
    input  logic         rst,

    // instruction‐fetch port
    input  logic [31:0]  fetch_addr,
    input  logic         fetch_read,
    output logic         fetch_resp,    // not yet used
    output logic [255:0] fetch_rdata,   // not yet used
    output logic [31:0] fetch_raddr, // not yet used

    // data‐mem port
    input  logic [31:0]  mem_addr,
    input  logic         mem_read,
    input  logic         mem_write,      // not yet used
    input  logic [255:0] mem_wdata,      // not yet used
    output logic         mem_resp,       // not yet used
    output logic [255:0] mem_rdata,      // not yet used
    output logic [31:0] mem_raddr, // not yet used
    // shared backend memory interface
    // input  logic         bmem_valid,     // indicates that bmem_rdata is valid
    output logic [31:0]  bmem_addr, 
    output logic         bmem_read,

    input  logic         r_resp,         // response from cache adapter for read
    input  logic         w_resp,         // response from cache adapter for write

    output logic         bmem_write,     
    output logic [255:0] bmem_wdata,      // not yet used
    input  logic [255:0] bmem_rdata,
    input  logic [31:0]  bmem_raddr
    // input  logic         bmem_rvalid
);
  assign fetch_raddr = bmem_raddr; // not yet used
  assign mem_raddr = bmem_raddr; // not yet used

  // //–– Latch requests and addresses
  // logic        pending_fetch, pending_mem;
  // logic [31:0] fetch_addr_reg,  mem_addr_reg;
  // // assign bmem_write = mem_write; // not yet used
  // assign bmem_wdata = mem_wdata; // not yet used

  // always_ff @(posedge clk) begin
  //   if (rst) begin
  //     pending_fetch  <= 1'b0;
  //     pending_mem    <= 1'b0;
  //     fetch_addr_reg <= '0;
  //     mem_addr_reg   <= '0;
  //   end else begin
  //     // capture new requests
  //     if (fetch_read) begin
  //       fetch_addr_reg <= fetch_addr;
  //       pending_fetch <= 1'b1;
  //     end
  //     if (mem_read | mem_write) begin
  //       mem_addr_reg   <= mem_addr;
  //       pending_mem   <= 1'b1;
  //     end
  //     if (r_resp)
  //       pending_fetch <= 1'b0;
  //     if (w_resp)
  //       pending_mem   <= 1'b0;
  //   end
  // end

  // always_comb begin
  //   bmem_read = 1'b0;
  //   bmem_addr = '0;
  //   bmem_write = 1'b0;

  //   if (pending_mem) begin
  //     if (mem_read) begin
  //       bmem_read = 1'b1;
  //       bmem_addr = mem_addr_reg;
  //     end else if (mem_write) begin
  //       bmem_write = 1'b1;
  //       bmem_addr = mem_addr_reg;
  //     end
  //   end
  //   else if (pending_fetch) begin
  //     bmem_read = 1'b1;
  //     bmem_addr = fetch_addr_reg;
  //   end
  //   // else if(pending_mem) begin
  // end

  // always_comb begin
  //   fetch_resp = 1'b0;
  //   fetch_rdata = '0;
  //   mem_resp = 1'b0; 
  //   mem_rdata = '0; 
  //   if(r_resp) begin // read finished, check if from mem or fetch
  //       if (pending_mem && bmem_raddr == mem_addr_reg) begin
  //           mem_resp = 1'b1;
  //           mem_rdata = bmem_rdata; // assign data from backend memory
  //       end 
  //       if (pending_fetch && bmem_raddr == fetch_addr_reg) begin
  //           fetch_resp = 1'b1; // indicate fetch response
  //           fetch_rdata = bmem_rdata; // assign data from backend memory
  //       end 
  //   end
  //   if(w_resp)begin
  //     mem_resp = 1'b1; // indicate mem response
  //   end
  // end


  typedef enum logic [1:0] {
    IDLE      = 2'b00,
    FETCH     = 2'b01,
    MEM       = 2'b10,
    DEFAULT   = 2'b11
  } fsm_t;

  fsm_t state, state_next;
  
  always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end
        else begin
            state <= state_next;
        end
    end

  always_comb begin
    // default outputs
    fetch_resp     = 1'b0;
    fetch_rdata    = '0;
    mem_resp       = 1'b0;
    mem_rdata      = '0;
    bmem_addr      = '0;
    bmem_read      = 1'b0;
    bmem_write     = 1'b0;
    bmem_wdata     = '0;
    state_next      = state;

    case (state)

      IDLE: begin
        
        if (mem_read || mem_write) begin
          state_next = MEM;
        end else
        if (fetch_read) begin
          state_next = FETCH;
        end 
        // else if (mem_read || mem_write) begin
          // state_next = MEM;
        // end
      end

      FETCH: begin
        bmem_addr = fetch_addr;
        bmem_read = 1'b1;
        if (r_resp) begin
          fetch_rdata = bmem_rdata;
          fetch_resp  = 1'b1;
          state_next   = IDLE;
        end
      end

      MEM: begin
        bmem_addr = mem_addr;

        if (mem_write) begin
          bmem_write = 1'b1;
          bmem_wdata = mem_wdata;
        end

        if (mem_read) begin
          bmem_read = 1'b1;
        end

        if (r_resp) begin
          if (mem_read) mem_rdata = bmem_rdata;
          mem_resp = 1'b1;
          bmem_read = '0;
          state_next = IDLE;
        end else if (w_resp) begin
          mem_resp = 1'b1;
          bmem_write =  '0;
          state_next = IDLE;
        end
      end

      default: begin
        state_next = IDLE;
      end

    endcase
  end


endmodule
