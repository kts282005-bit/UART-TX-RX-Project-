// ============================================================================
// uart_loopback_tb.v — integration test: uart_tx -> uart_rx, back to back
//
// DV approach: this is the "system-level" test. Unit tests already proved
// each block works in isolation; this proves they agree on the same wire
// protocol. A simple scoreboard queues expected bytes and checks them off
// as uart_rx reports them.
// ============================================================================
`timescale 1ns / 1ps

module uart_loopback_tb;

    localparam CLK_PERIOD   = 10;
    localparam CLKS_PER_BIT = 20;
    localparam NUM_TESTS    = 30;

    reg        clk;
    reg        rst_n;
    reg        tx_start;
    reg [7:0]  tx_data;
    wire       tx_busy;
    wire       tx_done;
    wire       serial_line;
    wire       rx_done;
    wire [7:0] rx_data;
    wire       framing_error;

    // simple scoreboard: a queue of expected bytes
    reg [7:0] expected_q [0:255];
    integer   wr_ptr, rd_ptr;
    integer   pass_count, fail_count;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .tx_start  (tx_start),
        .tx_data   (tx_data),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done),
        .tx_serial (serial_line)
    );

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) rx_dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx_serial     (serial_line),
        .rx_done       (rx_done),
        .rx_data       (rx_data),
        .framing_error (framing_error)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // scoreboard check process — runs concurrently with stimulus
    always @(posedge clk) begin
        if (rst_n && rx_done) begin
            if (rx_data !== expected_q[rd_ptr]) begin
                $display("  [FAIL] expected 0x%02h, got 0x%02h (framing_error=%b)",
                          expected_q[rd_ptr], rx_data, framing_error);
                fail_count = fail_count + 1;
            end else begin
                $display("  [PASS] 0x%02h round-tripped correctly", rx_data);
                pass_count = pass_count + 1;
            end
            rd_ptr = rd_ptr + 1;
        end
    end

    task send_byte(input [7:0] value);
        begin
            // #1 lets any pending non-blocking update from the previous
            // clock edge (e.g. the DUT's own tx_busy going high) settle
            // before we read it — without this, wait(tx_busy==0) can read
            // a stale pre-update value and fire tx_start while the DUT is
            // still mid-frame, silently dropping that byte.
            #1;
            wait (tx_busy == 1'b0);
            @(posedge clk);
            tx_start           <= 1'b1;
            tx_data            <= value;
            expected_q[wr_ptr] <= value;
            wr_ptr             = wr_ptr + 1;
            @(posedge clk);
            tx_start <= 1'b0;
        end
    endtask

    integer k;
    reg [7:0] rnd_byte;

    initial begin
        clk        = 0;
        rst_n      = 0;
        tx_start   = 0;
        tx_data    = 8'h00;
        wr_ptr     = 0;
        rd_ptr     = 0;
        pass_count = 0;
        fail_count = 0;

        $dumpfile("sim/uart_loopback_tb.vcd");
        $dumpvars(0, uart_loopback_tb);

        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (3) @(posedge clk);

        $display("=== uart loopback: directed bytes ===");
        send_byte(8'h00);
        send_byte(8'hFF);
        send_byte(8'h55);
        send_byte(8'hAA);

        $display("=== uart loopback: randomized bytes ===");
        for (k = 0; k < NUM_TESTS; k = k + 1) begin
            rnd_byte = $random;
            send_byte(rnd_byte);
        end

        // let the last byte finish and be scored (see note in send_byte
        // above about why the #1 is needed before reading tx_busy)
        #1;
        wait (tx_busy == 1'b0);
        repeat (CLKS_PER_BIT * 2) @(posedge clk);

        $display("=====================================");
        $display("uart_loopback_tb RESULT: %0d passed, %0d failed (of %0d sent)",
                   pass_count, fail_count, wr_ptr);
        $display("=====================================");
        if (fail_count == 0 && pass_count == wr_ptr)
            $display("STATUS: ALL TESTS PASSED");
        else
            $display("STATUS: TESTS FAILED");

        $finish;
    end

endmodule
