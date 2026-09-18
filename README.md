# Smart Traffic Management System

## Overview

A 4-way FPGA-based smart traffic management system implemented using Verilog RTL. The system controls traffic at four approaches: North, South, East and West. It supports normal traffic operation along with adaptive traffic control, emergency priority, pedestrian requests and night mode.

## Objective

The objective is to design a modular and safe traffic management system that:

* Controls traffic lights for a 4-way intersection.
* Adjusts GREEN duration according to traffic density.
* Gives priority to emergency vehicles and pedestrian requests.
* Ensures safe transitions between traffic phases.
* Provides a countdown display and night-mode operation.
* Can be simulated using ModelSim and demonstrated on an FPGA using Vivado.

## Specifications

### Traffic Inputs

Each approach uses a 4-bit digital traffic input.

| Input  | Traffic Count |
| ------ | ------------: |
| `0000` |             0 |
| `0001` |             1 |
| `0011` |             2 |
| `0111` |             3 |
| `1111` |             4 |

### Traffic Control

North-South and East-West traffic are controlled as two main phases.
The total demand for each phase is calculated as:

- N-S demand = `traffic_n_count + traffic_s_count`
- E-W demand = `traffic_e_count + traffic_w_count`

| Total Demand | GREEN Duration |
| -------------| -------------: |
| 0-1          |           10 s |
| 2-3          |           15 s |
| 4-8          |           20 s |

### Priority

The priority hierarchy is:

```text
Emergency
    ↓
Pedestrian
    ↓
Adaptive Traffic
    ↓
Normal Cycle
```

Emergency and pedestrian requests use safe transitions through YELLOW and ALL RED before entering the priority phase.

### Other Features

* Emergency vehicle handling for N/S/E/W.
* Pedestrian crossing request.
* Night mode with blinking yellow.
* Countdown timer.
* 7-segment display.
* Safety rule: N-S GREEN and E-W GREEN must never be active simultaneously.

## Architecture

The design is divided into independent RTL modules.

```text
             Traffic Inputs
          N   S   E   W
                │
                ▼
       ┌──────────────────┐
       │ traffic_input.v  │
       └────────┬─────────┘
                │
          Traffic Counts
                │
                ▼
     ┌──────────────────────┐
     │ adaptive_controller.v│
     └──────────┬───────────┘
                │
          Phase Demand
                │
                ▼
     ┌──────────────────────┐
     │ priority_controller.v│
     └──────────┬───────────┘
                │
     Emergency / Pedestrian
                │
                ▼
     ┌──────────────────────┐
     │ traffic_light_fsm.v  │
     └──────────┬───────────┘
                │
          ┌─────┴─────┐
          ▼           ▼
        N-S Lights   E-W Lights

        clock_timer.v
              │
              ▼
      seven_seg_driver.v
              │
              ▼
       7-Segment Display

      night_mode.v
              │
              ▼
      Blinking Yellow

   top_traffic_system.v
              │
              ▼
       Complete System
```

### RTL Modules

| File                      | Function                                                                    |
| ------------------------- | --------------------------------------------------------------------------- |
| `traffic_input.v`         | Processes N/S/E/W traffic inputs and produces traffic counts.               |
| `adaptive_controller.v`   | Determines traffic demand and requested GREEN duration.                     |
| `priority_controller.v`   | Handles emergency and pedestrian priority requests.                         |
| `traffic_light_fsm.v`     | Main finite-state machine controlling traffic-light states and transitions. |
| `clock_timer.v`           | Generates timing and countdown information.                                 |
| `night_mode.v`            | Controls blinking-yellow night operation.                                   |
| `seven_seg_driver.v`      | Drives the 7-segment countdown display.                                     |
| `top_traffic_system.v`    | Top-level module connecting all RTL blocks.                                 |
| `top_traffic_system_tb.v` | Testbench for complete-system simulation and verification.                  |
| `<FPGA_board>.xdc`        | FPGA pin and timing constraints for hardware implementation.                |

### Normal Traffic Sequence

```text
N-S GREEN
    ↓
N-S YELLOW
    ↓
ALL RED
    ↓
E-W GREEN
    ↓
E-W YELLOW
    ↓
ALL RED
    ↓
Repeat
```

## Hardware Output

The FPGA demonstration provides the following outputs:

### Traffic Lights

Each of the four approaches has:

* RED
* YELLOW
* GREEN

Therefore, the system has **12 traffic-light outputs** in total.

```text
North → RED / YELLOW / GREEN
South → RED / YELLOW / GREEN
East  → RED / YELLOW / GREEN
West  → RED / YELLOW / GREEN
```

### 7-Segment Display

The 7-segment display shows the **remaining time of the current traffic phase**.

### Night Mode

When night mode is enabled, the traffic lights operate in **blinking-yellow mode**.

### FPGA Inputs

The hardware demo uses FPGA switches/buttons for:

* Traffic inputs
* Emergency requests
* Pedestrian request
* Night-mode control

The exact FPGA pin assignments are defined in the board-specific `.xdc` constraints file.

## Tools

* **ModelSim** — RTL simulation and verification
* **Xilinx Vivado** — synthesis, implementation and FPGA programming
