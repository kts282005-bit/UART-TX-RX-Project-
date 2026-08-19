// ============================================================================
// uart_tx_tb.v — unit-level testbench for uart_tx
//
// DV approach: treat the DUT as a black box. We only watch tx_serial from
// the outside (like a logic analyzer would), decode the frame it produces,
// and compare against what we told the TX to send.
// ============================================================================
`timescale 1ns / 1ps

module uart_tx_tb;

    localparam CLK_PERIOD    = 10;   // 100 MHz sim clock
    localparam CLKS_PER_BIT  = 20;   // small value -> fast sim (not a real baud rate)
    localparam BIT_PERIOD_NS = CLK_PERIOD * CLKS_PER_BIT;

    reg        clk;
    reg        rst_n;
    reg        tx_start;
    reg [7:0]  tx_data;
    wire       tx_busy;
    wire       tx_done;
    wire       tx_serial;

    integer pass_count;
    integer fail_count;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .tx_start  (tx_start),
        .tx_data   (tx_data),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done),
        .tx_serial (tx_serial)
    );

    // clock
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---- task: send one byte through the DUT and check what comes out ----
    task send_and_check(input [7:0] value);
        reg [7:0] captured;
        integer   i;
        begin
            @(posedge clk);
            tx_start <= 1'b1;
            tx_data  <= value;
            @(posedge clk);
            tx_start <= 1'b0;

            // wait for the line to drop (start bit) then align to bit centers
            @(negedge tx_serial);
            #(BIT_PERIOD_NS/2);
            if (tx_serial !== 1'b0) begin
                $display("  [FAIL] 0x%02h: start bit not low at its center", value);
                fail_count = fail_count + 1;
            end

            captured = 8'h00;
            for (i = 0; i < 8; i = i + 1) begin
                #(BIT_PERIOD_NS);
                captured[i] = tx_serial; // LSB first
            end

            #(BIT_PERIOD_NS);
            if (tx_serial !== 1'b1) begin
                $display("  [FAIL] 0x%02h: stop bit not high at its center", value);
                fail_count = fail_count + 1;
            end else if (captured !== value) begin
                $display("  [FAIL] 0x%02h: decoded 0x%02h instead", value, captured);
                fail_count = fail_count + 1;
            end else begin
                $display("  [PASS] 0x%02h sent and decoded correctly", value);
                pass_count = pass_count + 1;
            end

            // let the DUT return to idle before the next transfer
            wait (tx_busy == 1'b0);
            @(posedge clk);
        end
    endtask

    integer k;
    reg [7:0] rnd_byte;

    initial begin
        clk        = 0;
        rst_n      = 0;
        tx_start   = 0;
        tx_data    = 8'h00;
        pass_count = 0;
        fail_count = 0;

        $dumpfile("sim/uart_tx_tb.vcd");
        $dumpvars(0, uart_tx_tb);

        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (3) @(posedge clk);

        $display("=== uart_tx directed tests ===");
        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'h55);
        send_and_check(8'hAA);
        send_and_check(8'h3C);

        $display("=== uart_tx randomized tests ===");
        for (k = 0; k < 10; k = k + 1) begin
            rnd_byte = $random;
            send_and_check(rnd_byte);
        end

        $display("=====================================");
        $display("uart_tx_tb RESULT: %0d passed, %0d failed", pass_count, fail_count);
        $display("=====================================");
        if (fail_count == 0)
            $display("STATUS: ALL TESTS PASSED");
        else
            $display("STATUS: TESTS FAILED");

        $finish;
    end

endmodule
