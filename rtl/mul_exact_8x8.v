// Exact Half Adder
module ha_exact (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire carry
);
    assign sum   = a ^ b;
    assign carry = a & b;
endmodule

// Exact Full Adder
module fa_exact (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire carry
);
    assign sum   = a ^ b ^ cin;
    assign carry = (a & b) | (b & cin) | (cin & a);
endmodule

// Exact 8-bit Multiplier for comparison
module mul_exact_8x8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [15:0] z
);
    assign z = a * b;
endmodule
