// ============================================================================
// uart_tx.v — UART Transmitter (8 data bits, no parity, 1 stop bit: "8N1")
//
// Sends tx_data serially on tx_serial, LSB first, framed as:
//   [ start bit=0 ][ d0 d1 d2 d3 d4 d5 d6 d7 ][ stop bit=1 ]
//
// CLKS_PER_BIT = clk_freq_hz / baud_rate
//   e.g. 50 MHz clock, 115200 baud -> 50_000_000 / 115200 ~= 434
// ============================================================================
module uart_tx #(
    parameter CLKS_PER_BIT = 434
) (
    input  wire       clk,
    input  wire       rst_n,     // active-low synchronous-ish reset
    input  wire        tx_start,  // pulse high for 1 clk to begin a transfer
    input  wire [7:0]  tx_data,   // byte to send, sampled when tx_start fires
    output reg         tx_busy,   // high while a frame is being shifted out
    output reg         tx_done,   // pulses high for 1 clk when frame complete
    output reg         tx_serial  // the actual UART line (idles high)
);

    localparam S_IDLE    = 3'd0;
    localparam S_START   = 3'd1;
    localparam S_DATA    = 3'd2;
    localparam S_STOP    = 3'd3;
    localparam S_CLEANUP = 3'd4;

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  tx_data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            tx_serial   <= 1'b1;
            tx_busy     <= 1'b0;
            tx_done     <= 1'b0;
            clk_count   <= 16'd0;
            bit_index   <= 3'd0;
            tx_data_reg <= 8'd0;
        end else begin
            tx_done <= 1'b0; // default: only asserted for 1 cycle in CLEANUP

            case (state)
                // -------------------------------------------------------
                S_IDLE: begin
                    tx_serial <= 1'b1;
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    if (tx_start) begin
                        tx_data_reg <= tx_data;
                        tx_busy     <= 1'b1;
                        state       <= S_START;
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end

                // -------------------------------------------------------
                S_START: begin
                    tx_serial <= 1'b0; // start bit
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 16'd1;
                    end else begin
                        clk_count <= 16'd0;
                        state     <= S_DATA;
                    end
                end

                // -------------------------------------------------------
                S_DATA: begin
                    tx_serial <= tx_data_reg[bit_index]; // LSB first
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 16'd1;
                    end else begin
                        clk_count <= 16'd0;
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
                    tx_serial <= 1'b1; // stop bit
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 16'd1;
                    end else begin
                        clk_count <= 16'd0;
                        state     <= S_CLEANUP;
                    end
                end

                // -------------------------------------------------------
                S_CLEANUP: begin
                    tx_busy <= 1'b0;
                    tx_done <= 1'b1;
                    state   <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
