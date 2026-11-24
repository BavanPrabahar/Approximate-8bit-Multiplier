// Approximate Full Adder (FAA)
// Uses approximate logic:
//   Sum   = (a ^ b) | cin   (Replaces second XOR with OR gate)
//   Carry = (a & b) | (b & cin) | (cin & a) (Exact majority logic)
//
// The wrong cases are a != b with cin = 1 (Sum = 1 instead of 0): 2 of the 8
// input combinations.
//
// Parameter APPROX (default 1) selects the approximate cell. APPROX = 0 gives
// an exact full adder (Sum = a ^ b ^ cin). APPROX is a constant, so synthesis
// keeps only the selected gate; no multiplexer is built.

module faa #(
    parameter APPROX = 1
) (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire carry
);

    assign sum   = APPROX ? ((a ^ b) | cin) : (a ^ b ^ cin);
    assign carry = (a & b) | (b & cin) | (cin & a);

endmodule
