package params;
  localparam A_REG_SIZE = 32;
  localparam A_WIDTH = $clog2(A_REG_SIZE);  // =5
  localparam P_REG_SIZE = 64;
  localparam P_WIDTH = $clog2(P_REG_SIZE);  // =7
  localparam ROB_SIZE = 16;
  localparam ROB_WIDTH = $clog2(ROB_SIZE);  // =5

  localparam FIFO_SIZE = 16;  // # entries AKA DEPTH
  localparam FIFO_WIDTH = 32;  // # bits
  localparam RS_DEPTH = 8;

  // localparam CDB_ALU = 0;
  // localparam CDB_MUL = 1;
  // localparam CDB_DIV = 2;
  // localparam CDB_LS = 3;
  // localparam CDB_BR = 4;

  localparam CDB_SIZE = 5;  // 5 func units
  localparam CDB_IND = $clog2(CDB_SIZE);
  localparam MULT_CYCLES = 4;
  localparam DIV_CYCLES = 10;
  localparam LOAD_DEPTH = 4;
  localparam STORE_DEPTH = 8;
  localparam LS_RS_SIZE = 8;
  localparam IMEM_PREFETCH_SIZE = 1;

endpackage


package rv32i_types;
  import params::*;
  typedef enum logic {
    rs1_out = 1'b0,
    pc_out  = 1'b1
  } alu_m1_sel_t;

  typedef enum logic {
    rs2_out = 1'b0,
    imm_out = 1'b1
  } alu_m2_sel_t;

  typedef enum logic [CDB_IND - 1:0] {
    alu,
    mul,
    div,
    ls,
    br,
    other
  } CDB_ind_t;

  // Instruction info package
  typedef struct packed {
    logic                 valid;
    logic [31:0]          inst;
    logic [2:0]           funct3;
    logic [6:0]           opcode;
    logic [31:0]          imm;
    logic [3:0]           aluop;
    alu_m1_sel_t          alu_m1_sel;
    alu_m2_sel_t          alu_m2_sel;
    logic [4:0]           rs1_addr;
    logic [P_WIDTH - 1:0] rs1_paddr;
    logic [4:0]           rs2_addr;
    logic [P_WIDTH - 1:0] rs2_paddr;
    logic [31:0]          rs1_v;
    logic [31:0]          rs2_v;
    logic [4:0]           rd_addr;
    logic [P_WIDTH - 1:0] rd_paddr;
    logic [31:0]          rd_v;
    logic                 rs1_use;
    logic                 rs2_use;
    logic                 imm_use;
    logic                 rd_use;
    logic [1:0]           mul_sel;
    logic [1:0]           div_sel;
    CDB_ind_t             CDB_ind;
    logic [31:0]          pc;
    logic [31:0]          pc_next;
    logic                 ls_sel;
    logic                 branch_taken;
    logic [31:0]          branch_target;
  } instr_pkt_t;

  // more mux def here (mp_verif/pkg/types.sv)
  typedef enum logic [6:0] {
    op_b_lui   = 7'b0110111,  // load upper immediate (U type)
    op_b_auipc = 7'b0010111,  // add upper immediate PC (U type)
    op_b_jal   = 7'b1101111,  // jump and link (J type)
    op_b_jalr  = 7'b1100111,  // jump and link register (I type)
    op_b_br    = 7'b1100011,  // branch (B type)
    op_b_load  = 7'b0000011,  // load (I type)
    op_b_store = 7'b0100011,  // store (S type)
    op_b_imm   = 7'b0010011,  // arith ops with register/immediate operands (I type)
    op_b_reg   = 7'b0110011   // arith ops with register operands (R type)
  } rv32i_opcode;

  typedef enum logic [6:0] {
    op_b_lui_   = 7'b0110111,  // load upper immediate (U type)
    op_b_auipc_ = 7'b0010111,  // add upper immediate PC (U type)
    // op_b_jal   = 7'b1101111,  // jump and link (J type)
    // op_b_jalr  = 7'b1100111,  // jump and link register (I type)
    // op_b_br    = 7'b1100011,  // branch (B type)
    // op_b_load  = 7'b0000011,  // load (I type)
    // op_b_store = 7'b0100011,  // store (S type)
    op_b_imm_   = 7'b0010011,  // arith ops with register/immediate operands (I type)
    op_b_reg_   = 7'b0110011   // arith ops with register operands (R type)
  } lim_op;

  typedef enum logic [2:0] {
    arith_f3_add  = 3'b000,  // check logic 30 for sub if op_reg op
    arith_f3_sll  = 3'b001,
    arith_f3_slt  = 3'b010,
    arith_f3_sltu = 3'b011,
    arith_f3_xor  = 3'b100,
    arith_f3_sr   = 3'b101,  // check logic 30 for logical/arithmetic
    arith_f3_or   = 3'b110,
    arith_f3_and  = 3'b111
  } arith_f3_t;

  typedef enum logic [2:0] {
    load_f3_lb  = 3'b000,
    load_f3_lh  = 3'b001,
    load_f3_lw  = 3'b010,
    load_f3_lbu = 3'b100,
    load_f3_lhu = 3'b101
  } load_f3_t;

  typedef enum logic [2:0] {
    store_f3_sb = 3'b000,
    store_f3_sh = 3'b001,
    store_f3_sw = 3'b010
  } store_f3_t;

  typedef enum logic [2:0] {
    branch_f3_beq  = 3'b000,
    branch_f3_bne  = 3'b001,
    branch_f3_blt  = 3'b100,
    branch_f3_bge  = 3'b101,
    branch_f3_bltu = 3'b110,
    branch_f3_bgeu = 3'b111
  } branch_f3_t;

  typedef enum logic [3:0] {
    alu_op_add   = 4'b0000,
    alu_op_sub   = 4'b0001,
    alu_op_slti  = 4'b0100,
    alu_op_sltiu = 4'b0110,
    alu_op_xor   = 4'b1000,
    alu_op_or    = 4'b1100,
    alu_op_and   = 4'b1110,
    alu_op_sll   = 4'b0010,
    alu_op_srl   = 4'b1010,
    alu_op_sra   = 4'b1011
  } alu_ops;

  // You'll need this type to randomly generate variants of certain
  // instructions that have the funct7 field.
  typedef enum logic [6:0] {
    base    = 7'b0000000,
    variant = 7'b0100000,
    extension = 7'b0000001 // MUL, DIV, REM
  } funct7_t;

  typedef union packed {
    logic [31:0] word;

    struct packed {
      logic [11:0] i_imm;
      logic [4:0]  rs1;
      logic [2:0]  funct3;
      logic [4:0]  rd;
      rv32i_opcode opcode;
    } i_type;

    struct packed {
      logic [6:0]  funct7;
      logic [4:0]  rs2;
      logic [4:0]  rs1;
      logic [2:0]  funct3;
      logic [4:0]  rd;
      rv32i_opcode opcode;
    } r_type;

    struct packed {
      logic [11:5] imm_s_top;
      logic [4:0] rs2;
      logic [4:0] rs1;
      logic [2:0] funct3;
      logic [4:0] imm_s_bot;
      lim_op opcode;
    } s_type;


    struct packed {
      logic imm_b12;
      logic [10:5] imm_b_top;
      logic [4:0] rs2;
      logic [4:0] rs1;
      logic [2:0] funct3;
      logic [4:1] imm_b_bot;
      logic imm_b11;
      rv32i_opcode opcode;
    } b_type;

    struct packed {
      logic [31:12] imm;
      logic [4:0]   rd;
      rv32i_opcode  opcode;
    } j_type;

    struct packed {
      logic [31:12] imm;
      logic [4:0]   rd;
      rv32i_opcode  opcode;
    } u_type;


  } instr_t;

  // typedef struct packed {
  //   logic Commit_Ready;
  //   logic [63:0] order;
  //   logic [31:0] inst;
  //   logic [4:0] Arch_Register;
  //   logic [6:0] Phys_Register;
  //   logic regf_we;
  //   rvfi_t rvfi;
  // } ROB_t;

  typedef struct packed {
    logic        valid;
    logic [63:0] order;
    logic [31:0] inst;
    logic [4:0]  rs1_addr;
    logic [4:0]  rs2_addr;
    logic [31:0] rs1_rdata;
    logic [31:0] rs2_rdata;
    logic [4:0]  rd_addr;
    logic [31:0] rd_wdata;
    logic [31:0] pc_rdata;
    logic [31:0] pc_wdata;
    logic [31:0] mem_addr;
    logic [3:0]  mem_rmask;
    logic [3:0]  mem_wmask;
    logic [31:0] mem_rdata;
    logic [31:0] mem_wdata;
  } rvfi_t;

  typedef struct packed {
    logic Commit_Ready;
    logic [4:0] Arch_Register;
    logic [P_WIDTH - 1:0] Phys_Register;
    logic flush;
    logic is_ls;
    rvfi_t rvfi;
    logic [31:0] pc_next;  // USED FOR BRANCH UNIT ONLY, OPTIMIZE LATER
    // logic [31:0] rd_data;
    logic [63:0] order;
    logic is_branch;
    logic branch_taken;
    logic [31:0] branch_target;
  } ROB_t;

  typedef struct packed {
    logic                   valid;
    logic [31:0]            imm;            // can reduce number of bits required later
    logic [2:0]             funct3;
    logic [1:0]             mul_sel;
    logic [1:0]             div_sel;
    logic [3:0]             aluop;
    alu_m1_sel_t            alu_m1_sel;
    alu_m2_sel_t            alu_m2_sel;
    logic [P_WIDTH - 1:0]   rs1_paddr;
    logic [P_WIDTH - 1:0]   rs2_paddr;
    logic [P_WIDTH - 1:0]   rd_paddr;
    logic [4:0]             rd_addr;
    logic                   p1_rdy;
    logic                   p2_rdy;
    logic                   rs1_use;
    logic                   rs2_use;
    logic                   imm_use;
    logic                   rd_use;
    logic [31:0]            pc;
    logic [31:0]            pc_next;
    CDB_ind_t               CDB_ind;
    logic [ROB_WIDTH - 1:0] ROB_entry;
    logic                   flush;
    logic [31:0]            rd_wdata;
    logic                   ls_sel;
    rvfi_t                  rvfi;
    logic                   branch_taken;
    logic [31:0]            branch_target;
  } RS_t;

  typedef struct packed {
    logic                   valid;
    // logic [63:0] order;
    // logic [31:0] inst;
    logic [31:0]            pc_wdata;
    // logic [4:0]  rs1_addr; // arch reg
    // logic [4:0]  rs2_addr;
    logic [P_WIDTH - 1:0]   rd_paddr;
    logic [4:0]             rd_addr;
    logic [31:0]            rd_data;
    // CDB_ind_t       CDB_ind;
    logic [ROB_WIDTH - 1:0] ROB_entry;
    logic                   flush;
    rvfi_t                  rvfi;
    logic                   is_branch;
    logic                   branch_taken;
    logic [31:0]            branch_target;
  } CDB_t;

  typedef struct packed {
    logic [63:0] order;
    logic [31:0] inst;
    logic [31:0] pc;
    logic branch_taken;
    logic [31:0] branch_target;
  } fetch_pkt_t;

  // typedef struct packed {
  //   logic [63:0] order;
  //   logic [31:0] inst;
  //   logic [31:0] pc;
  //   logic branch_taken;
  //   logic [31:0] branch_target;
  // } decode_pkt_t;

endpackage
