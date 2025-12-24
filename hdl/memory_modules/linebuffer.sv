module linebuffer (
    input  logic        clk,
    input  logic        rst,

    // CPU–side signals 
    input  logic [31:0] ufp_addr,
    output logic [31:0] ufp_rdata,
    input  logic [3:0]  ufp_rmask,
    // input  logic [3:0]  ufp_wmask,
    input  logic [31:0] ufp_wdata,  // (write not implemented in this simple example)
    output logic        ufp_resp,   // high when data is available

    // signals to cache.sv (downstream memory)
    output logic [31:0] dfp_addr,
    output logic [3:0]  dfp_rmask,
    input  logic [255:0] dfp_rdata,
    input  logic        dfp_resp ,   // indicates that the entire cache line has been returned
    input  logic        flush
);

  localparam LINE_SIZE = 32;                
  localparam LINE_MASK = 32'hFFFFFFE0;         

  // Single cacheline storage and tag
  logic [255:0] cache_data, updated_data;
  logic [31:0]  cache_addr, wdata;    // holds the aligned address (tag) of the cached line
  logic         valid;

  assign wdata = ufp_wdata;

  // FSM states: IDLE when a cache access is in progress (or hit), WAIT when a miss
  typedef enum logic [1:0] {IDLE, WAIT, EXTRA} state_t;
  state_t state, next_state;

  logic [31:0] req_addr;

  // Compute aligned address and word offset.
  // The CPU address is masked to obtain the cache line tag.
  wire [31:0] aligned_addr = ufp_addr & LINE_MASK;

  wire [4:0] offset = { ufp_addr[4:2], 2'b00 };

  // A “hit” means the cache is valid and the tag matches the aligned request.
  wire hit = valid && (cache_addr == aligned_addr) && (ufp_rmask != 0);

  //--------------------------------------------------------------------------
  // Combinational block: next state and output control signals
  //--------------------------------------------------------------------------

  always_comb begin
    // Default assignments
    next_state = state;
    dfp_rmask   = '0;
    dfp_addr   = 32'b0;
    ufp_resp   = 1'b0;

    case (state)
      IDLE: begin
        if (hit) begin
          // Cache hit: data available immediately
          ufp_resp = 1'b1;
        end else begin
          // Cache miss: initiate a memory read.
          // Latch the requested address (aligned) and move to WAIT state.
          next_state = WAIT;
          dfp_rmask   = '1;
          dfp_addr   = aligned_addr;
        end
      end

      WAIT: begin
        // Continue asserting the request until the memory returns the cache line.
        dfp_rmask = '1;
        dfp_addr = req_addr;  // use the latched (missed) address
        if (dfp_resp) begin
          // When the full cache line is received, signal that data is ready
          next_state = IDLE;
          if(dfp_addr == ufp_addr)
            ufp_resp   = 1'b1;
        end
      end

      default: next_state = EXTRA;
    endcase
    if(rst) begin
      dfp_rmask = '0;
      updated_data = '0;
      // dfp_wmask = '0;
    end
    if(dfp_resp)
      updated_data = dfp_rdata;
    else
      updated_data = cache_data;
  end

  //--------------------------------------------------------------------------
  // Sequential block: state update and cache line update
  //--------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (rst) begin
      state      <= IDLE;
      valid      <= 1'b0;
      cache_data <= 256'b0;
      cache_addr <= 32'b0;
      req_addr   <= 32'b0;
    end
    else if (flush) begin
      // Reset cache on flush
      // state      <= IDLE;
      valid      <= 1'b0;
      cache_data <= 256'b0;
      cache_addr <= 32'b0;
    end else begin
      state <= next_state;
      // On a miss (in IDLE) latch the aligned request address.
      if (state == IDLE && !hit)
        req_addr <= aligned_addr;

      // In WAIT state, when the memory returns the cache line, update the cache.
      if (state == WAIT && dfp_resp) begin
        cache_data <= dfp_rdata;
        cache_addr <= req_addr;
        valid      <= 1'b1;
      end
    end
  end
  assign ufp_rdata = (ufp_resp) ? updated_data[offset * 8 +: 32] : 32'b0;

endmodule