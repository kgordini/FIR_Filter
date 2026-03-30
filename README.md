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

## Verification/Results
All designs were verified using input and golden output data generated in MATLAB. The testbench compares each hardware output to the expected values. Every architecture produced matching outputs and passed verification.
