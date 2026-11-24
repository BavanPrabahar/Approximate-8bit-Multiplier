#!/usr/bin/env python3
"""
Technology-independent synthesis report for mul_app at several APPROX_MASK
settings: an open-source, reproducible companion to the Quartus timing numbers.

For each configuration it:
  1. synthesises rtl/mul_app.v with Yosys to generic AND/OR/XOR gates
     (synth -noabc, so the reported structure is the designed structure),
  2. re-simulates that gate netlist on all 65,536 inputs and checks it against
     the Python reference model (sim/verify_multiplier.py): an equivalence
     check of the synthesised netlist,
  3. reports gate counts, logic depth, and delay / dynamic-power estimates
     weighted by the normalised SPICE gate table from the README.

The delay and power columns are first-order estimates for comparing designs
against each other, not sign-off numbers: the delay is the gate-weighted
longest path (no wire load), and the power is the zero-delay toggle count of
each gate output over all 65,536 inputs in a fixed random order, weighted by
gate type. Both are normalised to the exact tree (APPROX_MASK = 0x0000).

Usage:  python3 synth/report.py [--yosys PATH] [--keep DIR]
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "sim"))
from verify_multiplier import all_inputs, error_metrics, mul_app_8x8  # noqa: E402

# Normalised gate delay / power (README "SPICE Normalized Relative Gate
# Comparison"; XOR = 1.00 reference).
GATE_DELAY = {"$_AND_": 0.58, "$_OR_": 0.79, "$_XOR_": 1.00}
GATE_POWER = {"$_AND_": 0.42, "$_OR_": 0.40, "$_XOR_": 1.00}
# Other Yosys gate types are not expected from this design, but newer Yosys
# versions may emit them. They are simulated correctly and weighted 1.0.
GATE_FUNC = {
    "$_AND_": lambda x, y: x & y,
    "$_OR_": lambda x, y: x | y,
    "$_XOR_": lambda x, y: x ^ y,
    "$_NOT_": lambda x: ~x,
    "$_NAND_": lambda x, y: ~(x & y),
    "$_NOR_": lambda x, y: ~(x | y),
    "$_XNOR_": lambda x, y: ~(x ^ y),
    "$_ANDNOT_": lambda x, y: x & ~y,
    "$_ORNOT_": lambda x, y: x | ~y,
    "$_MUX_": lambda x, y, s: np.where(s, y, x),
}

CONFIGS = [
    ("Exact Wallace tree (baseline)", 0x0000),
    ("Approx. low 4 columns", 0x000F),
    ("Approx. low 6 columns", 0x003F),
    ("Approx. low 8 columns (hybrid)", 0x00FF),
    ("Approx. low 10 columns", 0x03FF),
    ("Approx. low 12 columns", 0x0FFF),
    ("Fully approximate (original)", 0xFFFF),
]

RTL = ["rtl/haa.v", "rtl/faa.v", "rtl/mul_app.v"]


def synthesise(yosys, mask, out_json):
    script = (
        f"read_verilog {' '.join(os.path.join(ROOT, f) for f in RTL)}; "
        f"chparam -set APPROX_MASK {mask} mul_app; "
        f"synth -top mul_app -flatten -noabc; opt_clean; "
        f"write_json {out_json}"
    )
    subprocess.run([yosys, "-q", "-p", script], check=True)
    with open(out_json) as f:
        return json.load(f)["modules"]["mul_app"]


def evaluate(module, a, b):
    """Simulate the gate netlist. Returns output word, per-net values,
    per-net arrival time (weighted) and per-net depth (gate count)."""
    val, arr, dep = {}, {}, {}
    ports = module["ports"]
    for name, word in (("a", a), ("b", b)):
        for i, bit in enumerate(ports[name]["bits"]):
            val[bit] = ((word >> i) & 1).astype(bool)
            arr[bit] = 0.0
            dep[bit] = 0
    const = {"0": np.zeros(a.shape, bool), "1": np.ones(a.shape, bool)}

    def get(bit):
        return const[bit] if isinstance(bit, str) else val[bit]

    def ready(bit):
        return isinstance(bit, str) or bit in val

    pending = list(module["cells"].values())
    while pending:
        nxt = []
        for cell in pending:
            t, c = cell["type"], cell["connections"]
            ins = [c[p][0] for p in ("A", "B", "S") if p in c]
            if not all(ready(x) for x in ins):
                nxt.append(cell)
                continue
            if t not in GATE_FUNC:
                raise SystemExit(f"unexpected cell type {t}; extend GATE_FUNC")
            yb = c["Y"][0]
            val[yb] = GATE_FUNC[t](*(get(p) for p in ins))
            arr[yb] = max(arr.get(p, 0.0) for p in ins) + GATE_DELAY.get(t, 1.0)
            dep[yb] = max(dep.get(p, 0) for p in ins) + 1
        if len(nxt) == len(pending):
            raise SystemExit("combinational loop or undriven net in netlist")
        pending = nxt

    zbits = ports["z"]["bits"]
    z = sum(get(bit).astype(np.int64) << i for i, bit in enumerate(zbits))
    delay = max(arr.get(bit, 0.0) for bit in zbits if not isinstance(bit, str))
    depth = max(dep.get(bit, 0) for bit in zbits if not isinstance(bit, str))
    return z, val, delay, depth


def analyse(module):
    a, b = all_inputs(8)
    order = np.random.default_rng(2024).permutation(a.size)
    a, b = a[order], b[order]
    z, val, delay, depth = evaluate(module, a, b)

    counts = {t: 0 for t in GATE_DELAY}
    power = 0.0
    for cell in module["cells"].values():
        counts[cell["type"]] = counts.get(cell["type"], 0) + 1
        y = val[cell["connections"]["Y"][0]]
        activity = np.count_nonzero(y[1:] != y[:-1]) / (y.size - 1)
        power += activity * GATE_POWER.get(cell["type"], 1.0)
    return a, b, z, counts, delay, depth, power


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--yosys", default=os.environ.get("YOSYS", "yosys"))
    ap.add_argument("--keep", metavar="DIR", help="keep the Yosys JSON netlists here")
    args = ap.parse_args()

    outdir = args.keep or tempfile.mkdtemp(prefix="mul_app_synth_")
    os.makedirs(outdir, exist_ok=True)

    rows, ok = [], True
    for label, mask in CONFIGS:
        module = synthesise(args.yosys, mask, os.path.join(outdir, f"mul_app_{mask:04x}.json"))
        a, b, z, counts, delay, depth, power = analyse(module)
        ref = mul_app_8x8(a, b, mask)
        mism = int(np.count_nonzero(z != ref))
        ok &= mism == 0
        m = error_metrics(a, b, z, 8)
        rows.append((label, mask, counts, delay, depth, power, m, mism))

    base = rows[0]
    print("| Design | APPROX_MASK | XOR | OR | AND | Gates | Depth | Est. delay | "
          "Est. dyn. power | MRED (%) | NMED | Netlist = model |")
    print("|:--|:-:|--:|--:|--:|--:|--:|--:|--:|--:|--:|:-:|")
    for label, mask, counts, delay, depth, power, m, mism in rows:
        total = sum(counts.values())
        print(f"| {label} | 0x{mask:04X} | {counts['$_XOR_']} | {counts['$_OR_']} | "
              f"{counts['$_AND_']} | {total} | {depth} | {delay / base[3]:.3f} | "
              f"{power / base[5]:.3f} | {m['MRED']:.3f} | {m['NMED']:.5f} | "
              f"{'yes' if mism == 0 else f'NO ({mism})'} |")
    print()
    print("Est. delay = gate-weighted longest path; Est. dyn. power = toggle-weighted "
          "gate power; both normalised to the exact tree.")
    others = sorted({t for r in rows for t in r[2] if t not in GATE_DELAY and r[2][t]})
    if others:
        print(f"Note: netlists also contain {', '.join(others)} (counted in Gates, "
              "weighted 1.0); numbers will differ slightly from the README.")
    if not ok:
        print("SYNTH CHECK FAILED: synthesised netlist differs from the Python model")
        return 1
    print("SYNTH CHECK PASSED: every synthesised netlist matches the Python model "
          "on all 65,536 inputs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
