// Design of Approximate 8-bit Wallace Tree Multiplier (mul_app)
// Directly implements the structural architecture verified in ModelSim & Quartus Prime
// Inputs: a[7:0], b[7:0]
// Output: z[15:0]
// Uses approximate full adders (faa) and approximate half adders (haa)
//
// APPROX_MASK selects, per output column, whether the adders in that column
// are approximate (bit = 1) or exact (bit = 0). Each instance below is tagged
// with its column: "faa #(APPROX_MASK[4]) fa3(...)" sits in column 4 (weight 2^4).
//   16'hFFFF (default) : every adder approximate (the original design)
//   16'h00FF           : approximate in the 8 low columns only (hybrid)
//   16'h0000           : every adder exact; same tree, used as the fair
//                        exact baseline (see mul_exact_wallace.v)

module mul_app #(
    parameter [15:0] APPROX_MASK = 16'hFFFF
) (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [15:0] z
);

    wire c1,c2,c3,c4,c5,c6,c7,c8,s1,s2,s3,s4,s5,s6,s7,s8,m1,m2,m3,m4,m5,m6,m7,m8;
    wire n1,n2,n3,n4,n5,n6,n7,n8,x1,x2,x3,x4,x5,x6,x7,x8,y1,y2,y3,y4,y5,y6,y7,y8;
    wire j1,j2,j3,j4,j5,j6,j7,j8,k1,k2,k3,k4,k5,k6,k7,k8,l1,l2,l3,l4,l5,l6,l7,l8,l9,l10;
    wire r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,q1,q2,q3,q4,q5,q6,q7,q8,q9,q10,q11;
    wire v1,v2,v3,v4,v5,v6,v7,v8,v9,v10;

    // ==========================================
    // STAGE 1: Partial Product Reduction
    // ==========================================
    assign z[0] = a[0] & b[0];
    haa #(APPROX_MASK[1]) ha1(a[1]&b[0], a[0]&b[1], s1, c1);
    faa #(APPROX_MASK[2]) fa1(a[2]&b[0], a[1]&b[1], a[0]&b[2], s2, c2);
    faa #(APPROX_MASK[3]) fa2(a[3]&b[0], a[2]&b[1], a[1]&b[2], s3, c3);
    faa #(APPROX_MASK[4]) fa3(a[4]&b[0], a[3]&b[1], a[2]&b[2], s4, c4);
    faa #(APPROX_MASK[4]) fa4(a[1]&b[3], a[0]&b[4], 1'b0, m1, n1);
    faa #(APPROX_MASK[5]) fa5(a[5]&b[0], a[4]&b[1], a[3]&b[2], s5, c5);
    faa #(APPROX_MASK[5]) fa6(a[2]&b[3], a[1]&b[4], a[0]&b[5], m2, n2);
    faa #(APPROX_MASK[6]) fa7(a[6]&b[0], a[5]&b[1], a[4]&b[2], s6, c6);
    faa #(APPROX_MASK[7]) fa9(a[7]&b[0], a[6]&b[1], a[5]&b[2], s7, c7);
    faa #(APPROX_MASK[8]) fa11(1'b0, a[7]&b[1], a[6]&b[2], s8, c8);
    faa #(APPROX_MASK[6]) fa8(a[3]&b[3], a[2]&b[4], a[1]&b[5], m3, n3);
    faa #(APPROX_MASK[7]) fa10(a[4]&b[3], a[3]&b[4], a[2]&b[5], m4, n4);
    faa #(APPROX_MASK[8]) fa12(a[5]&b[3], a[4]&b[4], a[3]&b[5], m5, n5);
    faa #(APPROX_MASK[9]) fa13(a[6]&b[3], a[5]&b[4], a[4]&b[5], m6, n6);
    faa #(APPROX_MASK[10]) fa14(a[7]&b[3], a[6]&b[4], a[5]&b[5], m7, n7);
    faa #(APPROX_MASK[11]) fa15(1'b0, a[7]&b[4], a[6]&b[5], m8, n8);

    // ==========================================
    // STAGE 2
    // ==========================================
    assign z[1] = s1;
    haa #(APPROX_MASK[2]) ha2(c1, s2, x1, y1);
    faa #(APPROX_MASK[3]) fa17(c2, s3, a[0]&b[3], x2, y2);
    faa #(APPROX_MASK[4]) fa18(c3, s4, m1, x3, y3);
    faa #(APPROX_MASK[5]) fa19(c4, s5, m2, x4, y4);
    faa #(APPROX_MASK[6]) fa20(c5, s6, m3, x5, y5);
    faa #(APPROX_MASK[7]) fa21(c6, s7, m4, x6, y6);
    faa #(APPROX_MASK[8]) fa23(c7, s8, m5, x7, y7);
    faa #(APPROX_MASK[9]) fa25(c8, m6, a[7]&b[2], x8, y8);
    haa #(APPROX_MASK[6]) ha3(n2, a[0]&b[6], j1, k1);
    faa #(APPROX_MASK[7]) fa22(n3, a[1]&b[6], a[0]&b[7], j2, k2);
    faa #(APPROX_MASK[8]) fa24(n4, a[2]&b[6], a[1]&b[7], j3, k3);
    faa #(APPROX_MASK[9]) fa26(n5, a[3]&b[6], a[2]&b[7], j4, k4);
    faa #(APPROX_MASK[10]) fa27(n6, a[4]&b[6], a[3]&b[7], j5, k5);
    faa #(APPROX_MASK[11]) fa28(n7, a[5]&b[6], a[4]&b[7], j6, k6);
    faa #(APPROX_MASK[12]) fa29(n8, a[6]&b[6], a[5]&b[7], j7, k7);
    haa #(APPROX_MASK[13]) ha4(a[7]&b[6], a[6]&b[7], j8, k8);

    // ==========================================
    // STAGE 3
    // ==========================================
    assign z[2] = x1;
    haa #(APPROX_MASK[3]) ha5(y1, x2, l1, r1);
    haa #(APPROX_MASK[4]) ha6(y2, x3, l2, r2);
    faa #(APPROX_MASK[5]) fa30(y3, x4, n1, l3, r3);
    faa #(APPROX_MASK[6]) fa31(y4, x5, j1, l4, r4);
    faa #(APPROX_MASK[7]) fa32(y5, x6, j2, l5, r5);
    faa #(APPROX_MASK[8]) fa33(y6, x7, j3, l6, r6);
    faa #(APPROX_MASK[9]) fa34(y7, x8, j4, l7, r7);
    faa #(APPROX_MASK[10]) fa35(y8, m7, j5, l8, r8);
    haa #(APPROX_MASK[11]) ha7(m8, j6, l9, r9);
    haa #(APPROX_MASK[12]) ha8(a[7]&b[5], j7, l10, r10);

    // ==========================================
    // STAGE 4
    // ==========================================
    assign z[3] = l1;
    haa #(APPROX_MASK[4]) ha9(r1, l2, p1, q1);
    haa #(APPROX_MASK[5]) ha10(r2, l3, p2, q2);
    haa #(APPROX_MASK[6]) ha11(r3, l4, p3, q3);
    faa #(APPROX_MASK[7]) fa36(r4, l5, k1, p4, q4);
    faa #(APPROX_MASK[8]) fa37(r5, l6, k2, p5, q5);
    faa #(APPROX_MASK[9]) fa38(r6, l7, k3, p6, q6);
    faa #(APPROX_MASK[10]) fa39(r7, l8, k4, p7, q7);
    faa #(APPROX_MASK[11]) fa40(r8, l9, k5, p8, q8);
    faa #(APPROX_MASK[12]) fa41(r9, l10, k6, p9, q9);
    faa #(APPROX_MASK[13]) fa42(r10, j8, k7, p10, q10);
    haa #(APPROX_MASK[14]) ha12(a[7]&b[7], k8, p11, q11);

    // ==========================================
    // STAGE 5: Final Vector Addition
    // ==========================================
    assign z[4] = p1;
    haa #(APPROX_MASK[5]) ha13(q1, p2, z[5], v1);
    faa #(APPROX_MASK[6]) fa43(q2, p3, v1, z[6], v2);
    faa #(APPROX_MASK[7]) fa44(q3, p4, v2, z[7], v3);
    faa #(APPROX_MASK[8]) fa45(q4, p5, v3, z[8], v4);
    faa #(APPROX_MASK[9]) fa46(q5, p6, v4, z[9], v5);
    faa #(APPROX_MASK[10]) fa47(q6, p7, v5, z[10], v6);
    faa #(APPROX_MASK[11]) fa48(q7, p8, v6, z[11], v7);
    faa #(APPROX_MASK[12]) fa49(q8, p9, v7, z[12], v8);
    faa #(APPROX_MASK[13]) fa50(q9, p10, v8, z[13], v9);
    faa #(APPROX_MASK[14]) fa51(q10, p11, v9, z[14], v10);
    // Column 15 receives two bits: q11 (from ha12) and the final carry v10
    // (from fa51). Earlier versions used z[15] = q11 and dropped v10, which
    // lost 2^15 = 32768 whenever v10 = 1 (e.g. 129*255 gave 127 even with
    // exact adders). In an exact tree q11 and v10 are never both 1, since
    // the product fits in 16 bits, so OR is the exact sum here.
    assign z[15] = q11 | v10;

endmodule
