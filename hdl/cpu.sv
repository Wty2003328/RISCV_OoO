module cpu
  import rv32i_types::*;
  import params::*;
(
    input logic clk,
    input logic rst,

    output logic [31:0] bmem_addr,
    output logic        bmem_read,
    output logic        bmem_write,
    output logic [63:0] bmem_wdata,

    input logic        bmem_ready,  // bmem ready to take request
    input logic [31:0] bmem_raddr,
    input logic [63:0] bmem_rdata,
    input logic        bmem_rvalid  // bmem data available
);

  // fetch
  logic [31:0] imem_addr;  // cpu -> mem
  logic [ 3:0] imem_rmask;  // cpu -> mem
  logic [31:0] imem_rdata;  // mem -> cpu
  logic        imem_resp;  // mem -> cpu

  // memory
  logic [31:0] dmem_addr;  // cpu -> mem
  logic [ 3:0] dmem_rmask;  // cpu -> mem
  logic [ 3:0] dmem_wmask;  // cpu -> mem
  logic [31:0] dmem_rdata;  // mem -> cpu
  logic [31:0] dmem_wdata;  // cpu -> mem
  logic        dmem_resp;  // mem -> cpu

  // Stalling control signals
  logic        stalling_if;

  // Declear internal wires
  logic [ 4:0] rd_s;
  logic [31:0] rd_v;
  logic        regf_we;

  // Declear pc register signals
  logic [31:0] pc;
  logic [31:0] pc_next, flush_addr, pc_target;
  // logic   [63:0]  order;

  // Declear monitor signals
  logic        monitor_valid;
  logic [63:0] monitor_order;
  logic [31:0] monitor_inst;
  logic [ 4:0] monitor_rs1_addr;
  logic [ 4:0] monitor_rs2_addr;
  logic [31:0] monitor_rs1_rdata;
  logic [31:0] monitor_rs2_rdata;
  logic        monitor_regf_we;
  logic [ 4:0] monitor_rd_addr;
  logic [31:0] monitor_rd_wdata;
  logic [31:0] monitor_pc_rdata;
  logic [31:0] monitor_pc_wdata;
  logic [31:0] monitor_mem_addr;
  logic [ 3:0] monitor_mem_rmask;
  logic [ 3:0] monitor_mem_wmask;
  logic [31:0] monitor_mem_rdata;
  logic [31:0] monitor_mem_wdata;

  // linebuffer,cache,cache adapter signals (directly connected between modules)
  logic r_resp, w_resp, cache_resp, cache_resp_mem;  // response from cache adapter for read
  logic [255:0] rdata_out, cache_rdata, cache_rdata_mem, cache_wdata_mem;
  logic [31:0] linebuff_addr, adapter_raddr;
  logic [3:0] linebuff_rmask;  // linebuffer read mask

  // linebuffer,cache,cache adapter signals (goes to combinational logic in cpu)
  logic cache_read, bmem_read_next, cache_read_mem, cache_write_mem;
  logic [31:0] bmem_addr_next;

  //branch prdictor signals
  logic dispatch_br, predict_taken, predictor_stall;

  logic                 commit_br;
  logic [         31:0] commit_br_target;
  logic [ROB_WIDTH-1:0] commit_br_id;

  // Declare FIFO signals
  logic FIFO_i_full, FIFO_i_enq, FIFO_i_empty, FIFO_i_deq;
  fetch_pkt_t FIFO_out, FIFO_in, FIFO_out_decode;
  rvfi_t      rvfi_d;
  instr_pkt_t instr_d;
  logic rs_full, RS_enque, LS_enque;
  logic is_full_ROB;
  // FIFO logic
  logic flush;
  // logic deqed_before, empty_prev;
  // always_ff @(posedge clk ) begin
  //     empty_prev <= FIFO_i_empty;
  //     if (rst | flush | FIFO_i_empty) begin
  //         deqed_before <= 1'b0;
  //     end
  //     else if (FIFO_i_deq) begin
  //         deqed_before <= 1'b1;
  //     end
  // end
  logic ls_fifo_full;

  always_comb begin
    FIFO_i_deq = 1'b0;
    // && (LS_enque || RS_enque)
    //&& (LS_enque || RS_enque || !deqed_before)
    if (!FIFO_i_empty && !ls_fifo_full && !rs_full && !is_full_ROB) begin
      FIFO_i_deq = 1'b1;
    end
  end


  // FETCH AND DECODE INSTANTIATION
  // logic flush;
  // Define pc register
  always_ff @(posedge clk) begin
    if (rst) begin
      pc <= 32'hAAAAA000;
      // order <= '0;
    end
    if (!stalling_if) begin
      pc <= pc_next;
      // order <= order + 1;
    end
    if (flush) begin
      pc <= flush_addr;
    end else if (predict_taken) begin
      pc <= pc_target;
    end
  end
  // logic flush;


  // Instantiate pipeline stages
  if_stage if_stage_i (
      .rst(rst),
      .pc(pc),
      .pc_next(pc_next),
      .imem_addr(imem_addr),
      .imem_rmask(imem_rmask),
      // .imem_rdata(imem_rdata),
      .imem_resp(imem_resp),
      .stalling_if(stalling_if),
      .FIFO_full(FIFO_i_full),
      .enq(FIFO_i_enq),
      .flush(flush)

      // .predictor_stall(predictor_stall),
      // .predict_taken(predict_taken),
      // .pc_target(pc_target)
  );

  id_stage id_stage_i (
      .rst(rst),
      .fifo_out(FIFO_out_decode),
      .predict_taken(predict_taken),
      .pc_target(pc_target),
      .rvfi(rvfi_d),
      .instr(instr_d)
      // .stalling(stalling_if),
      // .fifo_enable(FIFO_i_deq)
  );

  logic [31:0]
      raddr_cache,
      raddr_cache_mem,
      arbiter_read_addr,
      adapter_raddr_out,
      arbiter_mem_raddr,
      arbiter_f_raddr;
  logic arbiter_read, arbiter_f_r_resp, arbiter_mem_r_resp, write_mem;
  logic [255:0] arbiter_f_rdata, arbiter_mem_rdata, wdata_mem;
  // FETCH adapter
  cache_adapter cache_adapter_if (
      .clk       (clk),
      .rst       (rst),
      .read      (arbiter_read),
      .addr_cpu  (arbiter_read_addr),
      // .write('0),
      // .waddr_cpu(),
      .bmem_read (bmem_read),
      .bmem_addr (bmem_addr),
      .bmem_write(bmem_write),
      // signal for reading
      .rdata_in  (bmem_rdata),                // bmem -> adapter
      .raddr_in  (bmem_raddr),                // bmem -> adapter
      .r_valid   (bmem_rvalid & bmem_ready),  // bmem -> adapter
      .rdata_out (rdata_out),                 // adapter_rdata, adapter -> cache
      .r_resp    (r_resp),                    // adapter_read_resp, adapter -> cache
      .raddr_out (adapter_raddr_out),

      // signals for writing (NOT NEEDED FOR FETCH)
      .wdata_in(wdata_mem),
      // .waddr_in('0),
      .w_valid(write_mem),
      .wdata_out(bmem_wdata),
      .w_resp(w_resp),
      .waddr_out()
  );

  mem_arbiter memory_choose (
      .clk(clk),
      .rst(rst),
      .fetch_addr(raddr_cache),
      .fetch_read(cache_read),
      .fetch_resp(arbiter_f_r_resp),  // arbiter tells f cache read done
      .fetch_rdata(arbiter_f_rdata),
      .fetch_raddr(arbiter_f_raddr),

      .mem_addr (raddr_cache_mem),
      .mem_read (cache_read_mem),
      .mem_write(cache_write_mem),
      .mem_wdata(cache_wdata_mem),
      .mem_resp (arbiter_mem_r_resp),
      .mem_rdata(arbiter_mem_rdata),
      .mem_raddr(arbiter_mem_raddr),

      .r_resp(r_resp),
      .w_resp(w_resp),
      .bmem_addr(arbiter_read_addr),
      .bmem_read(arbiter_read),

      .bmem_write(write_mem),
      .bmem_wdata(wdata_mem),
      .bmem_rdata(rdata_out),
      .bmem_raddr(adapter_raddr_out)
      // .bmem_rvalid() 
  );

  // FETCH cache
  cache cache_if (
      .clk(clk),
      .rst(rst),

      // linebuffer <-> cache
      .ufp_addr (linebuff_addr),   // linebuffer -> cache  
      .ufp_rmask(linebuff_rmask),  // linebuffer -> cache
      .ufp_wmask('0),
      .ufp_rdata(cache_rdata),     // cache -> linebuffer
      .ufp_wdata('0),
      .ufp_resp (cache_resp),      // cache -> linebuffer

      // cache <-> adapter
      .dfp_addr (raddr_cache),       // cache -> bmem
      .dfp_read (cache_read),
      .dfp_write(),
      .dfp_rdata(arbiter_f_rdata),   // adapter_rdata, adapter -> cache
      .dfp_wdata(),
      .dfp_resp (arbiter_f_r_resp),  // adapter_read_resp, adapter-> cache
      .dfp_raddr(arbiter_f_raddr)
  );
  // assign flush = '0;
  // FETCH linebuffer
  linebuffer linebuffer_if (
      .clk      (clk),
      .rst      (rst),
      // fetch <-> linebuffer
      .ufp_addr (imem_addr),   // fetch -> linebuffer
      .ufp_rdata(imem_rdata),  // linebuffer -> fetch
      .ufp_rmask(imem_rmask),  // fetch -> linebuffer
      .ufp_wdata('0),          // fetch no write
      .ufp_resp (imem_resp),   // linebuffer -> fetch

      // linebuffer <-> cache
      .dfp_addr (linebuff_addr),   // linebuffer -> cache
      .dfp_rmask(linebuff_rmask),  // linebuffer -> cache
      .dfp_rdata(cache_rdata),     // cache -> linebuffer
      .dfp_resp (cache_resp),      // cache -> linebuffer
      .flush    (flush)
  );

  // MEMORY cache
  cache cache_mem (
      .clk(clk),
      .rst(rst),

      // mem <-> cache
      .ufp_addr(dmem_addr),  // CONNECT WITH MEMORY     
      .ufp_rmask(dmem_rmask),
      .ufp_wmask(dmem_wmask),  // CONNECT WITH MEMORY
      .ufp_rdata(cache_rdata_mem),
      .ufp_wdata(dmem_wdata),
      .ufp_resp(cache_resp_mem),

      // cache <-> adapter
      .dfp_addr (raddr_cache_mem),     // cache -> bmem
      .dfp_read (cache_read_mem),
      .dfp_write(cache_write_mem),
      .dfp_rdata(arbiter_mem_rdata),   // adapter_rdata, adapter -> cache
      .dfp_wdata(cache_wdata_mem),
      .dfp_resp (arbiter_mem_r_resp),  // adapter_read_resp, adapter-> cache
      .dfp_raddr(arbiter_f_raddr)
  );

  always_comb begin
    FIFO_in = '0;
    if (imem_resp) begin
      FIFO_in.inst = imem_rdata;
      FIFO_in.pc   = imem_addr;
    end
  end

  // FETCH FIFO (instr queue)
  FIFO FIFO_if (
      .clk     (clk),
      .rst     (rst | flush | predict_taken),
      .enq     (FIFO_i_enq),                   // enqueue enable
      .deq     (FIFO_i_deq),                   // dequeue enable
      .data_in (FIFO_in),
      .data_out(FIFO_out),
      .full    (FIFO_i_full),
      .empty   (FIFO_i_empty)
  );



  RS_t ALU_IN, DIV_IN, MUL_IN, DISPATCH, MEM_IN, BR_IN;
  CDB_t CDB_out[CDB_SIZE];
  logic doing_mul, doing_div;
  logic complete_div, divide_by_0, hold_div, start_div;
  logic complete_mul, hold_mul, start_mul, send_valid_div, send_valid_mul;
  // CP3 logic
  // logic           ls_fifo_full;    
  assign doing_mul = ~send_valid_mul;
  assign doing_div = ~send_valid_div;
  assign hold_mul  = '0;
  assign hold_div  = '0;

  rs res_station (
      .clk(clk),
      .rst(rst || flush),
      .DISPATCH(DISPATCH),  // CONNECT TO DISPATCH
      .CDB(CDB_out),
      .dispatch_enqueu(RS_enque),  // CONNECT TO DISPATCH
      .doing_mul(doing_mul),
      .doing_div(doing_div),
      // .ls_fifo_full(ls_fifo_full),
      // .doing_br('0), // CONNECT TO BRANCH
      .start_mul(start_mul),
      .start_div(start_div),
      // .ls_fifo_en(ls_fifo_en), // CONNECT TO LOAD STORE
      // .start_br(),
      .ALU_IN(ALU_IN),
      .MUL_IN(MUL_IN),
      .DIV_IN(DIV_IN),
      // .MEM_IN(MEM_IN),
      .BR_IN(BR_IN),
      .rs_full(rs_full),
      .flush(flush)
  );


  // FUNCTIONAL UNITS

  logic [P_WIDTH - 1:0]
      rs1_paddr_alu,
      rs2_paddr_alu,
      rs1_paddr_div,
      rs2_paddr_div,
      rs1_paddr_mul,
      rs2_paddr_mul,
      rs1_paddr_br,
      rs2_paddr_br;
  logic [P_WIDTH - 1:0] rs1_paddr_ls, rs2_paddr_ls;  // for load/store
  logic [31:0]
      p1_data_alu,
      p2_data_alu,
      p1_data_div,
      p2_data_div,
      p1_data_mul,
      p2_data_mul,
      p1_data_ls,
      p2_data_ls,
      p1_data_br,
      p2_data_br;
  logic [31:0] alu_out, rd_ls_out;
  logic [32:0] div_out, rem_out;
  logic [65:0] mul_out;
  logic [32:0] a_div, b_div, a_mul, b_mul;
  RS_t alu_RS, mul_RS, div_RS, ls_RS, br_RS;
  logic                 ROB_head_LS;
  logic [ROB_WIDTH-1:0] ROB_head_entry;
  // CDB_t           CDB_out [CDB_SIZE];

  always_comb begin
    // CHECK IF DIV_RS_NEXT VALID
    a_div = '0;
    b_div = 33'b1;
    if (DIV_IN.valid) begin
      unique case (DIV_IN.div_sel[0])
        1'b0: begin  // signed
          a_div = {p1_data_div[31], p1_data_div};
          b_div = {p2_data_div[31], p2_data_div};
        end
        1'b1: begin  // unsigned
          a_div = {1'b0, p1_data_div};
          b_div = {1'b0, p2_data_div};
        end
      endcase
    end
  end

  always_comb begin
    a_mul = '0;
    b_mul = '0;
    if (MUL_IN.valid) begin
      unique case (MUL_IN.mul_sel[1])
        1'b0: begin  // signed
          a_mul = {p1_data_mul[31], p1_data_mul};
          b_mul = {p2_data_mul[31], p2_data_mul};
        end
        1'b1: begin  // unsigned
          a_mul = MUL_IN.mul_sel[0] ? {1'b0, p1_data_mul} : {p1_data_mul[31], p1_data_mul};
          b_mul = {1'b0, p2_data_mul};

        end
      endcase
    end
  end


  ls ls_i (
      .clk(clk),
      .rst(rst),
      .dmem_resp(cache_resp_mem),
      .dmem_rdata(cache_rdata_mem),
      .dmem_addr(dmem_addr),
      .dmem_rmask(dmem_rmask),
      .dmem_wmask(dmem_wmask),
      .dmem_wdata(dmem_wdata),
      .stalling_ls(),
      .rd_v(rd_ls_out),
      .LS_RS_next(DISPATCH),
      .ls_fifo_en(LS_enque),
      .ls_fifo_full(ls_fifo_full),
      .LS_RS_out(ls_RS),
      .rs1_paddr(rs1_paddr_ls),
      .rs2_paddr(rs2_paddr_ls),
      .p1_data(p1_data_ls),
      .p2_data(p2_data_ls),
      .ls_fifo_dequeue_rob(ROB_head_LS),
      .ROB_head_entry(ROB_head_entry),
      .flush(flush)
  );

  ALU adder (
      .rst(rst | flush),
      .clk(clk),
      .ALU_RS_next(ALU_IN),
      // Connect to PRF
      .rs1_paddr(rs1_paddr_alu),
      .rs2_paddr(rs2_paddr_alu),
      .p1_data(p1_data_alu),
      .p2_data(p2_data_alu),
      .aluout(alu_out),
      .ALU_RS_out(alu_RS)
  );

  DW_div_seq_inst divide (
      .clk(clk),
      .rst(rst | flush),  // NEED TO LOOK
      .hold(hold_div),
      .start(start_div),
      .a(a_div),
      .b(b_div),
      .DIV_RS_next(DIV_IN),
      .rs1_paddr(rs1_paddr_div),
      .rs2_paddr(rs2_paddr_div),
      // .p1_data(p1_data_div),
      // .p2_data(p2_data_div),
      .complete(complete_div),
      .divide_by_0(divide_by_0),
      .quotient(div_out),
      .remainder(rem_out),
      .DIV_RS_out(div_RS),
      .sent_valid(send_valid_div)
  );

  DW_mul_seq_inst mult (
      .clk(clk),
      .rst(rst | flush),
      .hold(hold_mul),
      .start(start_mul),
      .a(a_mul),
      .b(b_mul),
      .MUL_RS_next(MUL_IN),
      .rs1_paddr(rs1_paddr_mul),
      .rs2_paddr(rs2_paddr_mul),
      .complete(complete_mul),
      .mul_out(mul_out),
      .MUL_RS_out(mul_RS),
      .sent_valid(send_valid_mul)
  );

  branch_unit br_unit (
      .clk(clk),
      .rst(rst | flush),
      .BR_RS_next(BR_IN),
      .rs1_paddr(rs1_paddr_br),
      .rs2_paddr(rs2_paddr_br),
      .p1_data(p1_data_br),
      .p2_data(p2_data_br),
      // .br_pc_waddr(br_pc_waddr),      // branch packet from ROB
      // .br_rd_wdata(br_rd_wdata),
      .BR_RS_out(br_RS)
  );
  // CONTROL BUS



  CDB beep_beep_bus (
      .clk(clk),
      // .rst(rst),
      .alu_out(alu_out),
      .mul_out(mul_out),
      .div_out(div_out),
      .rem_out(rem_out),
      .rd_ls_out(rd_ls_out),
      .divide_by_0(divide_by_0),

      // RS_t from func units
      .alu_RS(alu_RS),
      .mul_RS(mul_RS),
      .div_RS(div_RS),
      .br_RS (br_RS),   // CONNECT TO BRANCH
      .ls_RS (ls_RS),   // CONNECT TO LOAD STORE
      .flush (flush),
      .WB_Bus(CDB_out)
  );


  logic               ROB_enque;
  logic [P_WIDTH-1:0] ROB_pd_dispatch;
  logic [A_WIDTH-1:0] ROB_rd_dispatch;

  // CDB_t                   CDB[CDB_SIZE];
  logic [63:0] flush_order, order;
  logic  [ROB_WIDTH-1:0] dispatch_ROB_Entry_ROB;
  logic  [  A_WIDTH-1:0] commit_rd_ROB;
  logic  [  P_WIDTH-1:0] commit_pd_ROB;
  rvfi_t                 commit_rvfi_ROB;
  // logic                   is_full_ROB;
  logic commit_ROB_use_rd, ROB_is_ls;
  // logic [ROB_WIDTH-1:0]   ROB_head_entry;

  ROB ROB_i (
      .clk               (clk),
      .rst               (rst),
      .ROB_enque         (ROB_enque),
      .ROB_pd_dispatch   (ROB_pd_dispatch),
      .ROB_rd_dispatch   (ROB_rd_dispatch),
      .ROB_order_dispatch(order),
      .CDB               (CDB_out),
      .ROB_is_ls         (ROB_is_ls),
      .flush             (flush),
      .flush_addr        (flush_addr),
      .flush_order       (flush_order),

      .dispatch_ROB_Entry_ROB(dispatch_ROB_Entry_ROB),
      .commit_rd_ROB         (commit_rd_ROB),
      .commit_pd_ROB         (commit_pd_ROB),
      .commit_rvfi_ROB       (commit_rvfi_ROB),
      .is_full_ROB           (is_full_ROB),
      .commit_ROB_use_rd     (commit_ROB_use_rd),
      .ROB_head_LS           (ROB_head_LS),
      .ROB_head_entry        (ROB_head_entry),

      .predict_taken(predict_taken),
      .pc_target(pc_target),

      .commit_br(commit_br),
      // .commit_br_target(commit_br_target),
      .commit_br_id(commit_br_id)

  );


  logic [P_WIDTH - 1:0] rd_paddr_RAT, rs1_paddr_RAT, rs2_paddr_RAT;
  logic dispatch_valid, ps1_valid, ps2_valid;
  logic [4:0] rd_dispatch, rs1_dispatch, rs2_dispatch;

  logic empty_fl, fl_deque;
  logic [ P_WIDTH - 1:0] pd_fl;
  logic [   P_WIDTH-1:0] freed_reg_phys;
  logic [   P_WIDTH-1:0] RRAT_val         [A_REG_SIZE];
  logic [P_REG_SIZE-1:0] backup_free_list;

  rename_dispatch rename (
      // CONNECT WITH RAT
      .clk                   (clk),
      .rst                   (rst),
      .ps1_RAT               (rs1_paddr_RAT),
      .ps1_valid             (ps1_valid),
      .ps2_RAT               (rs2_paddr_RAT),
      .ps2_valid             (ps2_valid),
      .pd_fl                 (pd_fl),                   // phys rd from free list
      .dispatch_ROB_Entry_ROB(dispatch_ROB_Entry_ROB),
      // .fifo_deq(FIFO_i_deq),
      .decode_output         (instr_d),
      .decode_rvfi           (rvfi_d),
      .is_empty_fl           (empty_fl),                // CONNECT TO FREE LIST
      .is_full_ROB           (is_full_ROB),
      .is_full_RS            (rs_full),
      .is_full_LS            (ls_fifo_full),
      .flush                 (flush),
      .flush_order           (flush_order),
      // .is_empty_fifo(FIFO_i_empty),
      .fl_deque              (fl_deque),
      .ROB_enque             (ROB_enque),
      .RS_enque              (RS_enque),
      .LS_enque              (LS_enque),
      .ROB_is_ls             (ROB_is_ls),
      .dispatch              (DISPATCH),
      .RAT_rd_dispatch       (rd_dispatch),             // CONNECT TO RAT
      .RAT_pd_dispatch       (rd_paddr_RAT),
      .RAT_rs1_dispatch      (rs1_dispatch),
      .RAT_rs2_dispatch      (rs2_dispatch),
      .pd_rob                (ROB_pd_dispatch),
      .rd_rob                (ROB_rd_dispatch),
      .RAT_dispatch_valid    (dispatch_valid),
      .order_rob             (order),
      .br_dispatch_en        (dispatch_br)
      // .fifo_deque()        // check which one works
  );

  RAT alias_table (
      .clk(clk),
      .rst(rst),
      .dispatch_valid(dispatch_valid),
      .rd_dispatch(rd_dispatch),
      .pd_dispatch(rd_paddr_RAT),
      .flush(flush),  // CONNECT TO ROB
      .RRAT(RRAT_val),
      .CDB(CDB_out),
      .rs1_dispatch(rs1_dispatch),
      .rs2_dispatch(rs2_dispatch),
      .ps1(rs1_paddr_RAT),
      .ps1_valid(ps1_valid),
      .ps2(rs2_paddr_RAT),
      .ps2_valid(ps2_valid)
  );

  // rrat rrat_i (
  //     .clk(clk),
  //     .rst(rst),
  //     .flush(flush),
  //     .commit(commit_ROB_use_rd),
  //     // .rd_use(rd_use),
  //     .commit_rd_ROB(commit_rd_ROB),
  //     .commit_pd_ROB(commit_pd_ROB),

  //     .RRAT(RRAT_val), // CONNECT WHEN NEEDED
  //     .freed_reg_phys(freed_reg_phys) // CONNECT TO FL
  // );
  rrat rrat_i (
      .clk(clk),
      .rst(rst),
      .commit(commit_ROB_use_rd),
      // .rd_use(rd_use),
      .commit_rd_ROB(commit_rd_ROB),
      .commit_pd_ROB(commit_pd_ROB),
      .flush(flush),
      .RRAT(RRAT_val),  // CONNECT WHEN NEEDED
      .freed_reg_phys(freed_reg_phys),  // CONNECT TO FL
      .backup_free_list(backup_free_list)  // CONNECT TO FL
  );

  free_list fl (
      .clk(clk),
      .rst(rst),
      .flush(flush),
      .fl_enque(commit_ROB_use_rd),  // need commit logic
      .fl_deque(fl_deque),
      .freed_reg_phys(freed_reg_phys),  // need commit logic
      .pd_fl(pd_fl),
      .is_empty_fl(empty_fl),
      .backup_free_list(backup_free_list)
  );

  prf reg_file (
      .clk(clk),
      .rst(rst),
      .CDB(CDB_out),
      .alu_rs1_paddr(rs1_paddr_alu),
      .alu_rs2_paddr(rs2_paddr_alu),
      .mul_rs1_paddr(rs1_paddr_mul),
      .mul_rs2_paddr(rs2_paddr_mul),
      .div_rs1_paddr(rs1_paddr_div),
      .div_rs2_paddr(rs2_paddr_div),
      .br_rs1_paddr(rs1_paddr_br),
      .br_rs2_paddr(rs2_paddr_br),
      .ls_rs1_paddr(rs1_paddr_ls),
      .ls_rs2_paddr(rs2_paddr_ls),

      .alu_rs1_v(p1_data_alu),
      .alu_rs2_v(p2_data_alu),
      .mul_rs1_v(p1_data_mul),
      .mul_rs2_v(p2_data_mul),
      .div_rs1_v(p1_data_div),
      .div_rs2_v(p2_data_div),
      .br_rs1_v (p1_data_br),
      .br_rs2_v (p2_data_br),
      .ls_rs1_v (p1_data_ls),
      .ls_rs2_v (p2_data_ls)
  );

  ooo_gshare_btb predictor_i (
      .clk          (clk),
      .rst          (rst),
      // fetch side
      .fetch_en     (FIFO_i_deq),
      // .pc_fetch          (pc),
      .predict_taken(predict_taken),
      .pc_target    (pc_target),

      .fifo_out       (FIFO_out),
      .fifo_out_decode(FIFO_out_decode),
      // dispatch side
      .dispatch_en    (dispatch_br),
      .dispatch_rob_id(dispatch_ROB_Entry_ROB),

      .stall_RS_LS   (rs_full || is_full_ROB || ls_fifo_full),
      // resolve side
      .resolve_en    (commit_br),
      .resolve_rob_id(commit_br_id),
      .mispredict    (flush),
      .actual_target (flush_addr)
      // .predictor_stall    (predictor_stall)
  );


  assign monitor_valid     = commit_rvfi_ROB.valid;
  assign monitor_order     = commit_rvfi_ROB.order;
  assign monitor_inst      = commit_rvfi_ROB.inst;
  assign monitor_rs1_addr  = commit_rvfi_ROB.rs1_addr;
  assign monitor_rs2_addr  = commit_rvfi_ROB.rs2_addr;
  assign monitor_rs1_rdata = commit_rvfi_ROB.rs1_rdata;
  assign monitor_rs2_rdata = commit_rvfi_ROB.rs2_rdata;
  assign monitor_rd_addr   = commit_rvfi_ROB.rd_addr;
  assign monitor_rd_wdata  = commit_rvfi_ROB.rd_wdata;
  assign monitor_pc_rdata  = commit_rvfi_ROB.pc_rdata;
  assign monitor_pc_wdata  = commit_rvfi_ROB.pc_wdata;
  assign monitor_mem_addr  = commit_rvfi_ROB.mem_addr;
  assign monitor_mem_rmask = commit_rvfi_ROB.mem_rmask;
  assign monitor_mem_wmask = commit_rvfi_ROB.mem_wmask;
  assign monitor_mem_rdata = commit_rvfi_ROB.mem_rdata;
  assign monitor_mem_wdata = commit_rvfi_ROB.mem_wdata;

endmodule : cpu
