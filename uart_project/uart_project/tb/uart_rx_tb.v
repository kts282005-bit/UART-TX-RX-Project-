// ============================================================================
// uart_rx_tb.v — unit-level testbench for uart_rx
//
// DV approach: drive rx_serial exactly like a real transmitter would
// (bit-banged from the testbench, not through uart_tx), so this test
// exercises uart_rx completely independently of uart_tx.
//
// NOTE ON TIMING: rx_done pulses for exactly 1 clock cycle at the MIDDLE
// of the stop bit (mid-bit sampling), which can land *before* the stimulus
// task finishes driving that stop bit for its full period. A sequential
// "wait(rx_done)" placed after the stimulus call can therefore start polling
// after the pulse has already come and gone, and hang forever. The fix used
// here is the standard one: a free-running scoreboard process that watches
// rx_done on every clock edge, independent of the stimulus task's timing.
// ============================================================================
`timescale 1ns / 1ps

module uart_rx_tb;

    localparam CLK_PERIOD    = 10;
    localparam CLKS_PER_BIT  = 20;
    localparam BIT_PERIOD_NS = CLK_PERIOD * CLKS_PER_BIT;

    reg  clk;
    reg  rst_n;
    reg  rx_serial;
    wire rx_done;
    wire [7:0] rx_data;
    wire framing_error;

    // scoreboard queue: expected data byte + expected framing_error flag
    reg [7:0] expected_data_q [0:63];
    reg       expected_ferr_q [0:63];
    integer   wr_ptr, rd_ptr;
    integer   pass_count, fail_count;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx_serial     (rx_serial),
        .rx_done       (rx_done),
        .rx_data       (rx_data),
        .framing_error (framing_error)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // free-running scoreboard: never blocks, so it can't miss a pulse
    always @(posedge clk) begin
        if (rst_n && rx_done) begin
            if (rx_data !== expected_data_q[rd_ptr]) begin
                $display("  [FAIL] expected 0x%02h, got 0x%02h", expected_data_q[rd_ptr], rx_data);
                fail_count = fail_count + 1;
            end else if (framing_error !== expected_ferr_q[rd_ptr]) begin
                $display("  [FAIL] 0x%02h: framing_error=%b, expected %b",
                          rx_data, framing_error, expected_ferr_q[rd_ptr]);
                fail_count = fail_count + 1;
            end else begin
                $display("  [PASS] 0x%02h received correctly (framing_error=%b)",
                          rx_data, framing_error);
                pass_count = pass_count + 1;
            end
            rd_ptr = rd_ptr + 1;
        end
    end

    // ---- task: bit-bang one 8N1 byte onto rx_serial, optionally with a bad stop bit ----
    task send_byte(input [7:0] value, input bad_stop);
        integer i;
        begin
            expected_data_q[wr_ptr] = value;
            expected_ferr_q[wr_ptr] = bad_stop;
            wr_ptr = wr_ptr + 1;

            rx_serial = 1'b0;              // start bit
            #(BIT_PERIOD_NS);
            for (i = 0; i < 8; i = i + 1) begin
                rx_serial = value[i];       // LSB first
                #(BIT_PERIOD_NS);
            end
            rx_serial = bad_stop ? 1'b0 : 1'b1; // stop bit (good=1, bad=0)
            #(BIT_PERIOD_NS);
            rx_serial = 1'b1;               // release line back to idle
        end
    endtask

    integer k;
    reg [7:0] rnd_byte;

    initial begin
        clk        = 0;
        rst_n      = 0;
        rx_serial  = 1'b1; // idle high
        wr_ptr     = 0;
        rd_ptr     = 0;
        pass_count = 0;
        fail_count = 0;

        $dumpfile("sim/uart_rx_tb.vcd");
        $dumpvars(0, uart_rx_tb);

        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (3) @(posedge clk);

        $display("=== uart_rx directed tests ===");
        send_byte(8'h00, 1'b0);
        send_byte(8'hFF, 1'b0);
        send_byte(8'h55, 1'b0);
        send_byte(8'hAA, 1'b0);
        send_byte(8'h3C, 1'b0);

        $display("=== uart_rx randomized tests ===");
        for (k = 0; k < 10; k = k + 1) begin
            rnd_byte = $random;
            send_byte(rnd_byte, 1'b0);
        end

        $display("=== uart_rx error-injection test (bad stop bit) ===");
        send_byte(8'hA5, 1'b1);

        // let the last frame's mid-stop-bit sample land, then a small margin
        repeat (CLKS_PER_BIT) @(posedge clk);

        $display("=====================================");
        $display("uart_rx_tb RESULT: %0d passed, %0d failed (of %0d sent)",
                   pass_count, fail_count, wr_ptr);
        $display("=====================================");
        if (fail_count == 0 && pass_count == wr_ptr)
            $display("STATUS: ALL TESTS PASSED");
        else
            $display("STATUS: TESTS FAILED");

        $finish;
    end

endmodule
