// Design of Approximate 4x4 Multiplier
// Based on partial products and 4:2 compressor reduction
// Inputs: a[3:0], b[3:0]
// Output: p[7:0]

module mul_app_4x4 (
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
    haa ha_col1 (p10, p01, s1, c1);

    wire s2, c2;
    faa fa_col2 (p20, p11, p02, s2, c2);

    wire s3, c4;
    // 4 inputs at column 3 compressed using 4:2 compressor
    wire comp_cout, comp_carry;
    compressor_4_2_approx comp3 (
        .x1(p30),
        .x2(p21),
        .x3(p12),
        .x4(p03),
        .cin(1'b0),
        .sum(s3),
        .carry(comp_carry),
        .cout(comp_cout)
    );

    wire s4, c5;
    faa fa_col4 (p31, p22, p13, s4, c5);

    wire s5, c6;
    haa ha_col5 (p32, p23, s5, c6);

    // Stage 2 final addition
    assign p[0] = p00;
    assign p[1] = s1;

    wire cy1;
    haa ha_add2 (c1, s2, p[2], cy1);

    wire cy2;
    faa fa_add3 (c2, s3, cy1, p[3], cy2);

    wire cy3;
    faa fa_add4 (comp_cout, s4, cy2, p[4], cy3);

    wire cy4;
    faa fa_add5 (c5, s5, cy3, p[5], cy4);

    faa fa_add6 (c6, p33, cy4, p[6], p[7]);

endmodule
