// Approximate Half Adder (HAA)
// Replaces XOR gate with OR gate for Sum calculation:
// - Standard HA: Sum = a ^ b (XOR: 8 transistors in CMOS, higher delay & power)
// - Approx HA:   Sum = a | b (OR: fewer transistors, lower power & delay)
// Carry remains exact: Carry = a & b
//
// The only wrong case is a = b = 1 (Sum = 1 instead of 0): 1 of the 4 input
// combinations.
//
// Parameter APPROX (default 1) selects the approximate cell. APPROX = 0 gives
// an exact half adder, which lets a multiplier choose per column whether to
// approximate (see APPROX_MASK in mul_app.v). APPROX is a constant, so
// synthesis keeps only the selected gate; no multiplexer is built.

module haa #(
    parameter APPROX = 1
) (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire carry
);

    assign sum   = APPROX ? (a | b) : (a ^ b);
    assign carry = a & b;

endmodule
