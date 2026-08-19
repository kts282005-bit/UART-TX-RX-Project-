<<<<<<< HEAD
# UART TX/RX — Base-Level Verification Project

A UART transmitter and receiver (8 data bits, no parity, 1 stop bit — "8N1"),
each with its own self-checking testbench, plus an integration test that
loops the transmitter directly into the receiver. Built with free, open
tools: plain Verilog-2001, **Icarus Verilog** for simulation, and
**GTKWave** for waveform viewing, editable in **VS Code**.

This is deliberately scoped as a *base level* project — no UVM, no
SystemVerilog classes — but the testbenches follow real verification
practice: black-box stimulus/checking, a scoreboard, randomized tests
alongside directed ones, and an error-injection case. That structure is
what you'd extend later if you move to SystemVerilog/UVM.

## 1. Install the tools

**Ubuntu/Debian**
```bash
sudo apt-get update
sudo apt-get install iverilog gtkwave
```

**macOS (Homebrew)**
```bash
brew install icarus-verilog gtkwave
```

**Windows**
- Icarus Verilog: install from https://bleyer.org/icarus/ (includes `iverilog`, `vvp`, and a GTKWave build), or use WSL2 + the Ubuntu instructions above.
- Or install everything inside WSL2 (recommended if you're also using VS Code's Remote - WSL extension).

**VS Code**
- Install VS Code, then the recommended extension in `.vscode/extensions.json`
  (Verilog-HDL/SystemVerilog by mshr-h) for syntax highlighting.
- Open this folder in VS Code (`code .`), then use **Terminal → Run Task**
  to run any of the tasks defined in `.vscode/tasks.json` (or just use the
  Makefile from a terminal — both do the same thing).

Verify your install:
```bash
iverilog -V
vvp -V
gtkwave --version
```

## 2. Project structure

```
uart_project/
├── rtl/
│   ├── uart_tx.v          UART transmitter (DUT)
│   └── uart_rx.v          UART receiver (DUT)
├── tb/
│   ├── uart_tx_tb.v        unit testbench for uart_tx (black-box, decodes the serial line)
│   ├── uart_rx_tb.v        unit testbench for uart_rx (bit-bangs frames, incl. a bad-stop-bit case)
│   └── uart_loopback_tb.v  integration testbench: tx -> rx, scoreboard-checked
├── sim/                    compiled binaries + .vcd waveform dumps land here (gitignored-worthy)
├── Makefile
├── .vscode/
│   ├── tasks.json          run any testbench from VS Code's Run Task menu
│   └── extensions.json
└── README.md
```

## 3. Running it

```bash
make tx          # unit test: uart_tx alone
make rx          # unit test: uart_rx alone
make loopback     # integration test: uart_tx -> uart_rx
make all          # all three, in order
make wave_loopback # opens sim/uart_loopback_tb.vcd in GTKWave (needs a display)
make clean        # remove sim/ outputs
```

Every testbench prints PASS/FAIL per test case and a final
`STATUS: ALL TESTS PASSED` (or `TESTS FAILED`) line — that line is what
you'd hook into a CI/regression script.

Current status on this build: **15/15 TX tests, 16/16 RX tests, 34/34
loopback tests, all passing.**

## 4. What each block does

**`uart_tx`** — Idle/Start/Data/Stop/Cleanup FSM. On `tx_start`, latches
`tx_data`, shifts it out LSB-first on `tx_serial` framed with a start bit
(0) and stop bit (1), and pulses `tx_done` when finished. `CLKS_PER_BIT`
(a parameter) sets the baud rate relative to `clk`.

**`uart_rx`** — Watches `rx_serial` through a 2-flop synchronizer (it's an
async input), detects a falling edge, re-confirms it's real at the
*middle* of the start bit (rejects glitches), then samples each following
bit at its mid-point — the standard technique for sampling away from
signal transitions. Reports `rx_data` + `rx_done`, and flags
`framing_error` if the stop bit isn't high.

## 5. Bugs I found and fixed while building the testbenches

This is worth keeping in your portfolio notes, since it's the most
convincing evidence of DV skill: two testbenches passed initial visual
review but hung or mis-scored when actually run, both from the same root
cause — a **delta-cycle race** where a `wait(signal == value)` is evaluated
in the same simulation time step as the DUT's own non-blocking update to
that signal, so it reads the stale pre-update value instead of the new one.

1. `uart_rx_tb`: `rx_done` pulses at the *middle* of the stop bit (mid-bit
   sampling), which can land before the stimulus task finishes driving that
   bit — a sequential `wait(rx_done)` placed right after started polling
   too late and hung forever. **Fix:** replaced it with a free-running
   scoreboard `always` block that watches `rx_done` every cycle, so it can't
   miss the pulse regardless of timing.
2. `uart_loopback_tb`: `wait(tx_busy == 1'b0)` was checked immediately after
   clearing `tx_start`, in the same time step the DUT was about to raise
   `tx_busy` — so it read the old value, fired the next `tx_start` while
   the DUT was still mid-frame, and that byte was silently dropped (the FSM
   only looks at `tx_start` while idle). **Fix:** added a `#1` delay so the
   check happens after all non-blocking updates from that edge have
   settled — the standard idiom for this class of race.

## 6. Natural next steps (good for a v2 / resume bullet)

- Add parity support and a `parity_error` flag
- Add SVA assertions (e.g. "stop bit must be high", "no new start bit
  before stop bit is sampled") as always-on checkers
- Port the testbenches to SystemVerilog with functional coverage
  (baud rate × data patterns × error scenarios) and a coverage report
- Rebuild the same environment in UVM (driver/monitor/sequencer/scoreboard)
  once you're comfortable with this version — the test plan carries over
  directly
- Target real hardware: synthesize for an FPGA dev board and test over
  a USB-UART bridge with a terminal program (PuTTY/Tera Term/`screen`)
=======
# UART-TX-RX-Project-
"UART transmitter/receiver base-level verification project"
>>>>>>> f89f799e848e1bd8bed01082d170092deb8acb04
