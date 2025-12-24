// module wb_stage 
// import rv32i_types::*; 
// (
//     input logic rst,
//     input mem_wb_reg_t mem_wb,

//     output logic   [4:0]       rd_s,
//     output logic   [31:0]      rd_v,
//     output logic               regf_we,
//     input  logic               stalling
// );

//     logic   [31:0]      pc_next;
//     logic               valid;

//     assign valid = (stalling) ? '0 : mem_wb.instr_pkt.valid;
    
//     always_comb begin
//         pc_next = '0;
//         regf_we = '0;
//         rd_s = '0;
//         rd_v = '0;
//         if (!rst) begin 
//             pc_next = mem_wb.instr_pkt.pc_next;
//             regf_we = mem_wb.instr_pkt.regf_we;
//             rd_s = mem_wb.instr_pkt.rd_s;
//             rd_v = mem_wb.instr_pkt.rd_v;
//         end
//     end

// endmodule