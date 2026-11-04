// Approximate 4:2 Compressor
// Inputs: x1, x2, x3, x4, cin
// Outputs: sum, carry, cout
// Built using approximate full adder and logic reduction for low power & high speed

module compressor_4_2_approx (
    input  wire x1,
    input  wire x2,
    input  wire x3,
    input  wire x4,
    input  wire cin,
    output wire sum,
    output wire carry,
    output wire cout
);

    wire s_int, c_int;

    // Stage 1: Compress x1, x2, x3
    faa fa_inst1 (
        .a(x1),
        .b(x2),
        .cin(x3),
        .sum(s_int),
        .carry(cout)
    );

    // Stage 2: Compress intermediate sum with x4 and cin
    faa fa_inst2 (
        .a(s_int),
        .b(x4),
        .cin(cin),
        .sum(sum),
        .carry(carry)
    );

endmodule
