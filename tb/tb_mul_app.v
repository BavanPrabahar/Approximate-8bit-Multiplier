`timescale 1ns / 1ps

// Exhaustive, self-checking testbench for the 8x8 approximate multiplier.
//
// For all 65,536 (a, b) pairs it checks:
//   1. mul_exact_wallace (same tree, exact adders) == a*b
//      -> proves the Wallace tree wiring is correct
//   2. mul_app #(APPROX_MASK = `MASK) == golden vector from the Python model
//      -> proves RTL and sim/verify_multiplier.py agree bit for bit
//         (only when compiled with -DGOLDEN_FILE="file.hex")
// and reports the error metrics of mul_app against a*b.
//
// Compile-time options (iverilog -D...):
//   MASK=16'h00FF          APPROX_MASK of the device under test (default FFFF)
//   GOLDEN_FILE="f.hex"    vectors from: sim/verify_multiplier.py --golden f.hex
//   DUMP                   write tb_mul_app.vcd for GTKWave
// Prints "TEST PASSED" or "TEST FAILED" as the final verdict.

`ifndef MASK
`define MASK 16'hFFFF
`endif

module tb_mul_app;

    reg  [7:0]  a;
    reg  [7:0]  b;
    wire [15:0] z_approx;      // device under test
    wire [15:0] z_tree_exact;  // same tree, exact adders
    wire [15:0] z_exact;       // behavioural a*b

    // Instantiate Approximate Multiplier
    mul_app #(.APPROX_MASK(`MASK)) uut_approx (
        .a(a),
        .b(b),
        .z(z_approx)
    );

    // Same Wallace tree built from exact adders
    mul_exact_wallace uut_tree_exact (
        .a(a),
        .b(b),
        .z(z_tree_exact)
    );

    // Instantiate Exact Multiplier (golden reference)
    mul_exact_8x8 ref_exact (
        .a(a),
        .b(b),
        .z(z_exact)
    );

`ifdef GOLDEN_FILE
    reg [15:0] golden [0:65535];
`endif

    integer i;
    integer ed, abs_ed, wce;
    integer n_err, n_wiring, n_golden;
    real    sum_abs, sum_rel, sum_signed, n_nonzero;

    // Signed error approx - exact. The 17-bit operands keep the subtraction
    // signed; the original testbench subtracted two unsigned 16-bit values,
    // so negative errors wrapped around (e.g. -640 printed as 64896).
    function integer err_dist(input [15:0] approx, input [15:0] exact);
        err_dist = $signed({1'b0, approx}) - $signed({1'b0, exact});
    endfunction

    task show(input [7:0] x, input [7:0] y);
        begin
            a = x; b = y; #1;
            ed = err_dist(z_approx, z_exact);
            $display(" %3d | %3d | %11d | %13d | %+6d | %+7.2f %%",
                     a, b, z_exact, z_approx, ed,
                     (z_exact == 0) ? 0.0 : 100.0 * ed / z_exact);
        end
    endtask

    initial begin
`ifdef DUMP
        $dumpfile("tb_mul_app.vcd");
        $dumpvars(0, tb_mul_app);
`endif
`ifdef GOLDEN_FILE
        $readmemh(`GOLDEN_FILE, golden);
`endif
        n_err = 0; n_wiring = 0; n_golden = 0; wce = 0;
        sum_abs = 0.0; sum_rel = 0.0; sum_signed = 0.0; n_nonzero = 0.0;

        for (i = 0; i < 65536; i = i + 1) begin
            {a, b} = i[15:0];          // vector index = a*256 + b
            #1;
            if (z_tree_exact !== z_exact) begin
                if (n_wiring < 5)
                    $display("WIRING ERROR: %0d*%0d exact tree gives %0d, expected %0d",
                             a, b, z_tree_exact, z_exact);
                n_wiring = n_wiring + 1;
            end
`ifdef GOLDEN_FILE
            if (z_approx !== golden[i]) begin
                if (n_golden < 5)
                    $display("MODEL MISMATCH: %0d*%0d RTL gives %0d, Python model %0d",
                             a, b, z_approx, golden[i]);
                n_golden = n_golden + 1;
            end
`endif
            ed     = err_dist(z_approx, z_exact);
            abs_ed = (ed < 0) ? -ed : ed;
            if (ed != 0)     n_err = n_err + 1;
            if (abs_ed > wce) wce = abs_ed;
            sum_abs    = sum_abs + abs_ed;
            sum_signed = sum_signed + ed;
            if (z_exact != 0) begin
                sum_rel   = sum_rel + (1.0 * abs_ed) / z_exact;
                n_nonzero = n_nonzero + 1.0;
            end
        end

        $display("==============================================================");
        $display("  TESTBENCH: mul_app (APPROX_MASK = 16'h%h) vs exact, exhaustive", `MASK);
        $display("==============================================================");
        $display("Vectors checked                   : %0d", i);
        $display("Error rate (ER)                   : %0.2f %%", 100.0 * n_err / 65536.0);
        $display("Mean error distance (MED)         : %0.2f", sum_abs / 65536.0);
        $display("Normalised MED (NMED)             : %0.5f", sum_abs / 65536.0 / 65025.0);
        $display("Mean relative error dist. (MRED)  : %0.3f %%", 100.0 * sum_rel / n_nonzero);
        $display("Worst-case error (WCE)            : %0d", wce);
        $display("Mean signed error (bias)          : %+0.2f", sum_signed / 65536.0);
        $display("--------------------------------------------------------------");
        $display("   A |   B | Exact (A*B) | Approx Output |  Error | Rel. err");
        $display("--------------------------------------------------------------");
        show(8'd132, 8'd231);
        show(8'd255, 8'd255);
        show(8'd128, 8'd128);
        show(8'd16,  8'd8);
        show(8'd64,  8'd32);
        $display("--------------------------------------------------------------");
        $display("Exact-tree wiring check           : %0d mismatches", n_wiring);
`ifdef GOLDEN_FILE
        $display("RTL vs Python golden model        : %0d mismatches", n_golden);
`else
        $display("RTL vs Python golden model        : skipped (no GOLDEN_FILE)");
`endif
        $display("==============================================================");
        if (n_wiring == 0 && n_golden == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");
        $finish;
    end

endmodule
