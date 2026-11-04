%% Image Blending / Multiplication using Approximate 8-Bit Multiplier
% Project: Design and Functional Verification of an Approximate 8-bit Multiplier
% Team: G.ReddySekhar Reddy, Balanand Aswind, G.Kranthi Kiran
% Supervisor: Dr. Elamaran.V, Assistant Professor, SEEE, SASTRA Deemed University

clear; clc; close all;

%% 1. Generate / Load Sample Images
% Creates two synthetic 8-bit grayscale images (256x256)
[X, Y] = meshgrid(linspace(0, 1, 256), linspace(0, 1, 256));
img1 = uint8(255 * (0.5 + 0.5 * sin(2 * pi * 3 * X)));
img2 = uint8(255 * Y);

%% 2. Exact Multiplication / Blending
% Normalization factor = 255 (Output scaled to 8-bit)
img_exact = uint8((double(img1) .* double(img2)) / 255);

%% 3. Approximate Multiplier Hardware Emulation
img_approx = zeros(size(img1), 'uint8');

disp('Executing Approximate Multiplier Image Blending...');
for r = 1:size(img1, 1)
    for c = 1:size(img1, 2)
        val1 = double(img1(r, c));
        val2 = double(img2(r, c));
        
        % Approximate 8-bit multiplication emulation
        prod_approx = emulate_approx_mul(val1, val2);
        
        % Scale back to 8-bit range
        img_approx(r, c) = uint8(min(255, floor(prod_approx / 255)));
    end
end

%% 4. Error Metrics Computation
mse_val = mean((double(img_exact(:)) - double(img_approx(:))).^2);
psnr_val = 10 * log10((255^2) / mse_val);

fprintf('=====================================================\n');
fprintf('  Image Processing Results with Approximate Multiplier\n');
fprintf('=====================================================\n');
fprintf('Mean Squared Error (MSE) : %.4f\n', mse_val);
fprintf('Peak Signal-to-Noise Ratio: %.2f dB\n', psnr_val);
fprintf('=====================================================\n');

%% 5. Visualization
figure('Name', 'Approximate Multiplier Image Multiplication', 'Position', [100, 100, 1000, 400]);

subplot(1, 3, 1);
imshow(img1);
title('Input Image 1');

subplot(1, 3, 2);
imshow(img_exact);
title('Exact Multiplication Output');

subplot(1, 3, 3);
imshow(img_approx);
title(sprintf('Approx Multiplier Output (PSNR: %.2f dB)', psnr_val));

%% Helper Function: Bit-Level Model of Approximate 8-bit Multiplier
function z = emulate_approx_mul(a, b)
    a_bits = bitget(uint8(a), 1:8);
    b_bits = bitget(uint8(b), 1:8);
    
    % HAA: sum = a | b, carry = a & b
    % FAA: sum = (a ^ b) | cin, carry = (a & b) | (b & cin) | (cin & a)
    
    % Stage 1
    z0 = bitand(a_bits(1), b_bits(1));
    [s1, c1] = haa(bitand(a_bits(2), b_bits(1)), bitand(a_bits(1), b_bits(2)));
    [s2, c2] = faa(bitand(a_bits(3), b_bits(1)), bitand(a_bits(2), b_bits(2)), bitand(a_bits(1), b_bits(3)));
    [s3, c3] = faa(bitand(a_bits(4), b_bits(1)), bitand(a_bits(3), b_bits(2)), bitand(a_bits(2), b_bits(3)));
    [s4, c4] = faa(bitand(a_bits(5), b_bits(1)), bitand(a_bits(4), b_bits(2)), bitand(a_bits(3), b_bits(3)));
    [m1, n1] = faa(bitand(a_bits(2), b_bits(4)), bitand(a_bits(1), b_bits(5)), 0);
    [s5, c5] = faa(bitand(a_bits(6), b_bits(1)), bitand(a_bits(5), b_bits(2)), bitand(a_bits(4), b_bits(3)));
    [m2, n2] = faa(bitand(a_bits(3), b_bits(4)), bitand(a_bits(2), b_bits(5)), bitand(a_bits(1), b_bits(6)));
    [s6, c6] = faa(bitand(a_bits(7), b_bits(1)), bitand(a_bits(6), b_bits(2)), bitand(a_bits(5), b_bits(3)));
    [s7, c7] = faa(bitand(a_bits(8), b_bits(1)), bitand(a_bits(7), b_bits(2)), bitand(a_bits(6), b_bits(3)));
    [s8, c8] = faa(0, bitand(a_bits(8), b_bits(2)), bitand(a_bits(7), b_bits(3)));
    [m3, n3] = faa(bitand(a_bits(4), b_bits(4)), bitand(a_bits(3), b_bits(5)), bitand(a_bits(2), b_bits(6)));
    [m4, n4] = faa(bitand(a_bits(5), b_bits(4)), bitand(a_bits(4), b_bits(5)), bitand(a_bits(3), b_bits(6)));
    [m5, n5] = faa(bitand(a_bits(6), b_bits(4)), bitand(a_bits(5), b_bits(5)), bitand(a_bits(4), b_bits(6)));
    [m6, n6] = faa(bitand(a_bits(7), b_bits(4)), bitand(a_bits(6), b_bits(5)), bitand(a_bits(5), b_bits(6)));
    [m7, n7] = faa(bitand(a_bits(8), b_bits(4)), bitand(a_bits(7), b_bits(5)), bitand(a_bits(6), b_bits(6)));
    [m8, n8] = faa(0, bitand(a_bits(8), b_bits(5)), bitand(a_bits(7), b_bits(6)));

    % Stage 2
    z1 = s1;
    [x1, y1] = haa(c1, s2);
    [x2, y2] = faa(c2, s3, bitand(a_bits(1), b_bits(4)));
    [x3, y3] = faa(c3, s4, m1);
    [x4, y4] = faa(c4, s5, m2);
    [x5, y5] = faa(c5, s6, m3);
    [x6, y6] = faa(c6, s7, m4);
    [x7, y7] = faa(c7, s8, m5);
    [x8, y8] = faa(c8, m6, bitand(a_bits(8), b_bits(3)));
    [j1, k1] = haa(n2, bitand(a_bits(1), b_bits(7)));
    [j2, k2] = faa(n3, bitand(a_bits(2), b_bits(7)), bitand(a_bits(1), b_bits(8)));
    [j3, k3] = faa(n4, bitand(a_bits(3), b_bits(7)), bitand(a_bits(2), b_bits(8)));
    [j4, k4] = faa(n5, bitand(a_bits(4), b_bits(7)), bitand(a_bits(3), b_bits(8)));
    [j5, k5] = faa(n6, bitand(a_bits(5), b_bits(7)), bitand(a_bits(4), b_bits(8)));
    [j6, k6] = faa(n7, bitand(a_bits(6), b_bits(7)), bitand(a_bits(5), b_bits(8)));
    [j7, k7] = faa(n8, bitand(a_bits(7), b_bits(7)), bitand(a_bits(6), b_bits(8)));
    [j8, k8] = haa(bitand(a_bits(8), b_bits(7)), bitand(a_bits(7), b_bits(8)));

    % Stage 3
    z2 = x1;
    [l1, r1] = haa(y1, x2);
    [l2, r2] = haa(y2, x3);
    [l3, r3] = faa(y3, x4, n1);
    [l4, r4] = faa(y4, x5, j1);
    [l5, r5] = faa(y5, x6, j2);
    [l6, r6] = faa(y6, x7, j3);
    [l7, r7] = faa(y7, x8, j4);
    [l8, r8] = faa(y8, m7, j5);
    [l9, r9] = haa(m8, j6);
    [l10, r10] = haa(bitand(a_bits(8), b_bits(6)), j7);

    % Stage 4
    z3 = l1;
    [p1, q1] = haa(r1, l2);
    [p2, q2] = haa(r2, l3);
    [p3, q3] = haa(r3, l4);
    [p4, q4] = faa(r4, l5, k1);
    [p5, q5] = faa(r5, l6, k2);
    [p6, q6] = faa(r6, l7, k3);
    [p7, q7] = faa(r7, l8, k4);
    [p8, q8] = faa(r8, l9, k5);
    [p9, q9] = faa(r9, l10, k6);
    [p10, q10] = faa(r10, j8, k7);
    [p11, q11] = haa(bitand(a_bits(8), b_bits(8)), k8);

    % Stage 5
    z4 = p1;
    [z5, v1] = haa(q1, p2);
    [z6, v2] = faa(q2, p3, v1);
    [z7, v3] = faa(q3, p4, v2);
    [z8, v4] = faa(q4, p5, v3);
    [z9, v5] = faa(q5, p6, v4);
    [z10, v6] = faa(q6, p7, v5);
    [z11, v7] = faa(q7, p8, v6);
    [z12, v8] = faa(q8, p9, v7);
    [z13, v9] = faa(q9, p10, v8);
    [z14, v10] = faa(q10, p11, v9);
    z15 = q11;

    bits = [z0, z1, z2, z3, z4, z5, z6, z7, z8, z9, z10, z11, z12, z13, z14, z15];
    z = sum(bits .* (2.^(0:15)));
end

function [s, c] = haa(a, b)
    s = bitor(a, b);
    c = bitand(a, b);
end

function [s, c] = faa(a, b, cin)
    s = bitor(bitxor(a, b), cin);
    c = bitor(bitor(bitand(a, b), bitand(b, cin)), bitand(cin, a));
end
