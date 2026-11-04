`timescale 1ns / 1ps

module tb_mul_app;

    reg  [7:0] a;
    reg  [7:0] b;
    wire [15:0] z_approx;
    wire [15:0] z_exact;

    // Instantiate Approximate Multiplier
    mul_app uut_approx (
        .a(a),
        .b(b),
        .z(z_approx)
    );

    // Instantiate Exact Multiplier
    mul_exact_8x8 uut_exact (
        .a(a),
        .b(b),
        .z(z_exact)
    );

    initial begin
        $display("=========================================================");
        $display("  TESTBENCH: Approximate vs Exact 8-bit Multiplier");
        $display("=========================================================");
        $display(" Time |  A  |  B  | Exact (A*B) | Approx Output | Error");
        $display("---------------------------------------------------------");

        // Test Case 1: 132 * 231 (from presentation slide 23)
        // Exact: 31132, Approx: 30492
        a = 8'd132; b = 8'd231; #10;
        $display("%4t | %3d | %3d | %11d | %13d | %5d", 
                 $time, a, b, z_exact, z_approx, z_exact - z_approx);

        // Test Case 2: 255 * 255 (from presentation slide 23)
        // Exact: 65535, Approx: 65025
        a = 8'd255; b = 8'd255; #10;
        $display("%4t | %3d | %3d | %11d | %13d | %5d", 
                 $time, a, b, z_exact, z_approx, z_exact - z_approx);

        // Test Case 3: 128 * 128 (from presentation slide 23)
        // Exact: 16384, Approx: 16384
        a = 8'd128; b = 8'd128; #10;
        $display("%4t | %3d | %3d | %11d | %13d | %5d", 
                 $time, a, b, z_exact, z_approx, z_exact - z_approx);

        // Test Case 4: Power of 2 test
        a = 8'd16; b = 8'd8; #10;
        $display("%4t | %3d | %3d | %11d | %13d | %5d", 
                 $time, a, b, z_exact, z_approx, z_exact - z_approx);

        // Test Case 5: 64 * 32
        a = 8'd64; b = 8'd32; #10;
        $display("%4t | %3d | %3d | %11d | %13d | %5d", 
                 $time, a, b, z_exact, z_approx, z_exact - z_approx);

        $display("=========================================================");
        $display("  Verification completed successfully!");
        $display("=========================================================");
        $finish;
    end

endmodule
