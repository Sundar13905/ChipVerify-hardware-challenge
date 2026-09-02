# 🔧 ChipVerify Hardware Challenge — Solutions

<div align="center">

![Verilog](https://img.shields.io/badge/HDL-Verilog-blue?style=for-the-badge&logo=v&logoColor=white)
![Progress](https://img.shields.io/badge/Progress-3%2F5%20Solved-yellow?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-In%20Progress-orange?style=for-the-badge)
![Made with](https://img.shields.io/badge/Made%20with-💙%20%26%20Verilog-informational?style=for-the-badge)

**My RTL solutions to the [ChipVerify Hardware Design Challenges](https://www.chipverify.com/)** — a set of classic digital design problems solved in Verilog, one module at a time.

</div>

---

## 📚 Table of Contents

- [Overview](#-overview)
- [Progress Tracker](#-progress-tracker)
- [Repo Structure](#-repo-structure)
- [Solutions](#-solutions)
  - [1️⃣ Debouncer](#1️⃣-debouncer)
  - [2️⃣ Traffic Light FSM](#2️⃣-traffic-light-fsm)
  - [3️⃣ 16-bit Adder](#3️⃣-16-bit-adder)
  - [4️⃣ 4-Channel Countdown Timer](#4️⃣-4-channel-countdown-timer-)
  - [5️⃣ Vending Machine FSM](#5️⃣-vending-machine-fsm-)
- [Tools Used](#️-tools-used)
- [About Me](#-about-me)

---

## 🧠 Overview

This repo is my personal playground for the **ChipVerify Hardware Design Challenge** series — five bite-sized but classic digital design problems that show up everywhere from interview whiteboards to real silicon. Each solution is written in **plain Verilog**, kept clean and well-commented, and organized into its own folder.

Think of this as a running logbook of RTL muscle-memory: debouncing a noisy switch today, arbitrating a vending machine tomorrow.

---

## 📊 Progress Tracker

| # | Challenge | Status | Difficulty |
|---|-----------|:------:|:----------:|
| 1 | Debouncer | ✅ Done | 🟢 Easy |
| 2 | Traffic Light FSM | ✅ Done | 🟡 Medium |
| 3 | 16-bit Adder | ✅ Done | 🟢 Easy |
| 4 | 4-Channel Countdown Timer | ✅ Done  | 🟡 Medium |
| 5 | Vending Machine FSM | ⏳ In Progress | 🔴 Hard |

```
Progress: [████████████████████░░░░] 80% (4/5 solved)
```

---

## 🗂️ Repo Structure

```
ChipVerify-hardware-challenge/
├── 01_debouncer/
│   └── debouncer.v
├── 02_traffic_light_fsm/
│   └── traffic_light_fsm.v
├── 03_16bit_adder/
│   └── adder_16bit.v
├── 04_countdown_timer/           # 🚧 coming soon
└── 05_vending_machine_fsm/       # 🚧 coming soon
```

---


---

## 🧩 Solutions

### 1️⃣ Debouncer

A parameterized, counter-based debouncer. `CLK_FREQ_KHZ` sets the clock frequency, and the debounce window is derived as `CLK_FREQ_KHZ × 5` cycles — a fixed **5 ms** settle time regardless of clock speed. A 9-bit counter tracks how long `btn_in` has disagreed with the current `btn_out`, and `9'd511` is used as a one-cycle "pulse" sentinel to flag `btn_pressed` / `btn_released`.

```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> COUNTING: btn_in ≠ btn_out
    COUNTING --> IDLE: btn_in glitches back to btn_out
    COUNTING --> UPDATE: counter == DEBOUNCE_CYCLES-1
    UPDATE --> PULSE: btn_out <= btn_in, counter <= 511
    PULSE --> IDLE: btn_pressed / btn_released asserted, counter <= 0
```

**Core idea:**
- While `btn_in == btn_out`, the counter stays at 0 (nothing to debounce).
- The moment they disagree, the counter starts climbing.
- Any glitch back to the current output resets the counter — a bounce doesn't count as a stable change.
- Once the counter survives a full `DEBOUNCE_CYCLES` window, `btn_out` is updated and the counter is parked at `511` for exactly one cycle to fire `btn_pressed`/`btn_released`, then it self-clears back to 0.

📁 [`01_debouncer/`](./01_debouncer)

---

### 2️⃣ Traffic Light FSM

A 4-state Moore FSM arbitrating a North-South / East-West intersection, with an `emergency` override that forces all-red.

```mermaid
stateDiagram-v2
    [*] --> NS_GREEN
    NS_GREEN --> NS_YELLOW: count == 30 (NS green for 30 cycles)
    NS_YELLOW --> EW_GREEN: count == 4 (NS yellow for 5 cycles)
    EW_GREEN --> EW_YELLOW: count == 29 (EW green for 30 cycles)
    EW_YELLOW --> NS_GREEN: count == 4 (EW yellow for 5 cycles)

    note right of NS_GREEN
        emergency = 1 → both lights forced to
        all-red (2'b00), state and count freeze
        until emergency deasserts
    end note
```

**Core idea:** `current_state` drives both light outputs combinationally, and an on-board `count` register times each phase (30 cycles for green, 5 for yellow). When `emergency` is asserted, the combinational logic overrides both `ns_light`/`ew_light` to red and the state register holds in place — no state transition happens until the emergency clears.

📁 [`02_traffic_light_fsm/`](./02_traffic_light_fsm)

---

### 3️⃣ 16-bit Adder — Brent-Kung Parallel Prefix

Not a plain ripple-carry adder — this is a **Brent-Kung parallel prefix adder**, a logarithmic-depth carry tree (`log₂16 = 4` levels) that computes all carries far faster than a linear ripple chain. The top module registers the combinational sum/carry-out on the clock edge.

```mermaid
graph TD
    A["A[15:0]"] --> GP["Bit-level Generate/Propagate<br/>g0 = A & B, p0 = A ^ B"]
    B["B[15:0]"] --> GP
    GP --> L1["Prefix Level 1<br/>(span 1)"]
    L1 --> L2["Prefix Level 2<br/>(span 2)"]
    L2 --> L3["Prefix Level 3<br/>(span 4)"]
    L3 --> L4["Prefix Level 4<br/>(span 8)"]
    L4 --> CARRY["Carry Chain<br/>carry[i+1] = G[i] | (P[i] & cin)"]
    CIN["cin"] --> CARRY
    CARRY --> SUM["sum[i] = p0[i] ^ carry[i]"]
    CARRY --> COUT["cout = carry[16]"]
    SUM --> REG["Registered on posedge clk"]
    COUT --> REG
```

**Core idea:**
- **Stage 0:** compute per-bit generate (`g0 = A & B`) and propagate (`p0 = A ^ B`).
- **Prefix tree (4 levels):** at each level, bits combine with a neighbor `2^level` positions back to build up group generate/propagate signals `G`/`P` — this is what gives Brent-Kung its `O(log n)` carry latency instead of `O(n)`.
- **Carry chain:** the final-level `G`/`P` values directly produce every carry bit in parallel.
- **Sum:** each output bit is just `p0[i] ^ carry[i]`.
- The `adder16` top module wraps the combinational `Brent_kung_16_bit` core and registers `sum`/`cout` on `posedge clk` (with active-low async reset).

📁 [`03_16bit_adder/`](./03_16bit_adder)

---

### 4️⃣ 4-Channel Countdown Timer

Four independent 16-bit countdown channels, each with load, run, stop, and a level-sensitive `expired` flag — built as one reusable per-channel module (`timer_channel_opt`) instantiated four times, rather than a single monolithic array. This was iterated through several synthesis-driven optimization passes (area was the tight constraint, not power or timing) before landing on this structure.

```mermaid
graph TD
    LE["load_en[3:0]"] --> PE["Priority Encoder<br/>load_grant[i] = load_en[i] & ~(lower bits)"]
    PE --> CH0["timer_channel_opt #0"]
    PE --> CH1["timer_channel_opt #1"]
    PE --> CH2["timer_channel_opt #2"]
    PE --> CH3["timer_channel_opt #3"]
    LV["load_val[15:0]"] --> CH0
    LV --> CH1
    LV --> CH2
    LV --> CH3
    RUN["run[3:0] / stop[3:0]"] --> CH0
    RUN --> CH1
    RUN --> CH2
    RUN --> CH3
    CH0 --> C0["count0, expired[0]"]
    CH1 --> C1["count1, expired[1]"]
    CH2 --> C2["count2, expired[2]"]
    CH3 --> C3["count3, expired[3]"]
```

**Core idea:**
- **Load priority:** a direct AND/OR priority encoder (`load_grant[i] = load_en[i] & ~load_en[i-1] & ...`) — lowest channel index wins on simultaneous loads. Written this way instead of an arithmetic `~x + 1` isolate-lowest-bit trick, since the arithmetic form pulls in an adder for no real benefit at this width.
- **Zero detection:** `expired = ~(|count)` — a straightforward reduction-NOR, cheaper than a 16-bit equality comparator against a constant.
- **Enable-flop inference, not a data-mux hold:** the key optimization. `ce = load_grant | (run & ~stop & ~expired)` is computed as its own signal and fed to the register's enable path (`else if (ce) count <= next_count;` with no explicit "else hold" branch). This lets synthesis map straight to the standard-cell library's dedicated enable flip-flop (`sky130_fd_sc_hd__edfxtp_1` in this flow) instead of building a 3-way hold-mux in front of a plain flop — a meaningfully cheaper way to express "do nothing this cycle" in silicon.
- **Async, active-low reset** (`negedge rst_n` in the sensitivity list) maps directly to the library's reset-capable flop variant, keeping reset out of the combinational cloud entirely rather than synthesizing it as extra gating logic.
- **Per-channel module instantiation** (`timer_channel_opt #(16)`, ×4) instead of a shared register array — each instance presents synthesis with identical, self-contained logic, making the enable-flop and priority patterns easier for the tool to recognize consistently across all four channels.

📁 [`04_countdown_timer/`](./04_countdown_timer)

---

### 5️⃣ Vending Machine FSM 🚧

*Coming soon — a Moore/Mealy FSM tracking inserted coins, dispensing product, and returning change.*

---

## 🛠️ Tools Used

- **HDL:** Verilog
- **Simulation:** *(add your simulator here — e.g. Icarus Verilog / ModelSim / Vivado XSim)*
- **Reference:** [ChipVerify](https://www.chipverify.com/) design challenge problem statements

---

## 👤 About Me

**Sundaravadivelan Karthikeyan**
Final-year ECE (Honors in Embedded Systems) student | RTL Design & Verification enthusiast

🔗 [GitHub — @Sundar13905](https://github.com/Sundar13905)

---

<div align="center">

⭐ *If you find this useful, drop a star — more solutions incoming!* ⭐

</div>

<div align="center">

⭐ *If you find this useful, drop a star — more solutions incoming!* ⭐

</div>
