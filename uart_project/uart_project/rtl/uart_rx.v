// ============================================================================
// uart_rx.v — UART Receiver (8 data bits, no parity, 1 stop bit: "8N1")
//
// Watches rx_serial for a falling edge (start bit), confirms it at the
// middle of the start bit, then samples each subsequent data bit at the
// middle of its bit period (standard UART RX technique — avoids sampling
// right at a transition, where the line may not have settled).
//
// CLKS_PER_BIT = clk_freq_hz / baud_rate  (must match the far-end TX)
// ============================================================================
module uart_rx #(
    parameter CLKS_PER_BIT = 434
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire        rx_serial,     // the raw UART line, async to clk
    output reg          rx_done,       // pulses high for 1 clk when byte ready
    output reg  [7:0]   rx_data,       // received byte, valid when rx_done=1
    output reg           framing_error // pulses high with rx_done if stop bit was wrong
);

    localparam S_IDLE    = 3'd0;
    localparam S_START   = 3'd1;
    localparam S_DATA    = 3'd2;
    localparam S_STOP    = 3'd3;
    localparam S_CLEANUP = 3'd4;

    // 2-flop synchronizer: rx_serial comes from outside the clock domain,
    // so we register it twice before using it to avoid metastability.
    reg rx_sync1, rx_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_serial;
            rx_sync2 <= rx_sync1;
        end
    end

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  rx_data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            rx_done       <= 1'b0;
            framing_error <= 1'b0;
            clk_count     <= 16'd0;
            bit_index     <= 3'd0;
            rx_data_reg   <= 8'd0;
            rx_data       <= 8'd0;
        end else begin
            rx_done       <= 1'b0; // default: only asserted for 1 cycle
            framing_error <= 1'b0;

            case (state)
                // -------------------------------------------------------
                S_IDLE: begin
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    if (rx_sync2 == 1'b0) begin
                        // possible start bit — go confirm it at mid-bit
                        state <= S_START;
                    end
                end

                // -------------------------------------------------------
                S_START: begin
                    if (clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        if (rx_sync2 == 1'b0) begin
                            // confirmed: real start bit, not a glitch
                            clk_count <= 16'd0;
                            state     <= S_DATA;
                        end else begin
                            state <= S_IDLE; // false alarm
                        end
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                // -------------------------------------------------------
                S_DATA: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 16'd1;
                    end else begin
                        clk_count <= 16'd0;
                        rx_data_reg[bit_index] <= rx_sync2; // LSB first
                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 3'd1;
                        end else begin
                            bit_index <= 3'd0;
                            state     <= S_STOP;
                        end
                    end
                end

                // -------------------------------------------------------
                S_STOP: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 16'd1;
                    end else begin
                        clk_count     <= 16'd0;
                        rx_data       <= rx_data_reg;
                        rx_done       <= 1'b1;
                        framing_error <= (rx_sync2 != 1'b1); // stop bit should be high
                        state         <= S_CLEANUP;
                    end
                end

                // -------------------------------------------------------
                S_CLEANUP: begin
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
