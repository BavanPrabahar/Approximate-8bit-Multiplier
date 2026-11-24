// Exact 8-bit Wallace Tree Multiplier: the fair baseline for mul_app.
//
// The same netlist (same partial products, same five reduction stages, same
// ripple-carry final adder) built entirely from exact half/full adders. Any
// difference in delay, area or power against mul_app therefore comes only
// from the OR-for-XOR approximation, not from a different architecture.

module mul_exact_wallace (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [15:0] z
);

    mul_app #(.APPROX_MASK(16'h0000)) u_tree (
        .a(a),
        .b(b),
        .z(z)
    );

endmodule
