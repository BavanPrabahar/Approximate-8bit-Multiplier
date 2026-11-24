// Behavioural exact 8-bit multiplier: the golden reference (z = a * b) that
// the testbenches compare against.
//
// Do NOT use this module for delay/area comparisons: synthesis tools map
// "a * b" to their own optimised multiplier or to hard DSP blocks. For a fair
// comparison use mul_exact_wallace.v, which is the same Wallace tree as
// mul_app with exact adders. (The ha_exact / fa_exact cells that used to live
// here are replaced by haa / faa with APPROX = 0.)

module mul_exact_8x8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [15:0] z
);
    assign z = a * b;
endmodule
