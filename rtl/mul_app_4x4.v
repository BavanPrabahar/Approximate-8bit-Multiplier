// Design of Approximate 4x4 Multiplier
// Based on partial products and 4:2 compressor reduction
// Inputs: a[3:0], b[3:0]
// Output: p[7:0]
//
// APPROX_MASK[i] = 1 makes the adders in column i approximate, 0 makes them
// exact (8'hFF = fully approximate, 8'h00 = exact multiplier).
//
// Columns 3-5 use the standard 4:2 compressor chain: cout of column i feeds
// cin of column i+1, and each compressor's carry goes to the final adder one
// column up. An earlier version left comp3's carry output unconnected, which
// lost 2^4 = 16 whenever it was 1 (e.g. 3*12 gave 20 even with exact adders).

module mul_app_4x4 #(
    parameter [7:0] APPROX_MASK = 8'hFF
) (
    input  wire [3:0] a,
    input  wire [3:0] b,
    output wire [7:0] p
);

    // Partial products
    wire p00 = a[0] & b[0];
    wire p10 = a[1] & b[0];
    wire p01 = a[0] & b[1];
    wire p20 = a[2] & b[0];
    wire p11 = a[1] & b[1];
    wire p02 = a[0] & b[2];
    wire p30 = a[3] & b[0];
    wire p21 = a[2] & b[1];
    wire p12 = a[1] & b[2];
    wire p03 = a[0] & b[3];
    wire p31 = a[3] & b[1];
    wire p22 = a[2] & b[2];
    wire p13 = a[1] & b[3];
    wire p32 = a[3] & b[2];
    wire p23 = a[2] & b[3];
    wire p33 = a[3] & b[3];

    // Stage 1 reduction
    wire s1, c1;
    haa #(APPROX_MASK[1]) ha_col1 (p10, p01, s1, c1);

    wire s2, c2;
    faa #(APPROX_MASK[2]) fa_col2 (p20, p11, p02, s2, c2);

    // Column 3: four partial products -> 4:2 compressor
    wire s3, carry3, cout3;
    compressor_4_2_approx #(APPROX_MASK[3]) comp3 (
        .x1(p30),
        .x2(p21),
        .x3(p12),
        .x4(p03),
        .cin(1'b0),
        .sum(s3),
        .carry(carry3),
        .cout(cout3)
    );

    // Column 4: three partial products + cout3 -> 4:2 compressor
    wire s4, carry4, cout4;
    compressor_4_2_approx #(APPROX_MASK[4]) comp4 (
        .x1(p31),
        .x2(p22),
        .x3(p13),
        .x4(1'b0),
        .cin(cout3),
        .sum(s4),
        .carry(carry4),
        .cout(cout4)
    );

    // Column 5: two partial products + cout4 -> full adder
    wire s5, c6;
    faa #(APPROX_MASK[5]) fa_col5 (p32, p23, cout4, s5, c6);

    // Stage 2 final addition (ripple carry)
    assign p[0] = p00;
    assign p[1] = s1;

    wire cy1;
    haa #(APPROX_MASK[2]) ha_add2 (c1, s2, p[2], cy1);

    wire cy2;
    faa #(APPROX_MASK[3]) fa_add3 (c2, s3, cy1, p[3], cy2);

    wire cy3;
    faa #(APPROX_MASK[4]) fa_add4 (carry3, s4, cy2, p[4], cy3);

    wire cy4;
    faa #(APPROX_MASK[5]) fa_add5 (carry4, s5, cy3, p[5], cy4);

    faa #(APPROX_MASK[6]) fa_add6 (c6, p33, cy4, p[6], p[7]);

endmodule
