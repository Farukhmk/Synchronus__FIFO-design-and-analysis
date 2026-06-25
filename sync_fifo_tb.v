`timescale 1ns/1ps

module sync_fifo_tb;

    // ─────────────────────────────────────────────
    // Parameters
    // ─────────────────────────────────────────────
    localparam DATA_WIDTH = 8;
    localparam DEPTH      = 8;

    // ─────────────────────────────────────────────
    // DUT Signals
    // ─────────────────────────────────────────────
    reg                   clk;
    reg                   rst;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    reg                   rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire                  full;
    wire                  empty;

    // ─────────────────────────────────────────────
    // DUT Instantiation
    // ─────────────────────────────────────────────
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .wr_en   (wr_en),
        .wr_data (wr_data),
        .rd_en   (rd_en),
        .rd_data (rd_data),
        .full    (full),
        .empty   (empty)
    );

    // ─────────────────────────────────────────────
    // Clock Generation: 10ns period = 100MHz
    // ─────────────────────────────────────────────
    initial clk = 0;
    always  #5 clk = ~clk;

    // ─────────────────────────────────────────────
    // Error Counter
    // ─────────────────────────────────────────────
    integer errors = 0;



    // ── RESET TASK ───────────────────────────────
    // Drive reset for 2 full cycles then release
    task fifo_reset;
        begin
            @(negedge clk);
            rst    = 1;
            wr_en  = 0;
            rd_en  = 0;
            wr_data = 0;
            @(negedge clk);
            @(negedge clk);
            rst = 0;
        end
    endtask

    // ── WRITE TASK ───────────────────────────────
    // Drive wr_en and wr_data on falling edge
    // so the rising edge sees stable signals
    task fifo_write;
        input [DATA_WIDTH-1:0] data;
        begin
            @(negedge clk);     // drive on falling edge
            wr_en   = 1;
            wr_data = data;
            @(negedge clk);     // one full cycle later
            wr_en   = 0;        // deassert
        end
    endtask


    task fifo_read;
        output [DATA_WIDTH-1:0] data;
        begin
            @(negedge clk);
            rd_en = 1;
            #2;


            data  = rd_data;
            @(negedge clk);
            rd_en = 0;
        end
    endtask



    // full and empty can never both be 1
    always @(posedge clk) begin
        if (full && empty) begin
            $display("ASSERTION FAIL @ %0t: full AND empty both high!", $time);
            $finish;
        end
    end

    // count can never exceed DEPTH
    always @(posedge clk) begin
        if (dut.count > DEPTH) begin
            $display("ASSERTION FAIL @ %0t: count overflow! count=%0d", $time, dut.count);
            $finish;
        end
    end

    // full must assert exactly when count == DEPTH
    always @(posedge clk) begin
        if ((dut.count == DEPTH) && !full) begin
            $display("ASSERTION FAIL @ %0t: count==DEPTH but full not asserted!", $time);
            $finish;
        end
    end

    // empty must assert exactly when count == 0
    always @(posedge clk) begin
        if ((dut.count == 0) && !empty) begin
            $display("ASSERTION FAIL @ %0t: count==0 but empty not asserted!", $time);
            $finish;
        end
    end

    // wr_ptr must always be within valid range
    always @(posedge clk) begin
        if (dut.wr_ptr >= DEPTH) begin
            $display("ASSERTION FAIL @ %0t: wr_ptr out of range! wr_ptr=%0d", $time, dut.wr_ptr);
            $finish;
        end
    end

    // rd_ptr must always be within valid range
    always @(posedge clk) begin
        if (dut.rd_ptr >= DEPTH) begin
            $display("ASSERTION FAIL @ %0t: rd_ptr out of range! rd_ptr=%0d", $time, dut.rd_ptr);
            $finish;
        end
    end

    // ═════════════════════════════════════════════
    // TEST SEQUENCES
    // ═════════════════════════════════════════════
    reg [DATA_WIDTH-1:0] read_data;

    initial begin
        // initialise all inputs
        rst     = 0;
        wr_en   = 0;
        rd_en   = 0;
        wr_data = 0;


        $display("─────────────────────────────────");
        $display("TEST 1: Reset check");
        fifo_reset;

        if (empty !== 1'b1) begin
            $display("FAIL: empty should be 1 after reset, got %b", empty);
            errors = errors + 1;
        end
        if (full !== 1'b0) begin
            $display("FAIL: full should be 0 after reset, got %b", full);
            errors = errors + 1;
        end
        if (dut.count !== 0) begin
            $display("FAIL: count should be 0 after reset, got %0d", dut.count);
            errors = errors + 1;
        end
        $display("PASS: Reset OK");


        $display("─────────────────────────────────");
        $display("TEST 2: Write 3 items, read back in order");
        fifo_reset;

        fifo_write(8'hAA);
        fifo_write(8'hBB);
        fifo_write(8'hCC);

        fifo_read(read_data);
        if (read_data !== 8'hAA) begin
            $display("FAIL: Expected 0xAA, got 0x%0h", read_data);
            errors = errors + 1;
        end else $display("  Read 1: 0x%0h ✓", read_data);

        fifo_read(read_data);
        if (read_data !== 8'hBB) begin
            $display("FAIL: Expected 0xBB, got 0x%0h", read_data);
            errors = errors + 1;
        end else $display("  Read 2: 0x%0h ✓", read_data);

        fifo_read(read_data);
        if (read_data !== 8'hCC) begin
            $display("FAIL: Expected 0xCC, got 0x%0h", read_data);
            errors = errors + 1;
        end else $display("  Read 3: 0x%0h ✓", read_data);

        $display("PASS: Order preserved");


        $display("─────────────────────────────────");
        $display("TEST 3: Fill FIFO completely");
        fifo_reset;

        fifo_write(8'h01);
        fifo_write(8'h02);
        fifo_write(8'h03);
        fifo_write(8'h04);
        fifo_write(8'h05);
        fifo_write(8'h06);
        fifo_write(8'h07);
        fifo_write(8'h08);  // 8th write → full

        if (full !== 1'b1) begin
            $display("FAIL: full should be 1 after 8 writes");
            errors = errors + 1;
        end
        if (empty === 1'b1) begin
            $display("FAIL: empty should not be 1 when full");
            errors = errors + 1;
        end
        $display("PASS: Full flag correct (count=%0d)", dut.count);


        $display("─────────────────────────────────");
        $display("TEST 4: Overflow attempt");
        // FIFO still full from TEST 3 with [01..08]
        fifo_write(8'hFF);  // must be ignored

        // First read must still give 0x01
        fifo_read(read_data);
        if (read_data !== 8'h01) begin
            $display("FAIL: Overflow corrupted data! Got 0x%0h (expected 0x01)", read_data);
            errors = errors + 1;
        end else $display("  Overflow ignored correctly, first item = 0x%0h ✓", read_data);
        $display("PASS: Overflow handled correctly");


        $display("─────────────────────────────────");
        $display("TEST 5: Drain FIFO completely");
        fifo_reset;

        fifo_write(8'hAB);
        fifo_read(read_data);  // drain the one item

        if (empty !== 1'b1) begin
            $display("FAIL: empty should be 1 after draining");
            errors = errors + 1;
        end
        if (dut.count !== 0) begin
            $display("FAIL: count should be 0, got %0d", dut.count);
            errors = errors + 1;
        end
        $display("PASS: Empty flag correct");


        $display("─────────────────────────────────");
        $display("TEST 6: Underflow attempt");
        // FIFO is empty from TEST 5
        @(negedge clk);
        rd_en = 1;
        @(negedge clk);
        rd_en = 0;

        if (empty !== 1'b1) begin
            $display("FAIL: empty should still be 1 after underflow attempt");
            errors = errors + 1;
        end
        if (dut.count !== 0) begin
            $display("FAIL: count should still be 0 after underflow, got %0d", dut.count);
            errors = errors + 1;
        end
        $display("PASS: Underflow handled correctly");


        $display("─────────────────────────────────");
        $display("TEST 7: Simultaneous read and write");
        fifo_reset;

        fifo_write(8'hA1);
        fifo_write(8'hA2);
        // FIFO contains [A1, A2], count=2

        // Drive both rd_en and wr_en simultaneously
        @(negedge clk);
        wr_en   = 1;
        wr_data = 8'hA3;
        rd_en   = 1;
        #2;
        read_data = rd_data;    // capture 0xA1 before pointer moves
        @(negedge clk);
        wr_en = 0;
        rd_en = 0;

        if (read_data !== 8'hA1) begin
            $display("FAIL: Simultaneous read: Expected 0xA1, got 0x%0h", read_data);
            errors = errors + 1;
        end else $display("  Simultaneous read got: 0x%0h ✓", read_data);

        // FIFO should now contain [A2, A3], count still 2
        fifo_read(read_data);
        if (read_data !== 8'hA2) begin
            $display("FAIL: Expected 0xA2, got 0x%0h", read_data);
            errors = errors + 1;
        end else $display("  Next read: 0x%0h ✓", read_data);

        fifo_read(read_data);
        if (read_data !== 8'hA3) begin
            $display("FAIL: Expected 0xA3, got 0x%0h", read_data);
            errors = errors + 1;
        end else $display("  Next read: 0x%0h ✓", read_data);

        $display("PASS: Simultaneous read+write OK");


        $display("─────────────────────────────────");
        $display("TEST 8: Pointer wrap-around");
        fifo_reset;

        // Fill and drain 3 times to force pointer wrap-around
        repeat(3) begin
            fifo_write(8'hDE);
            fifo_write(8'hAD);
            fifo_write(8'hBE);
            fifo_write(8'hEF);
            fifo_read(read_data);
            fifo_read(read_data);
            fifo_read(read_data);
            fifo_read(read_data);
        end

        if (empty !== 1'b1) begin
            $display("FAIL: Should be empty after wrap-around test");
            errors = errors + 1;
        end
        if (dut.count !== 0) begin
            $display("FAIL: count should be 0, got %0d", dut.count);
            errors = errors + 1;
        end
        $display("PASS: Pointer wrap-around OK");
        $display("  Final wr_ptr=%0d, rd_ptr=%0d", dut.wr_ptr, dut.rd_ptr);


        $display("─────────────────────────────────");
        $display("TEST 9: Reset in middle of operation");

        fifo_write(8'h11);
        fifo_write(8'h22);
        fifo_write(8'h33);

        fifo_reset;

        if (empty !== 1'b1) begin
            $display("FAIL: empty should be 1 after mid-operation reset");
            errors = errors + 1;
        end
        if (dut.count !== 0) begin
            $display("FAIL: count should be 0 after reset, got %0d", dut.count);
            errors = errors + 1;
        end
        $display("PASS: Mid-operation reset OK");


        $display("─────────────────────────────────");
        if (errors == 0)
            $display("ALL TESTS PASSED ✅  (9/9)");
        else
            $display("FAILED: %0d error(s) found ❌", errors);
        $display("─────────────────────────────────");

        $finish;
    end

endmodule
