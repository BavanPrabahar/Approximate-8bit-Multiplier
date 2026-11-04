// Approximate Half Adder (HAA)
// Replaces XOR gate with OR gate for Sum calculation:
// - Standard HA: Sum = a ^ b (XOR: 8 transistors in CMOS, higher delay & power)
// - Approx HA:   Sum = a | b (OR: fewer transistors, lower power & delay)
// Carry remains exact: Carry = a & b

module haa (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire carry
);

    assign sum   = a | b;
    assign carry = a & b;

endmodule
