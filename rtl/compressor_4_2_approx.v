// Approximate 4:2 Compressor
// Inputs : x1, x2, x3, x4, cin       (all of weight 2^i)
// Outputs: sum (2^i), carry (2^(i+1)), cout (2^(i+1))
// Built from two cascaded full adders. cout depends only on x1..x3, so when
// cout of column i drives cin of column i+1 the chain does not ripple.
//
// Parameter APPROX is passed to both full adders (1 = approximate faa,
// 0 = exact full adder).

module compressor_4_2_approx #(
    parameter APPROX = 1
) (
    input  wire x1,
    input  wire x2,
    input  wire x3,
    input  wire x4,
    input  wire cin,
    output wire sum,
    output wire carry,
    output wire cout
);

    wire s_int;

    // Stage 1: Compress x1, x2, x3
    faa #(APPROX) fa_inst1 (
        .a(x1),
        .b(x2),
        .cin(x3),
        .sum(s_int),
        .carry(cout)
    );

    // Stage 2: Compress intermediate sum with x4 and cin
    faa #(APPROX) fa_inst2 (
        .a(s_int),
        .b(x4),
        .cin(cin),
        .sum(sum),
        .carry(carry)
    );

endmodule
