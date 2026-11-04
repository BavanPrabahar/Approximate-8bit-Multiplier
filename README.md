# ⚡ Design and Functional Verification of an Approximate 8-Bit Wallace Tree Multiplier

[![Verilog HDL](https://img.shields.io/badge/Language-Verilog_HDL-blue.svg)]()
[![ModelSim](https://img.shields.io/badge/Simulation-ModelSim_Lite_20.1-brightgreen.svg)]()
[![Quartus](https://img.shields.io/badge/Synthesis-Quartus_Prime_Lite_20.1-orange.svg)]()
[![FPGA](https://img.shields.io/badge/FPGA-Cyclone_II_E-purple.svg)]()
[![MATLAB](https://img.shields.io/badge/Analysis-MATLAB-red.svg)]()

> Implementation and functional verification of an **approximate 8-bit Wallace Tree Multiplier** using gate-level logic approximation (OR gate substitution for XOR) and approximate 4:2 compressors. Designed for error-tolerant applications in **multimedia processing, computer vision, and machine learning acceleration**, achieving a **~24.4% reduction in critical path propagation delay**.

---

## 📌 Executive Summary

Modern multimedia and deep learning workloads exhibit intrinsic error resilience: slight numerical inaccuracies in pixel arithmetic or neural weights produce virtually imperceptible perceptual degradation while offering substantial savings in power, silicon area, and delay.

In digital arithmetic, multiplication is among the most power- and delay-intensive operations. This project implements an **Approximate 8-Bit Multiplier** based on the Wallace tree reduction architecture. By substituting complex, high-delay XOR gates with simpler OR gates in half adders and full adders, we significantly reduce transistor counts and critical path latency.

### 🌟 Key Highlights
* **24.4% Delay Reduction:** Average propagation delay dropped from **$17.51\text{ ns}$** (Exact) to **$13.24\text{ ns}$** (Approximate).
* **Gate-Level Optimization:** Replaced power-hungry XOR gates (requiring up to 8–12 CMOS transistors) with compact OR gates (3–6 CMOS transistors).
* **4:2 Compressor Architecture:** Designed high-speed partial product reduction stages using approximate 4:2 compressors.
* **Error Tolerant Applications:** Validated through image blending in MATLAB, demonstrating high visual fidelity (PSNR) despite arithmetic approximations.

---

## 🔬 Theoretical Background & Gate-Level Comparison

In CMOS logic design, XOR gates are significantly slower and consume more static and dynamic power than primitive AND and OR gates due to deeper internal transistor stacks and higher parasitic capacitance.

### SPICE Normalized Relative Gate Comparison
| Gate | Relative Propagation Delay | Relative Power Consumption | Typical Transistor Count (CMOS) |
| :---: | :---: | :---: | :---: |
| **AND** | **0.58** | **0.42** | 6 |
| **OR** | **0.79** | **0.40** | 6 |
| **XOR** | **1.00** *(Reference)* | **1.00** *(Reference)* | 8 – 12 |

> **Design Principle:** Substituting XOR gates with OR gates eliminates deep transistor trees, directly improving critical path latency and dynamic switching power.

---

## 📐 Circuit Architectures & Approximations

### 1. Approximate Half Adder (`haa`)
* **Exact Half Adder:**
  $$\text{Sum} = A \oplus B, \quad \text{Carry} = A \cdot B$$
* **Approximate Half Adder (`haa`):**
  $$\text{Sum} = A + B \quad (\text{OR gate}), \quad \text{Carry} = A \cdot B$$
* *Truth Table:*
  | A | B | Exact Sum | Exact Carry | Approx Sum | Approx Carry | Error? |
  | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
  | 0 | 0 | 0 | 0 | 0 | 0 | No |
  | 0 | 1 | 1 | 0 | 1 | 0 | No |
  | 1 | 0 | 1 | 0 | 1 | 0 | No |
  | 1 | 1 | 0 | 1 | **1** | 1 | **Yes (1/16 error)** |

### 2. Approximate Full Adder (`faa`)
* **Approximate Full Adder (`faa`):**
  $$\text{Sum} = (A \oplus B) + C_{\text{in}} \quad (\text{OR substitution on 2nd stage})$$
  $$C_{\text{out}} = (A \cdot B) + (B \cdot C_{\text{in}}) + (C_{\text{in}} \cdot A) \quad (\text{Exact Majority})$$

### 3. Approximate 4:2 Compressor
Compresses 4 partial product inputs ($x_1, x_2, x_3, x_4$) and carry-in ($C_{\text{in}}$) into Sum, Carry, and $C_{\text{out}}$ using a two-stage cascade of approximate adders.

---

## 🏗️ 8-Bit Multiplier Structural Architecture (Wallace Tree)

The 8-bit multiplier generates an $8 \times 8$ matrix of partial products ($a_i \cdot b_j$) and compresses them through a 5-stage Wallace tree reduction network:

```
[ Inputs: A[7:0], B[7:0] ]
          │
          ▼
   Stage 1: Partial Product Generation (64 AND gates) + Initial Reduction (haa, faa)
          │
          ▼
   Stage 2: Column Reduction using haa and faa
          │
          ▼
   Stage 3: Secondary Wallace Tree Reduction
          │
          ▼
   Stage 4: Intermediate Sum and Carry Vector Condensation
          │
          ▼
   Stage 5: Final Vector Addition (haa13, faa43-faa51)
          │
          ▼
   [ Product Output: Z[15:0] ]
```

---

## 📊 Experimental Results & Functional Verification

### 1. Functional Verification (ModelSim Waveforms)
Comparative verification between the exact multiplier and the approximate multiplier:

#### 4x4 Multiplier Verification:
* $8 \times 4 = 32 \longrightarrow$ **Approx: 32** *(Exact Match)*
* $10 \times 4 = 40 \longrightarrow$ **Approx: 40** *(Exact Match)*
* $10 \times 10 = 100 \longrightarrow$ **Approx: 84** *(Minor acceptable error for low-power operation)*

#### 8x8 Multiplier Verification:
* $132 \times 231 = 31,132 \longrightarrow$ **Approx: 30,492** *(Error: ~2.05%)*
* $255 \times 255 = 65,535 \longrightarrow$ **Approx: 65,025** *(Error: ~0.77%)*
* $128 \times 128 = 16,384 \longrightarrow$ **Approx: 16,384** *(Exact Match)*

---

### 2. Critical Path Timing & Delay Analysis (Quartus Prime Lite)
Static Timing Analysis (STA) performed across all input pins:

```
Exact Multiplier Critical Path Delay      :  17.51459 ns
Approximate Multiplier Critical Path Delay:  13.23722 ns
--------------------------------------------------------
Net Delay Improvement                     :   4.27737 ns (24.42% Faster)
```

---

## 🖼️ Application: Image Multiplication & Blending

Image multiplication and alpha blending algorithms are resilient to least-significant bit (LSB) inaccuracies. 

A MATLAB simulation environment (`matlab/image_blending_approx.m`) emulates the bit-level hardware architecture on 8-bit pixel values:
* Exact pixel blending vs. Approximate pixel blending demonstrates high visual fidelity with negligible PSNR degradation.

---

## 📁 Repository Structure

```text
Approximate-8bit-Multiplier/
├── README.md                          # Comprehensive project technical report
├── rtl/                               # Verilog HDL RTL source files
│   ├── haa.v                          # Approximate Half Adder (OR-gate Sum)
│   ├── faa.v                          # Approximate Full Adder
│   ├── compressor_4_2_approx.v        # Approximate 4:2 Compressor
│   ├── mul_app_4x4.v                  # Approximate 4x4 Multiplier
│   ├── mul_app.v                      # Approximate 8x8 Wallace Tree Multiplier
│   └── mul_exact_8x8.v                # Exact 8x8 Multiplier Reference Model
├── tb/                                # Testbench verification files
│   ├── tb_mul_app.v                   # Testbench for 8-bit approximate multiplier
│   └── tb_mul_app_4x4.v               # Testbench for 4x4 multiplier
├── sim/                               # Simulation & analytical models
│   └── verify_multiplier.py           # Python 65,536-case exhaustive verification
├── matlab/                            # Image processing application
│   └── image_blending_approx.m        # Image blending using approximate arithmetic
└── docs/                              # Schematics and timing analysis data
```

---

## 🛠️ Tools & Environments
* **HDL:** Verilog HDL (IEEE 1364-2001)
* **Simulation:** ModelSim Lite 20.1
* **Synthesis & Timing:** Intel Quartus Prime Lite 20.1
* **Target FPGA:** Intel Cyclone II E Family
* **Application Modeling:** MATLAB R2021a+ / Python 3.8+

---

## 👥 Project Team & Academic Credits

### Student Team Members (Department of ECE, SASTRA Deemed University):
1. **G. ReddySekhar Reddy** (Reg No: 125004220)
2. **Balanand Aswind** (Reg No: 125004036)
3. **G. Kranthi Kiran** (Reg No: 125004365)

### Supervisor:
* **Dr. Elamaran V.**  
  *Assistant Professor, School of Electrical & Electronics Engineering (SEEE),*  
  *SASTRA Deemed to be University, Thanjavur, Tamil Nadu, India.*

---

## 📚 References
1. Satyajit Mondal, Marimuthu R, Ravi S, *"Approximate 8-bit multipliers and their physical design implementation"*, e-Prime - Advances in Electrical Engineering, Electronics and Energy, vol. 6, 2023, 100300. [DOI: 10.1016/j.prime.2023.100300](https://doi.org/10.1016/j.prime.2023.100300).
2. A. Jain, N. Dugar, S. Yadav and K. Singh, *"EmpowerSoC: An Open-Source Power Analysis Engine based on Qflow"*, 2022 2nd Asian Conference on Innovation in Technology (ASIANCON), 2022. [DOI: 10.1109/ASIANCON55314.2022.9909414](https://doi.org/10.1109/ASIANCON55314.2022.9909414).
3. M. S. Ansari, H. Jiang, B. F. Cockburn and J. Han, *"Low-Power Approximate Multipliers Using Encoded Partial Products and Approximate Compressors"*, IEEE Journal on Emerging and Selected Topics in Circuits and Systems (JETCAS), vol. 8, no. 3, pp. 404-416, Sept. 2018. [DOI: 10.1109/JETCAS.2018.2832204](https://doi.org/10.1109/JETCAS.2018.2832204).
