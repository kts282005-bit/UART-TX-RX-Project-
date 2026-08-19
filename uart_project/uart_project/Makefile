# ============================================================================
# Makefile for the UART TX/RX project
#   make tx          -> compile + run the uart_tx unit testbench
#   make rx          -> compile + run the uart_rx unit testbench
#   make loopback    -> compile + run the tx<->rx integration testbench
#   make all         -> run all three, one after another
#   make wave_tx      / wave_rx / wave_loopback -> open the matching .vcd in GTKWave
#   make clean       -> remove compiled sim binaries and waveform dumps
# ============================================================================

IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

RTL_DIR  = rtl
TB_DIR   = tb
SIM_DIR  = sim

.PHONY: all tx rx loopback wave_tx wave_rx wave_loopback clean

all: tx rx loopback

tx:
	$(IVERILOG) -g2001 -o $(SIM_DIR)/uart_tx_tb.out $(RTL_DIR)/uart_tx.v $(TB_DIR)/uart_tx_tb.v
	$(VVP) $(SIM_DIR)/uart_tx_tb.out

rx:
	$(IVERILOG) -g2001 -o $(SIM_DIR)/uart_rx_tb.out $(RTL_DIR)/uart_rx.v $(TB_DIR)/uart_rx_tb.v
	$(VVP) $(SIM_DIR)/uart_rx_tb.out

loopback:
	$(IVERILOG) -g2001 -o $(SIM_DIR)/uart_loopback_tb.out $(RTL_DIR)/uart_tx.v $(RTL_DIR)/uart_rx.v $(TB_DIR)/uart_loopback_tb.v
	$(VVP) $(SIM_DIR)/uart_loopback_tb.out

wave_tx: tx
	$(GTKWAVE) $(SIM_DIR)/uart_tx_tb.vcd &

wave_rx: rx
	$(GTKWAVE) $(SIM_DIR)/uart_rx_tb.vcd &

wave_loopback: loopback
	$(GTKWAVE) $(SIM_DIR)/uart_loopback_tb.vcd &

clean:
	rm -f $(SIM_DIR)/*.out $(SIM_DIR)/*.vcd
