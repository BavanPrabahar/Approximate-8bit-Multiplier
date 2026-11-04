#!/usr/bin/env python3
"""
Python Functional Verification and Error Metrics Analysis
for Approximate 8-bit Wallace Tree Multiplier.
Replicates the hardware logic gate-for-gate to compute:
- Mean Absolute Error (MAE)
- Mean Relative Error (MRE)
- Error Rate (ER)
- Peak Signal-to-Noise Ratio (PSNR)
"""

import numpy as np

def haa(a, b):
    # Approximate Half Adder: Sum = a | b, Carry = a & b
    return (a | b) & 1, (a & b) & 1

def faa(a, b, cin):
    # Approximate Full Adder: Sum = (a ^ b) | cin, Carry = majority
    sum_val = ((a ^ b) | cin) & 1
    carry_val = ((a & b) | (b & cin) | (cin & a)) & 1
    return sum_val, carry_val

def mul_approx_8x8(a, b):
    a_bits = [(a >> i) & 1 for i in range(8)]
    b_bits = [(b >> i) & 1 for i in range(8)]

    # Stage 1: Partial Product Generation & Initial Reduction
    z0 = a_bits[0] & b_bits[0]
    s1, c1 = haa(a_bits[1] & b_bits[0], a_bits[0] & b_bits[1])
    s2, c2 = faa(a_bits[2] & b_bits[0], a_bits[1] & b_bits[1], a_bits[0] & b_bits[2])
    s3, c3 = faa(a_bits[3] & b_bits[0], a_bits[2] & b_bits[1], a_bits[1] & b_bits[2])
    s4, c4 = faa(a_bits[4] & b_bits[0], a_bits[3] & b_bits[1], a_bits[2] & b_bits[2])
    m1, n1 = faa(a_bits[1] & b_bits[3], a_bits[0] & b_bits[4], 0)
    s5, c5 = faa(a_bits[5] & b_bits[0], a_bits[4] & b_bits[1], a_bits[3] & b_bits[2])
    m2, n2 = faa(a_bits[2] & b_bits[3], a_bits[1] & b_bits[4], a_bits[0] & b_bits[5])
    s6, c6 = faa(a_bits[6] & b_bits[0], a_bits[5] & b_bits[1], a_bits[4] & b_bits[2])
    s7, c7 = faa(a_bits[7] & b_bits[0], a_bits[6] & b_bits[1], a_bits[5] & b_bits[2])
    s8, c8 = faa(0, a_bits[7] & b_bits[1], a_bits[6] & b_bits[2])
    m3, n3 = faa(a_bits[3] & b_bits[3], a_bits[2] & b_bits[4], a_bits[1] & b_bits[5])
    m4, n4 = faa(a_bits[4] & b_bits[3], a_bits[3] & b_bits[4], a_bits[2] & b_bits[5])
    m5, n5 = faa(a_bits[5] & b_bits[3], a_bits[4] & b_bits[4], a_bits[3] & b_bits[5])
    m6, n6 = faa(a_bits[6] & b_bits[3], a_bits[5] & b_bits[4], a_bits[4] & b_bits[5])
    m7, n7 = faa(a_bits[7] & b_bits[3], a_bits[6] & b_bits[4], a_bits[5] & b_bits[5])
    m8, n8 = faa(0, a_bits[7] & b_bits[4], a_bits[6] & b_bits[5])

    # Stage 2
    z1 = s1
    x1, y1 = haa(c1, s2)
    x2, y2 = faa(c2, s3, a_bits[0] & b_bits[3])
    x3, y3 = faa(c3, s4, m1)
    x4, y4 = faa(c4, s5, m2)
    x5, y5 = faa(c5, s6, m3)
    x6, y6 = faa(c6, s7, m4)
    x7, y7 = faa(c7, s8, m5)
    x8, y8 = faa(c8, m6, a_bits[7] & b_bits[2])
    j1, k1 = haa(n2, a_bits[0] & b_bits[6])
    j2, k2 = faa(n3, a_bits[1] & b_bits[6], a_bits[0] & b_bits[7])
    j3, k3 = faa(n4, a_bits[2] & b_bits[6], a_bits[1] & b_bits[7])
    j4, k4 = faa(n5, a_bits[3] & b_bits[6], a_bits[2] & b_bits[7])
    j5, k5 = faa(n6, a_bits[4] & b_bits[6], a_bits[3] & b_bits[7])
    j6, k6 = faa(n7, a_bits[5] & b_bits[6], a_bits[4] & b_bits[7])
    j7, k7 = faa(n8, a_bits[6] & b_bits[6], a_bits[5] & b_bits[7])
    j8, k8 = haa(a_bits[7] & b_bits[6], a_bits[6] & b_bits[7])

    # Stage 3
    z2 = x1
    l1, r1 = haa(y1, x2)
    l2, r2 = haa(y2, x3)
    l3, r3 = faa(y3, x4, n1)
    l4, r4 = faa(y4, x5, j1)
    l5, r5 = faa(y5, x6, j2)
    l6, r6 = faa(y6, x7, j3)
    l7, r7 = faa(y7, x8, j4)
    l8, r8 = faa(y8, m7, j5)
    l9, r9 = haa(m8, j6)
    l10, r10 = haa(a_bits[7] & b_bits[5], j7)

    # Stage 4
    z3 = l1
    p1, q1 = haa(r1, l2)
    p2, q2 = haa(r2, l3)
    p3, q3 = haa(r3, l4)
    p4, q4 = faa(r4, l5, k1)
    p5, q5 = faa(r5, l6, k2)
    p6, q6 = faa(r6, l7, k3)
    p7, q7 = faa(r7, l8, k4)
    p8, q8 = faa(r8, l9, k5)
    p9, q9 = faa(r9, l10, k6)
    p10, q10 = faa(r10, j8, k7)
    p11, q11 = haa(a_bits[7] & b_bits[7], k8)

    # Stage 5: Final Vector Addition
    z4 = p1
    z5, v1 = haa(q1, p2)
    z6, v2 = faa(q2, p3, v1)
    z7, v3 = faa(q3, p4, v2)
    z8, v4 = faa(q4, p5, v3)
    z9, v5 = faa(q5, p6, v4)
    z10, v6 = faa(q6, p7, v5)
    z11, v7 = faa(q7, p8, v6)
    z12, v8 = faa(q8, p9, v7)
    z13, v9 = faa(q9, p10, v8)
    z14, v10 = faa(q10, p11, v9)
    z15 = q11

    z_bits = [z0, z1, z2, z3, z4, z5, z6, z7, z8, z9, z10, z11, z12, z13, z14, z15]
    return sum(bit << i for i, bit in enumerate(z_bits))

def run_exhaustive_verification():
    print("=" * 60)
    print("  Exhaustive Verification across all 65,536 combinations (0..255)")
    print("=" * 60)

    total_cases = 256 * 256
    errors = 0
    abs_errors = []
    rel_errors = []

    for a in range(256):
        for b in range(256):
            exact = a * b
            approx = mul_approx_8x8(a, b)
            diff = abs(exact - approx)

            if diff != 0:
                errors += 1
                abs_errors.append(diff)
                if exact != 0:
                    rel_errors.append(diff / exact)
            else:
                abs_errors.append(0)

    mae = np.mean(abs_errors)
    max_err = np.max(abs_errors)
    mre = np.mean(rel_errors) * 100 if rel_errors else 0.0
    error_rate = (errors / total_cases) * 100

    print(f"Total Combinations Tested : {total_cases}")
    print(f"Error Rate (ER)           : {error_rate:.2f}%")
    print(f"Mean Absolute Error (MAE) : {mae:.4f}")
    print(f"Mean Relative Error (MRE) : {mre:.4f}%")
    print(f"Maximum Error             : {max_err}")
    print("=" * 60)

if __name__ == "__main__":
    run_exhaustive_verification()
