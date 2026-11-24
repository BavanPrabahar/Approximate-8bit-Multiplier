#!/usr/bin/env python3
"""
Bit-accurate reference model and error analysis for the approximate
multipliers in rtl/mul_app.v (8x8 Wallace tree) and rtl/mul_app_4x4.v.

The model mirrors the RTL netlist instance for instance (same instance names,
same column tags), so it can be diffed against the Verilog by eye. It works on
numpy arrays, so all 65,536 input pairs are evaluated in a single call.

APPROX_MASK works exactly as in the RTL: bit i = 1 makes the adders in output
column i approximate, bit i = 0 makes them exact. With mask 0 the model must
equal a*b for every input; this is checked on every run and proves the wiring.

Error metrics (standard definitions from the approximate-computing literature):
  ER    error rate: share of inputs with a wrong product
  MED   mean error distance, mean |approx - exact|
  NMED  MED normalised by the largest exact product ((2^N - 1)^2)
  MRED  mean relative error distance, mean |approx - exact| / exact (exact != 0)
  WCE   worst-case error, max |approx - exact|
  bias  mean signed error, mean (approx - exact); > 0 means overestimation

Usage:
  python3 sim/verify_multiplier.py                    # 8x8, mask 0xFFFF
  python3 sim/verify_multiplier.py --mask 0x00FF      # approximate low 8 columns
  python3 sim/verify_multiplier.py --width 4          # 4x4 multiplier
  python3 sim/verify_multiplier.py --sweep            # accuracy vs approx columns
  python3 sim/verify_multiplier.py --golden out.hex   # vectors for the testbench
"""

import argparse
import sys

import numpy as np


# --------------------------------------------------------------------------
# Adder cells (rtl/haa.v, rtl/faa.v, rtl/compressor_4_2_approx.v)
# --------------------------------------------------------------------------
def _cells(mask):
    """Return ha/fa/comp42 functions that pick approximate or exact logic
    from the column number, as the RTL does with #(APPROX_MASK[col])."""

    def approx(col):
        return (mask >> col) & 1

    def ha(col, a, b):
        s = (a | b) if approx(col) else (a ^ b)
        return s, a & b

    def fa(col, a, b, cin):
        s = ((a ^ b) | cin) if approx(col) else (a ^ b ^ cin)
        return s, (a & b) | (b & cin) | (cin & a)

    def comp42(col, x1, x2, x3, x4, cin):
        s_int, cout = fa(col, x1, x2, x3)
        s, carry = fa(col, s_int, x4, cin)
        return s, carry, cout

    return ha, fa, comp42


def _bits(x, n):
    x = np.asarray(x, dtype=np.int64)
    return [(x >> i) & 1 for i in range(n)]


def _pack(z_bits):
    return sum(bit.astype(np.int64) << i for i, bit in enumerate(z_bits))


# --------------------------------------------------------------------------
# 8x8 Wallace tree: mirrors rtl/mul_app.v
# --------------------------------------------------------------------------
def mul_app_8x8(a, b, mask=0xFFFF):
    ha, fa, _ = _cells(mask)
    A, B = _bits(a, 8), _bits(b, 8)
    zero = np.zeros_like(A[0])

    def pp(i, j):
        return A[i] & B[j]

    # Stage 1: partial product reduction
    z0 = pp(0, 0)
    s1, c1 = ha(1, pp(1, 0), pp(0, 1))                      # ha1
    s2, c2 = fa(2, pp(2, 0), pp(1, 1), pp(0, 2))            # fa1
    s3, c3 = fa(3, pp(3, 0), pp(2, 1), pp(1, 2))            # fa2
    s4, c4 = fa(4, pp(4, 0), pp(3, 1), pp(2, 2))            # fa3
    m1, n1 = fa(4, pp(1, 3), pp(0, 4), zero)                # fa4
    s5, c5 = fa(5, pp(5, 0), pp(4, 1), pp(3, 2))            # fa5
    m2, n2 = fa(5, pp(2, 3), pp(1, 4), pp(0, 5))            # fa6
    s6, c6 = fa(6, pp(6, 0), pp(5, 1), pp(4, 2))            # fa7
    s7, c7 = fa(7, pp(7, 0), pp(6, 1), pp(5, 2))            # fa9
    s8, c8 = fa(8, zero, pp(7, 1), pp(6, 2))                # fa11
    m3, n3 = fa(6, pp(3, 3), pp(2, 4), pp(1, 5))            # fa8
    m4, n4 = fa(7, pp(4, 3), pp(3, 4), pp(2, 5))            # fa10
    m5, n5 = fa(8, pp(5, 3), pp(4, 4), pp(3, 5))            # fa12
    m6, n6 = fa(9, pp(6, 3), pp(5, 4), pp(4, 5))            # fa13
    m7, n7 = fa(10, pp(7, 3), pp(6, 4), pp(5, 5))           # fa14
    m8, n8 = fa(11, zero, pp(7, 4), pp(6, 5))               # fa15

    # Stage 2
    z1 = s1
    x1, y1 = ha(2, c1, s2)                                  # ha2
    x2, y2 = fa(3, c2, s3, pp(0, 3))                        # fa17
    x3, y3 = fa(4, c3, s4, m1)                              # fa18
    x4, y4 = fa(5, c4, s5, m2)                              # fa19
    x5, y5 = fa(6, c5, s6, m3)                              # fa20
    x6, y6 = fa(7, c6, s7, m4)                              # fa21
    x7, y7 = fa(8, c7, s8, m5)                              # fa23
    x8, y8 = fa(9, c8, m6, pp(7, 2))                        # fa25
    j1, k1 = ha(6, n2, pp(0, 6))                            # ha3
    j2, k2 = fa(7, n3, pp(1, 6), pp(0, 7))                  # fa22
    j3, k3 = fa(8, n4, pp(2, 6), pp(1, 7))                  # fa24
    j4, k4 = fa(9, n5, pp(3, 6), pp(2, 7))                  # fa26
    j5, k5 = fa(10, n6, pp(4, 6), pp(3, 7))                 # fa27
    j6, k6 = fa(11, n7, pp(5, 6), pp(4, 7))                 # fa28
    j7, k7 = fa(12, n8, pp(6, 6), pp(5, 7))                 # fa29
    j8, k8 = ha(13, pp(7, 6), pp(6, 7))                     # ha4

    # Stage 3
    z2 = x1
    l1, r1 = ha(3, y1, x2)                                  # ha5
    l2, r2 = ha(4, y2, x3)                                  # ha6
    l3, r3 = fa(5, y3, x4, n1)                              # fa30
    l4, r4 = fa(6, y4, x5, j1)                              # fa31
    l5, r5 = fa(7, y5, x6, j2)                              # fa32
    l6, r6 = fa(8, y6, x7, j3)                              # fa33
    l7, r7 = fa(9, y7, x8, j4)                              # fa34
    l8, r8 = fa(10, y8, m7, j5)                             # fa35
    l9, r9 = ha(11, m8, j6)                                 # ha7
    l10, r10 = ha(12, pp(7, 5), j7)                         # ha8

    # Stage 4
    z3 = l1
    p1, q1 = ha(4, r1, l2)                                  # ha9
    p2, q2 = ha(5, r2, l3)                                  # ha10
    p3, q3 = ha(6, r3, l4)                                  # ha11
    p4, q4 = fa(7, r4, l5, k1)                              # fa36
    p5, q5 = fa(8, r5, l6, k2)                              # fa37
    p6, q6 = fa(9, r6, l7, k3)                              # fa38
    p7, q7 = fa(10, r7, l8, k4)                             # fa39
    p8, q8 = fa(11, r8, l9, k5)                             # fa40
    p9, q9 = fa(12, r9, l10, k6)                            # fa41
    p10, q10 = fa(13, r10, j8, k7)                          # fa42
    p11, q11 = ha(14, pp(7, 7), k8)                         # ha12

    # Stage 5: final vector addition
    z4 = p1
    z5, v1 = ha(5, q1, p2)                                  # ha13
    z6, v2 = fa(6, q2, p3, v1)                              # fa43
    z7, v3 = fa(7, q3, p4, v2)                              # fa44
    z8, v4 = fa(8, q4, p5, v3)                              # fa45
    z9, v5 = fa(9, q5, p6, v4)                              # fa46
    z10, v6 = fa(10, q6, p7, v5)                            # fa47
    z11, v7 = fa(11, q7, p8, v6)                            # fa48
    z12, v8 = fa(12, q8, p9, v7)                            # fa49
    z13, v9 = fa(13, q9, p10, v8)                           # fa50
    z14, v10 = fa(14, q10, p11, v9)                         # fa51
    z15 = q11 | v10

    return _pack([z0, z1, z2, z3, z4, z5, z6, z7,
                  z8, z9, z10, z11, z12, z13, z14, z15])


# --------------------------------------------------------------------------
# 4x4 compressor-based multiplier: mirrors rtl/mul_app_4x4.v
# --------------------------------------------------------------------------
def mul_app_4x4(a, b, mask=0xFF):
    ha, fa, comp42 = _cells(mask)
    A, B = _bits(a, 4), _bits(b, 4)
    zero = np.zeros_like(A[0])

    def pp(i, j):
        return A[i] & B[j]

    s1, c1 = ha(1, pp(1, 0), pp(0, 1))                                    # ha_col1
    s2, c2 = fa(2, pp(2, 0), pp(1, 1), pp(0, 2))                          # fa_col2
    s3, carry3, cout3 = comp42(3, pp(3, 0), pp(2, 1), pp(1, 2), pp(0, 3), zero)  # comp3
    s4, carry4, cout4 = comp42(4, pp(3, 1), pp(2, 2), pp(1, 3), zero, cout3)     # comp4
    s5, c6 = fa(5, pp(3, 2), pp(2, 3), cout4)                             # fa_col5

    p0, p1 = pp(0, 0), s1
    p2, cy1 = ha(2, c1, s2)                                               # ha_add2
    p3, cy2 = fa(3, c2, s3, cy1)                                          # fa_add3
    p4, cy3 = fa(4, carry3, s4, cy2)                                      # fa_add4
    p5, cy4 = fa(5, carry4, s5, cy3)                                      # fa_add5
    p6, p7 = fa(6, c6, pp(3, 3), cy4)                                     # fa_add6

    return _pack([p0, p1, p2, p3, p4, p5, p6, p7])


MODELS = {8: (mul_app_8x8, 0xFFFF), 4: (mul_app_4x4, 0xFF)}


# --------------------------------------------------------------------------
# Analysis
# --------------------------------------------------------------------------
def all_inputs(width):
    n = 1 << width
    a, b = np.meshgrid(np.arange(n), np.arange(n), indexing="ij")
    return a.ravel(), b.ravel()  # index = a * 2^width + b


def error_metrics(a, b, approx, width):
    exact = a * b
    ed = approx - exact
    nz = exact != 0
    return {
        "ER": np.mean(ed != 0) * 100.0,
        "MED": np.mean(np.abs(ed)),
        "NMED": np.mean(np.abs(ed)) / ((1 << width) - 1) ** 2,
        "MRED": np.mean(np.abs(ed[nz]) / exact[nz]) * 100.0,
        "WCE": int(np.max(np.abs(ed))),
        "bias": np.mean(ed),
    }


def self_check(width):
    """With every adder exact (mask 0) the tree must multiply exactly."""
    model, _ = MODELS[width]
    a, b = all_inputs(width)
    bad = np.nonzero(model(a, b, mask=0) != a * b)[0]
    if bad.size:
        i = bad[0]
        print(f"SELF-CHECK FAILED: exact-cell {width}x{width} tree gives "
              f"{int(model(a[i], b[i], 0))} for {a[i]}*{b[i]} ({bad.size} bad cases)")
        return False
    print(f"Self-check: exact-cell {width}x{width} tree == a*b for all "
          f"{a.size} inputs")
    return True


def report(width, mask):
    model, _ = MODELS[width]
    a, b = all_inputs(width)
    m = error_metrics(a, b, model(a, b, mask), width)
    digits = (2 * width + 3) // 4
    print("=" * 62)
    print(f"  {width}x{width} approximate multiplier, APPROX_MASK = "
          f"0x{mask:0{digits}X}  ({a.size} input pairs)")
    print("=" * 62)
    print(f"Error rate (ER)                   : {m['ER']:.2f} %")
    print(f"Mean error distance (MED)         : {m['MED']:.2f}")
    print(f"Normalised MED (NMED)             : {m['NMED']:.5f}")
    print(f"Mean relative error dist. (MRED)  : {m['MRED']:.3f} %")
    print(f"Worst-case error (WCE)            : {m['WCE']}")
    print(f"Mean signed error (bias)          : {m['bias']:+.2f}")
    print("-" * 62)
    spots = [(132, 231), (255, 255), (128, 128), (16, 8), (64, 32)] if width == 8 \
        else [(8, 4), (10, 4), (10, 10), (15, 15)]
    for x, y in spots:
        p = int(model(x, y, mask))
        print(f"{x:4d} x {y:<4d} exact {x * y:6d}   approx {p:6d}   "
              f"error {p - x * y:+6d} ({(p - x * y) / max(x * y, 1) * 100:+.2f} %)")
    print("=" * 62)


def sweep(width):
    model, _ = MODELS[width]
    a, b = all_inputs(width)
    print(f"| Approx. columns (K) | APPROX_MASK | ER (%) | MED | NMED | MRED (%) | WCE | bias |")
    print("|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|")
    digits = (2 * width + 3) // 4
    for k in range(0, 2 * width + 1):
        mask = (1 << k) - 1
        m = error_metrics(a, b, model(a, b, mask), width)
        print(f"| {k} | 0x{mask:0{digits}X} | {m['ER']:.2f} | {m['MED']:.1f} | "
              f"{m['NMED']:.5f} | {m['MRED']:.3f} | {m['WCE']} | {m['bias']:+.1f} |")


def write_golden(path, width, mask):
    """One product per line in hex, line index = a * 2^width + b ($readmemh)."""
    model, _ = MODELS[width]
    a, b = all_inputs(width)
    digits = (2 * width + 3) // 4
    with open(path, "w") as f:
        for v in model(a, b, mask):
            f.write(f"{int(v):0{digits}x}\n")
    print(f"Wrote {a.size} golden vectors to {path}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--width", type=int, choices=(4, 8), default=8)
    ap.add_argument("--mask", type=lambda s: int(s, 0), default=None,
                    help="APPROX_MASK (default: all columns approximate)")
    ap.add_argument("--sweep", action="store_true",
                    help="metrics for K = 0..2N approximate low columns")
    ap.add_argument("--golden", metavar="FILE",
                    help="write golden vectors for the testbench")
    args = ap.parse_args()

    mask = MODELS[args.width][1] if args.mask is None else args.mask
    if not self_check(args.width):
        return 1
    if args.golden:
        write_golden(args.golden, args.width, mask)
    elif args.sweep:
        sweep(args.width)
    else:
        report(args.width, mask)
    return 0


if __name__ == "__main__":
    sys.exit(main())
