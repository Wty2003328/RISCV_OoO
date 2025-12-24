    longint timeout;
    initial begin
        $value$plusargs("TIMEOUT_ECE411=%d", timeout);
    end

    mem_itf_banked mem_itf(.*);
    dram_w_burst_frfcfs_controller mem(.itf(mem_itf));
    // random_tb random_tb(.itf(mem_itf));
    mon_itf #(.CHANNELS(8)) mon_itf(.*);
    monitor #(.CHANNELS(8)) monitor(.itf(mon_itf));

    cpu dut(
        .clk            (clk),
        .rst            (rst),

        .bmem_addr  (mem_itf.addr  ),
        .bmem_read  (mem_itf.read  ),
        .bmem_write (mem_itf.write ),
        .bmem_wdata (mem_itf.wdata ),
        .bmem_ready (mem_itf.ready ),
        .bmem_raddr (mem_itf.raddr ),
        .bmem_rdata (mem_itf.rdata ),
        .bmem_rvalid(mem_itf.rvalid)
    );

    `include "rvfi_reference.svh"

    always @(posedge clk) begin
        if (mon_itf.halt) begin
            
            $display("Flush count: %d", dut.ROB_i.flush_count);
            $display("Pred correct count: %d", dut.ROB_i.predicted_correct);
            $display("Total Branch count: %d", dut.ROB_i.total_branch);
            $display("Mispredict count: %d", dut.ROB_i.mispredict_jump);
            // $display("Fetch allocate count: %d", dut.cache_if.cache_allocate_count);
            $finish;
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        if (mem_itf.error != 0 || mon_itf.error != 0) begin
            $fatal;
        end
        timeout <= timeout - 1;
    end