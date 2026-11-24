`timescale 1ns / 1ps

// Exhaustive, self-checking testbench for the 4x4 approximate multiplier.
//
// For all 256 (a, b) pairs it checks:
//   1. mul_app_4x4 #(APPROX_MASK = 8'h00) == a*b      (wiring is correct)
//   2. mul_app_4x4 #(APPROX_MASK = `MASK4) == golden vector from the Python
//      model (only when compiled with -DGOLDEN_FILE="file.hex")
// and reports the error metrics of the approximate multiplier.
//
// Compile-time options (iverilog -D...):
//   MASK4=8'h0F            APPROX_MASK of the device under test (default FF)
//   GOLDEN_FILE="f.hex"    vectors from:
//                          sim/verify_multiplier.py --width 4 --golden f.hex
// Prints "TEST PASSED" or "TEST FAILED" on the last line.

`ifndef MASK4
`define MASK4 8'hFF
`endif

module tb_mul_app_4x4;

    reg  [3:0] a;
    reg  [3:0] b;
    wire [7:0] p_approx;
    wire [7:0] p_tree_exact;
    wire [7:0] p_exact = a * b;

    mul_app_4x4 #(.APPROX_MASK(`MASK4)) uut_approx (
        .a(a),
        .b(b),
        .p(p_approx)
    );

    mul_app_4x4 #(.APPROX_MASK(8'h00)) uut_tree_exact (
        .a(a),
        .b(b),
        .p(p_tree_exact)
    );

`ifdef GOLDEN_FILE
    reg [7:0] golden [0:255];
`endif

    integer i;
    integer ed, abs_ed, wce;
    integer n_err, n_wiring, n_golden;
    real    sum_abs, sum_rel, sum_signed, n_nonzero;

    function integer err_dist(input [7:0] approx, input [7:0] exact);
        err_dist = $signed({1'b0, approx}) - $signed({1'b0, exact});
    endfunction

    task show(input [3:0] x, input [3:0] y);
        begin
            a = x; b = y; #1;
            ed = err_dist(p_approx, p_exact);
            $display("  %2d | %2d | %11d | %13d | %+6d | %+7.2f %%",
                     a, b, p_exact, p_approx, ed,
                     (p_exact == 0) ? 0.0 : 100.0 * ed / p_exact);
        end
    endtask

    initial begin
`ifdef GOLDEN_FILE
        $readmemh(`GOLDEN_FILE, golden);
`endif
        n_err = 0; n_wiring = 0; n_golden = 0; wce = 0;
        sum_abs = 0.0; sum_rel = 0.0; sum_signed = 0.0; n_nonzero = 0.0;

        for (i = 0; i < 256; i = i + 1) begin
            {a, b} = i[7:0];           // vector index = a*16 + b
            #1;
            if (p_tree_exact !== p_exact) begin
                if (n_wiring < 5)
                    $display("WIRING ERROR: %0d*%0d exact tree gives %0d, expected %0d",
                             a, b, p_tree_exact, p_exact);
                n_wiring = n_wiring + 1;
            end
`ifdef GOLDEN_FILE
            if (p_approx !== golden[i]) begin
                if (n_golden < 5)
                    $display("MODEL MISMATCH: %0d*%0d RTL gives %0d, Python model %0d",
                             a, b, p_approx, golden[i]);
                n_golden = n_golden + 1;
            end
`endif
            ed     = err_dist(p_approx, p_exact);
            abs_ed = (ed < 0) ? -ed : ed;
            if (ed != 0)     n_err = n_err + 1;
            if (abs_ed > wce) wce = abs_ed;
            sum_abs    = sum_abs + abs_ed;
            sum_signed = sum_signed + ed;
            if (p_exact != 0) begin
                sum_rel   = sum_rel + (1.0 * abs_ed) / p_exact;
                n_nonzero = n_nonzero + 1.0;
            end
        end

        $display("==============================================================");
        $display("  TESTBENCH: mul_app_4x4 (APPROX_MASK = 8'h%h) vs exact, exhaustive", `MASK4);
        $display("==============================================================");
        $display("Vectors checked                   : %0d", i);
        $display("Error rate (ER)                   : %0.2f %%", 100.0 * n_err / 256.0);
        $display("Mean error distance (MED)         : %0.2f", sum_abs / 256.0);
        $display("Normalised MED (NMED)             : %0.5f", sum_abs / 256.0 / 225.0);
        $display("Mean relative error dist. (MRED)  : %0.3f %%", 100.0 * sum_rel / n_nonzero);
        $display("Worst-case error (WCE)            : %0d", wce);
        $display("Mean signed error (bias)          : %+0.2f", sum_signed / 256.0);
        $display("--------------------------------------------------------------");
        $display("   A |  B | Exact (A*B) | Approx Output |  Error | Rel. err");
        $display("--------------------------------------------------------------");
        show(4'd8,  4'd4);
        show(4'd10, 4'd4);
        show(4'd10, 4'd10);
        show(4'd15, 4'd15);
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
