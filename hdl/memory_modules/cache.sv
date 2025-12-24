module cache (
    input logic clk,
    input logic rst,

    // CPU-side signals (UFP = Upward-Facing Port)
    input  logic [ 31:0] ufp_addr,
    input  logic [  3:0] ufp_rmask,
    input  logic [  3:0] ufp_wmask,
    output logic [255:0] ufp_rdata,
    input  logic [ 31:0] ufp_wdata,
    output logic         ufp_resp,

    // Memory-side signals (DFP = Downward-Facing Port)
    output logic [ 31:0] dfp_addr,
    output logic         dfp_read,
    output logic         dfp_write,
    input  logic [255:0] dfp_rdata,
    output logic [255:0] dfp_wdata,
    input  logic         dfp_resp,
    input  logic [ 31:0] dfp_raddr
);

  // ------------------------------------------------------------------------
  // 1) Address Decomposition
  //    [31:9] = tag (23 bs), [8:5] = index (4 bs -> 16 sets),
  //    [4:2] = word offset in 32B line, [1:0] = always 0
  // ------------------------------------------------------------------------
  logic [31:0] ufp_addr_q;
  logic [ 3:0] ufp_rmask_q;
  logic [ 3:0] ufp_wmask_q;
  logic [31:0] ufp_wdata_q;

  always_ff @(posedge clk) begin
    if (rst) begin
      ufp_addr_q  <= 32'b0;
      ufp_rmask_q <= 4'b0;
      ufp_wmask_q <= 4'b0;
      ufp_wdata_q <= 32'b0;
    end else if ((ufp_rmask != 4'b0) || (ufp_wmask != 4'b0)) begin
      ufp_addr_q  <= ufp_addr;
      ufp_rmask_q <= ufp_rmask;
      ufp_wmask_q <= ufp_wmask;
      ufp_wdata_q <= ufp_wdata;
    end
  end

  // Stage 1: Decode the latched address into tag, index, offset
  logic [ 22:0] ufp_tag;
  logic [  3:0] ufp_idx;
  logic [  4:0] ufp_offset;

  // ------------------------------------------------------------------------
  // 2) Arrays (4 Ways)
  //    (a) data_array: 256 bs/line
  //    (b) tag_array:  23 bs/line
  //    (c) valid_dirty_array: 2 bs => {dirty, valid}
  // ------------------------------------------------------------------------
  // Data arrays
  logic [255:0] data_array_dout[4];
  logic [255:0] data_in        [4];
  logic         data_we        [4];  // active-low write

  // Tag arrays (23 bs each)
  logic [ 22:0] tag_array_dout [4];
  logic [ 22:0] tag_in         [4];
  logic         tag_we         [4];

  // Valid/dirty arrays: 2 bs => [1]=dirty, [0]=valid
  logic [  1:0] vd_out         [4];
  logic [  1:0] vd_in          [4];
  logic         vd_we          [4];

  // Break out valid/dirty bs
  logic         valid_out      [4];
  logic         dirty_out      [4];

  // ------------------------------------------------------------------------
  // 3) Hit Detection (Combinational)
  // ------------------------------------------------------------------------
  logic [  3:0] tag_equal;
  logic hit_way0, hit_way1, hit_way2, hit_way3;
  logic hit_detected;
  logic [255:0] data_hit_selected;
  // Indicates which way hit (if any)
  logic [1:0] way_hit;

  // Extract valid/dirty bs
  generate
    for (genvar i = 0; i < 4; i++) begin : valids
      always_comb begin
        valid_out[i] = vd_out[i][0];
        dirty_out[i] = vd_out[i][1];
      end
    end
  endgenerate

  // Tag compare and data selection
  always_comb begin
    // Compare each way's tag with ufp_tag
    tag_equal[0] = (ufp_tag == tag_array_dout[0]);
    tag_equal[1] = (ufp_tag == tag_array_dout[1]);
    tag_equal[2] = (ufp_tag == tag_array_dout[2]);
    tag_equal[3] = (ufp_tag == tag_array_dout[3]);

    // Combine with valid bs
    hit_way0 = tag_equal[0] & valid_out[0];
    hit_way1 = tag_equal[1] & valid_out[1];
    hit_way2 = tag_equal[2] & valid_out[2];
    hit_way3 = tag_equal[3] & valid_out[3];

    // Hit detected if any way hits
    hit_detected = hit_way0 | hit_way1 | hit_way2 | hit_way3;

    // Select data from the way that hit
    unique casez ({
      hit_way3, hit_way2, hit_way1, hit_way0
    })
      4'b???1: data_hit_selected = data_array_dout[0];
      4'b??10: data_hit_selected = data_array_dout[1];
      4'b?100: data_hit_selected = data_array_dout[2];
      4'b1000: data_hit_selected = data_array_dout[3];
      default: data_hit_selected = 'x;
    endcase

    // Identify which way hit
    way_hit = 2'bxx;
    if (hit_way0) way_hit = 2'b00;
    else if (hit_way1) way_hit = 2'b01;
    else if (hit_way2) way_hit = 2'b10;
    else if (hit_way3) way_hit = 2'b11;
  end

  // ------------------------------------------------------------------------
  // 4) PLRU (Modified to use sp_ff_array with a one-cycle delay)
  // ------------------------------------------------------------------------
  // Signals for PLRU state storage
  logic [2:0] plru_read;  // Output from sp_ff_array (delayed)
  logic [2:0] plru_din;  // New PLRU state to write
  logic       plru_we;  // Write enable (active low)

  // Instantiate the PLRU sp_ff_array (16 entries, 3 bs each)
  sp_ff_array #(
      .S_INDEX(4),
      .WIDTH  (3)
  ) plru_array (
      .clk0 (clk),
      .rst0 (rst),
      .csb0 (1'b0),
      .web0 (plru_we),   // Active-low write: 0 updates the entry.
      .addr0(ufp_idx),
      .din0 (plru_din),
      .dout0(plru_read)
  );
  // ------------------------------------------------------------------------
  // 5) FSM Declaration
  // ------------------------------------------------------------------------
  typedef enum logic [2:0] {
    IDLE      = 3'b000,
    TAG_CHECK = 3'b001,
    ALLOCATE  = 3'b010,
    WAIT      = 3'b011,
    WRITEBACK = 3'b100
  } fsm_t;

  fsm_t fsm_state, fsm_next_state;


  logic [1:0] victim_way;
  always_comb begin
    unique casez (plru_read)
      3'b0?0: victim_way = 2'b11;  // When plru_read matches 0 ? 0, choose victim 3
      3'b1?0: victim_way = 2'b10;  // When plru_read matches 1 ? 0, choose victim 2
      3'b?01: victim_way = 2'b01;  // When plru_read matches ? 0 1, choose victim 1
      3'b?11: victim_way = 2'b00;  // When plru_read matches ? 1 1, choose victim 0
      default: begin
        victim_way = 2'b00;
      end
    endcase
  end

  // Update the PLRU state on a hit using a unique case statement.
  logic [2:0] plru_next;
  always_comb begin
    // Default: hold the current state.
    plru_next = plru_read;
    plru_we   = 1'b1;

    if (fsm_state == TAG_CHECK && hit_detected) begin
      unique case (way_hit)
        2'b00:   plru_next = {plru_read[2], 1'b0, 1'b0};  // Hit on way 0
        2'b01:   plru_next = {plru_read[2], 1'b1, 1'b0};  // Hit on way 1
        2'b10:   plru_next = {1'b0, plru_read[1], 1'b1};  // Hit on way 2
        2'b11:   plru_next = {1'b1, plru_read[1], 1'b1};  // Hit on way 3
        default: plru_next = plru_read;
      endcase
      // Signal that a write update is taking place.
      plru_we = 1'b0;
    end

    plru_din = plru_next;
  end

  // ------------------------------------------------------------------------
  // 6) Write/Read Helper Signals
  // ------------------------------------------------------------------------
  logic [ 31:0] cache_wdata;
  logic [ 31:0] data_temp;
  logic [255:0] data_input;
  logic [ 31:0] data_read_temp;
  logic [ 31:0] cache_wmask;

  // ------------------------------------------------------------------------
  // 7) State Register
  // ------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) fsm_state <= IDLE;
    else fsm_state <= fsm_next_state;
  end

  // ------------------------------------------------------------------------
  // 8) Next-State & Output Logic (Combinational)
  // ------------------------------------------------------------------------
  always_comb begin
    // Default signal assignments
    fsm_next_state = fsm_state;
    ufp_resp       = 1'b0;
    ufp_rdata      = '0;
    dfp_addr       = 32'b0;
    dfp_read       = 1'b0;
    dfp_write      = 1'b0;
    dfp_wdata      = 256'bx;

    ufp_tag        = ufp_addr_q[31:9];
    ufp_idx        = ufp_addr_q[8:5];
    // ufp_offset: [4:2] plus two zeros to make 32-b word offset in a 256-b line
    ufp_offset     = {ufp_addr_q[4:2], 2'b00};

    // Default: no writes to arrays (active-high write disable)
    for (integer i = 0; i < 4; i++) begin
      data_we[i] = 1'b1;
      data_in[i] = 'x;
      tag_we[i]  = 1'b1;
      tag_in[i]  = 'x;
      vd_we[i]   = 1'b1;
      vd_in[i]   = 2'b0;
    end

    cache_wmask    = 32'b0;
    cache_wdata    = 32'b0;
    data_temp      = 32'b0;
    data_read_temp = 32'b0;
    data_input     = 256'b0;

    unique case (fsm_state)
      // ------------------------------------------------------------
      IDLE: begin
        if ((ufp_rmask != 4'b0) || (ufp_wmask != 4'b0)) begin
          fsm_next_state = TAG_CHECK;
          // Use the incoming address index
          ufp_idx = ufp_addr[8:5];
        end else begin
          fsm_next_state = IDLE;
        end
      end

      // ------------------------------------------------------------
      TAG_CHECK: begin
        if (hit_detected) begin
          // On hit, update valid/dirty and tag arrays
          vd_in[way_hit]  = {(dirty_out[way_hit] | (ufp_wmask_q != 4'b0)), 1'b1};
          vd_we[way_hit]  = 1'b0;

          tag_in[way_hit] = ufp_tag;
          tag_we[way_hit] = 1'b0;

          if (ufp_wmask_q != 4'b0) begin
            // Write operation: merge data with word write mask
            cache_wmask = 32'hFFFFFFFF;
            data_temp   = data_hit_selected[ufp_offset*8+:32];
            data_input  = data_hit_selected;
            for (integer b = 0; b < 4; b++) begin
              if (ufp_wmask_q[b]) cache_wdata[(8*b)+:8] = ufp_wdata[(8*b)+:8];
              else cache_wdata[(8*b)+:8] = data_temp[(8*b)+:8];
            end
            data_input[ufp_offset*8+:32] = cache_wdata;
            data_in[way_hit] = data_input;
            data_we[way_hit] = 1'b0;

            ufp_resp = 1'b1;
          end else begin
            // Read operation: extract the proper word
            // data_read_temp = data_hit_selected[(ufp_offset[4:2]*32)+:32];
            // for (integer b = 0; b < 4; b++) begin
            //   if (ufp_rmask_q[b]) ufp_rdata[(8*b)+:8] = data_read_temp[(8*b)+:8];
            // end
            ufp_rdata = data_hit_selected;  // can get whole line now
            ufp_resp  = 1'b1;
          end

          // PLRU update on a hit is performed in the PLRU block above.
          fsm_next_state = IDLE;
        end else begin
          // On a miss, use the pipelined victim selection from the PLRU array.
          if (dirty_out[victim_way]) fsm_next_state = WRITEBACK;
          else fsm_next_state = ALLOCATE;
        end
      end

      // ------------------------------------------------------------
      ALLOCATE: begin
        ufp_resp = 1'b0;
        dfp_read = 1'b1;
        dfp_addr = {ufp_addr_q[31:5], 5'b00000};  // 256-b aligned address
        if (dfp_resp && dfp_raddr == dfp_addr) begin
          cache_wmask         = 32'hFFFFFFFF;
          data_in[victim_way] = dfp_rdata;
          data_we[victim_way] = 1'b0;

          vd_in[victim_way]   = {(ufp_wmask_q != 4'b0), 1'b1};  // valid=1, dirty=0
          vd_we[victim_way]   = 1'b0;

          tag_in[victim_way]  = ufp_tag;
          tag_we[victim_way]  = 1'b0;

          fsm_next_state      = WAIT;
        end else begin
          fsm_next_state = ALLOCATE;
        end
      end

      // ------------------------------------------------------------
      WAIT: begin
        // Wait one cycle for the new line to be recognized.
        fsm_next_state = TAG_CHECK;
      end

      // ------------------------------------------------------------
      WRITEBACK: begin
        ufp_resp  = 1'b0;
        dfp_addr  = {tag_array_dout[victim_way], ufp_idx, 5'b00000};
        dfp_write = 1'b1;
        dfp_wdata = data_array_dout[victim_way];
        if (dfp_resp) fsm_next_state = ALLOCATE;
        else fsm_next_state = WRITEBACK;
      end

      default: fsm_next_state = IDLE;
    endcase
  end

  // ------------------------------------------------------------------------
  // 9) Physical Arrays
  // ------------------------------------------------------------------------
  generate
    for (genvar i = 0; i < 4; i++) begin : ways
      // 256-b data array
      mp_cache_data_array data_array (
          .clk0  (clk),
          .csb0  (1'b0),
          .web0  (data_we[i]),
          .wmask0(cache_wmask),
          .addr0 (ufp_idx),
          .din0  (data_in[i]),
          .dout0 (data_array_dout[i])
      );

      // 23-b tag array
      mp_cache_tag_array tag_array (
          .clk0 (clk),
          .csb0 (1'b0),
          .web0 (tag_we[i]),
          .addr0(ufp_idx),
          .din0 (tag_in[i]),
          .dout0(tag_array_dout[i])
      );

      // 2-b valid/dirty array: [1] = dirty, [0] = valid
      sp_ff_array #(
          .S_INDEX(4),
          .WIDTH  (2)
      ) valid_dirty_array (
          .clk0 (clk),
          .rst0 (rst),
          .csb0 (1'b0),
          .web0 (vd_we[i]),
          .addr0(ufp_idx),
          .din0 (vd_in[i]),
          .dout0(vd_out[i])
      );
    end
  endgenerate

endmodule
