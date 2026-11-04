// Approximate Full Adder (FAA)
// Uses approximate logic:
//   Sum   = (a ^ b) | cin   (Replaces second XOR with OR gate)
//   Carry = (a & b) | (b & cin) | (cin & a) (Exact majority logic)

module faa (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire carry
);

    assign sum   = (a ^ b) | cin;
    assign carry = (a & b) | (b & cin) | (cin & a);

endmodule
