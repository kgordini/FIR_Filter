# FIR Filter Project

## Overview
This project designs a low-pass FIR filter in hardware. The filter is first designed in MATLAB, then implemented in Verilog/SystemVerilog, and verified using ModelSim. Hardware results such as area, clock frequency, and power were obatined using Quartus.

## Filter Specifications
Given:
- Passband edge: 0.2π
- Stopband edge: 0.23π
- Required attenuation: 80 dB

Final design:
- 202 taps
- Coefficients: 24-bits
- Input/Output: 16-bit

## Architectures
The FIR filter was deigned using several different hardware architectures. These include a baseline, pipelined, parallel L=2, parallel L=3, and a combined parallel L=3 with pipelining version. Each architecture uses the same coefficients but has a different computation style.

## Tools Used
- **MATLAB:** Used for FIR filter design, coefficient quantization, and generating golden output data for verification.
- **Quartus:** Used for synthesis, fitting, and hardware resource analysis (area, fmax, power).
- **ModelSim:** For functional verification and timing simulations of the systemverilog designs.

## Verification/Results
All designs were verified using input and golden output data generated in MATLAB. The testbench compares each hardware output to the expected values. Every architecture produced matching outputs and passed verification.

Metric | FIR_baseline | FIR_pipeline | FIR_parallel_L2 | FIR_parallel_L3 | FIR_parallel_L3_pipeline|
-------|--------------|--------------|-----------------|-----------------|-------------------------|
Logic Utilization (in ALMS) | 13,814/113,560 (12%) | 8,179/113,560 (7%) | 26,434/113,560 (23%) | 38,438/113,560 (34%) |38,312/113,560 (34%) |
Total Registers | 3249 | 9637 | 3249 | 3265 | 3344
Fmax | 36.14 MHz | 98.35 MHz | 35.33 MHz | 34.52 MHz | 44.91 MHz
Total Thermal Power Dissipation | 527.39 mW | 527.34 mW | 529.01 mW | 529.90 mW | 529.93 mW
Core Static Thermal Power Dissipation | 519.61 mW |  519.60 mW | 519.63 mW | 519.64 mW | 519.64 mW
I/O Thermal Power Dissipation | 7.78 mW | 7.73 mW | 9.38 mW | 10.26 mW | 10.28 mW

## Conclusion & Further Analysis
- **Pipelining Performance:** The [FIR_pipeline](FIR_Filter/verilog/FIR_pipeline.sv) architecture had the highest Fmax (98.35 MHz), showing how intermediate registers reduce critical path.
- **Parallelism Trade-offs:** [FIR_parallel_L3](FIR_Filter/verilog/FIR_parallel_L3.sv) increased throughput and increased logic utilization to 34% (38,438 ALMs) comapred to the baseline (12%).
- **Hardware Constraints:** To resolve an issue in Quartus, where the required DSP chain length (59) exceeded the device's physical limit of 28 per column. I changed the DSP Block Balancing synthesis setting to Logic Elements instead of Auto. This change allowed the parallel and parallel/pipeline code to run.
- **Final Verification:** All architectures successfully passed functional verification against the MATLAb golden output, confirming that the quantization of coefficients to 24-bits and data to 16-bits maintained the required 80dB stopband attenuation.

