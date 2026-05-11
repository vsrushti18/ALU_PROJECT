# Parameterized Arithmetic Logic Unit (ALU) — Design & Verification

**Author:** Srushti Vadnere | **Employee ID:** 6938 | **Date:** 11th May 2026

---

## Overview

This project implements and verifies a fully parameterized Arithmetic Logic Unit (ALU) in Verilog. The ALU supports both arithmetic and logical operations, controlled via a MODE signal, and is designed with a pipelined synchronous architecture.

---

## Features

- Parameterized operand width, command width, and output width
- Two operating modes:
  - **Arithmetic Mode (MODE = 1):** Addition, subtraction, increment/decrement, signed arithmetic, comparison, and multi-cycle multiplication
  - **Logical Mode (MODE = 0):** AND, OR, XOR, NAND, NOR, XNOR, NOT, shift, and rotate operations
- Carry and overflow detection
- Comparator flags: Greater (G), Equal (E), Less (L)
- Error flag (ERR) for invalid commands and input combinations
- Multi-cycle (3-cycle) multiplication operations (CMD 9 and CMD 10)
- Asynchronous reset and clock enable support

---

## Parameters

| Parameter  | Value | Description                    |
|------------|-------|--------------------------------|
| `IN_SIZE`  | 8     | Operand width (bits)           |
| `CMD_SIZE` | 4     | Command bus width (bits)       |
| `OUT_SIZE` | 16    | Result width (2 × IN_SIZE)     |

---

## Port Description

### Inputs

| Signal      | Width    | Description                                      |
|-------------|----------|--------------------------------------------------|
| `CLK`       | 1        | Clock (edge-sensitive)                           |
| `RST`       | 1        | Active-high asynchronous reset                   |
| `CE`        | 1        | Active-high clock enable                         |
| `MODE`      | 1        | 1 = Arithmetic, 0 = Logical                      |
| `INP_VALID` | 2        | 00=none, 01=OPA valid, 10=OPB valid, 11=both     |
| `CMD`       | CMD_SIZE | Operation select                                 |
| `OPA`       | IN_SIZE  | Operand A                                        |
| `OPB`       | IN_SIZE  | Operand B                                        |
| `CIN`       | 1        | Carry-in for ADD_CIN / SUB_CIN                   |

### Outputs

| Signal  | Width    | Description                            |
|---------|----------|----------------------------------------|
| `RES`   | OUT_SIZE | Operation result                       |
| `COUT`  | 1        | Carry-out                              |
| `OFLOW` | 1        | Overflow flag                          |
| `G`     | 1        | Comparator: OPA > OPB                  |
| `E`     | 1        | Comparator: OPA == OPB                 |
| `L`     | 1        | Comparator: OPA < OPB                  |
| `ERR`   | 1        | Error flag (invalid CMD or INP_VALID)  |

---

## Supported Operations

### Arithmetic (MODE = 1)

| CMD | Mnemonic  | Required INP_VALID | Operation                        |
|-----|-----------|--------------------|----------------------------------|
| 0   | ADD       | 2'b11              | OPA + OPB                        |
| 1   | SUB       | 2'b11              | OPA − OPB                        |
| 2   | ADD_CIN   | 2'b11              | OPA + OPB + CIN                  |
| 3   | SUB_CIN   | 2'b11              | OPA − OPB − CIN                  |
| 4   | INC_A     | 2'b01 or 2'b11     | OPA + 1                          |
| 5   | DEC_A     | 2'b01 or 2'b11     | OPA − 1                          |
| 6   | INC_B     | 2'b10 or 2'b11     | OPB + 1                          |
| 7   | DEC_B     | 2'b10 or 2'b11     | OPB − 1                          |
| 8   | CMP       | 2'b11              | Sets G, L, or E                  |
| 9   | MUL_INC   | 2'b11              | (OPA+1) × (OPB+1) — 3-cycle      |
| 10  | MUL_SHL   | 2'b11              | (OPA<<1) × OPB — 3-cycle         |
| 11  | SADD      | 2'b11              | Signed addition                  |
| 12  | SSUB      | 2'b11              | Signed subtraction               |
| >12 | —         | —                  | ERR = 1                          |

### Logical (MODE = 0)

| CMD  | Mnemonic  | Required INP_VALID | Operation                              |
|------|-----------|--------------------|----------------------------------------|
| 0    | AND       | 2'b11              | OPA & OPB                              |
| 1    | NAND      | 2'b11              | ~(OPA & OPB)                           |
| 2    | OR        | 2'b11              | OPA \| OPB                             |
| 3    | NOR       | 2'b11              | ~(OPA \| OPB)                          |
| 4    | XOR       | 2'b11              | OPA ^ OPB                              |
| 5    | XNOR      | 2'b11              | ~(OPA ^ OPB)                           |
| 6    | NOT_A     | 2'b01 or 2'b11     | ~OPA                                   |
| 7    | NOT_B     | 2'b10 or 2'b11     | ~OPB                                   |
| 8    | SHR1_A    | 2'b01 or 2'b11     | OPA >> 1                               |
| 9    | SHL1_A    | 2'b01 or 2'b11     | OPA << 1                               |
| 10   | SHR1_B    | 2'b10 or 2'b11     | OPB >> 1                               |
| 11   | SHL1_B    | 2'b10 or 2'b11     | OPB << 1                               |
| 12   | ROL_A_B   | 2'b11              | Rotate OPA left by OPB[2:0]            |
| 13   | ROR_A_B   | 2'b11              | Rotate OPA right by OPB[2:0]           |
| >14  | —         | —                  | ERR = 1                                |

> **Note:** ROL and ROR directions are swapped in the current RTL implementation (known bug).

---

## Timing Behavior

- **Single-cycle operations:** Output is registered one clock cycle after the input is sampled on the rising edge of CLK (when CE is high).
- **Multi-cycle operations (CMD 9 & 10):**
  - Cycle 0: Inputs captured; RES is undefined (X)
  - Cycle 1: Intermediate pipeline stage
  - Cycle 2: Final result written to RES

---

## Verification

The ALU was verified using a **self-checking Verilog testbench** with a cycle-accurate reference model instantiated in parallel with the DUT.

### Tools

| Tool       | Purpose                                        |
|------------|------------------------------------------------|
| Questa SIM | Simulation, coverage collection, pass/fail reporting |
| Vivado     | Waveform viewing and timing analysis           |

### Test Coverage

- All arithmetic and logical commands
- Valid and invalid INP_VALID combinations
- Corner cases: max values, overflow, underflow, carry-in
- Multi-cycle multiplication and interrupt handling
- Asynchronous reset verification
- Signed arithmetic and overflow detection
- Rotate with error conditions

### Coverage Results

| Metric                | Value   |
|-----------------------|---------|
| Overall RTL Coverage  | 97.18%  |
| Statement Coverage    | 100%    |
| Branch Coverage       | 98.13%  |
| FEC Expression        | 100%    |
| FEC Condition         | 100%    |
| Toggle Coverage       | 97.50%  |
| State Coverage        | 100%    |
| Transition Coverage   | 75%     |
| FSM Coverage          | 87.50%  |

### Test Results

| Total Tests | Passed | Failed |
|-------------|--------|--------|
| 177         | 14     | 163    |

Most failures were due to a **pipeline latency mismatch** — the DUT updates outputs one cycle earlier than the testbench expects.

---

## Known Bugs

1. **Missing pipeline register:** DUT outputs update immediately instead of after the required clock-cycle latency.
2. **Multi-cycle intermediate state:** CMD 9 and CMD 10 do not generate the expected X state during the processing cycle.
3. **Rotate direction swap:** ROL physically implements a right-rotate; ROR physically implements a left-rotate.
4. Missing ERR assertions in some invalid-input conditions.
5. Signed overflow handling issues in SADD/SSUB.

---

## Future Work

- Implement proper pipeline synchronization for all operations
- Fix multiplication intermediate-state handling and timing
- Correct rotate direction (ROL/ROR) implementation
- Improve FSM transition and toggle coverage
- Add constrained-random and assertion-based (SVA) verification
- Develop a UVM-based environment for scalable regression
- Perform synthesis and FPGA implementation for hardware validation
