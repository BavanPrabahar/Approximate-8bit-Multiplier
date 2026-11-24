%% Image Blending / Multiplication using Approximate 8-Bit Multiplier
% Project: Design and Functional Verification of an Approximate 8-bit Multiplier
% Team: G.ReddySekhar Reddy, Balanand Aswind, G.Kranthi Kiran
% Supervisor: Dr. Elamaran.V, Assistant Professor, SEEE, SASTRA Deemed University
%
% Alpha-blends two 8-bit images, out = (alpha*I1 + (255-alpha)*I2) / 255,
% with every 8x8 product computed by a bit-accurate model of rtl/mul_app.v,
% and compares the result against the same blend done with exact products.
%
% The model is evaluated once for all 65,536 operand pairs to build a
% product look-up table (LUT), so blending any image is plain indexing.
%
% APPROX_MASK works as in the RTL: bit i = 1 makes column i approximate.
%   0xFFFF  fully approximate (original design)
%   0x00FF  approximate in the 8 low columns only (hybrid)
%
% If build/golden8_FFFF.hex exists (run "make sim" first), the LUT is also
% checked against the RTL golden vectors.

clear; clc; close all;

masks  = [hex2dec('00FF'), hex2dec('FFFF')];
labels = {'Hybrid (APPROX\_MASK = 0x00FF)', 'Fully approx. (0xFFFF)'};
here   = fileparts(mfilename('fullpath'));

%% 1. Load input images (toolbox sample images, synthetic fallback)
if exist('cameraman.tif', 'file') && exist('rice.png', 'file')
    img1 = imread('cameraman.tif');
    img2 = imread('rice.png');
    img2 = img2(1:size(img1, 1), 1:size(img1, 2));
else
    [X, Y] = meshgrid(linspace(0, 1, 256), linspace(0, 1, 256));
    img1 = uint8(255 * (0.5 + 0.5 * sin(2 * pi * 3 * X)));
    img2 = uint8(255 * Y);
end
% Horizontal alpha ramp: left = img2, right = img1
alpha = uint8(repmat(round(linspace(0, 255, size(img1, 2))), size(img1, 1), 1));

%% 2. Product look-up tables (index = a*256 + b + 1)
[A, B] = ndgrid(0:255, 0:255);
A = reshape(A', [], 1);   % a varies slowest: index = a*256 + b
B = reshape(B', [], 1);
lut_exact = A .* B;

golden = fullfile(here, '..', 'build', 'golden8_FFFF.hex');
if exist(golden, 'file')
    ref = hex2dec(strsplit(strtrim(fileread(golden))));
    nbad = nnz(mul_app_model(A, B, hex2dec('FFFF')) ~= ref);
    fprintf('MATLAB model vs RTL golden vectors: %d mismatches\n', nbad);
end
assert(isequal(mul_app_model(A, B, 0), lut_exact), ...
    'Exact-cell model must equal a*b');

%% 3. Blend with exact and approximate multipliers
blend = @(lut) uint8(min(255, floor( ...
    (lut(double(alpha) * 256 + double(img1) + 1) + ...
     lut(double(255 - alpha) * 256 + double(img2) + 1)) / 255)));

img_exact = blend(lut_exact);
fprintf('=====================================================\n');
fprintf('  Alpha blending with the approximate multiplier\n');
fprintf('=====================================================\n');
fprintf('%-34s %10s %8s\n', 'Configuration', 'PSNR (dB)', 'SSIM');
img_approx = cell(size(masks));
psnr_val   = zeros(size(masks));
for k = 1:numel(masks)
    img_approx{k} = blend(mul_app_model(A, B, masks(k)));
    mse_val = mean((double(img_exact(:)) - double(img_approx{k}(:))).^2);
    psnr_val(k) = 10 * log10(255^2 / mse_val);
    if exist('ssim', 'file')
        s = ssim(img_approx{k}, img_exact);
    else
        s = NaN;
    end
    fprintf('APPROX_MASK = 0x%04X %14s %10.2f %8.4f\n', masks(k), '', psnr_val(k), s);
end

fprintf('-----------------------------------------------------\n');
fprintf('PSNR vs number of approximate low columns K:\n');
for K = [4 6 7 8 9 10 12 16]
    out = blend(mul_app_model(A, B, 2^K - 1));
    mse_val = mean((double(img_exact(:)) - double(out(:))).^2);
    fprintf('  K = %2d  (0x%04X)  PSNR = %6.2f dB\n', K, 2^K - 1, 10 * log10(255^2 / mse_val));
end
fprintf('=====================================================\n');

%% 4. Visualization
fig = figure('Name', 'Approximate Multiplier Image Blending', 'Position', [100, 100, 1200, 330]);
tiles = tiledlayout(fig, 1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile; imshow(img1); title('Input 1');
nexttile; imshow(img_exact); title('Exact multiplier');
for k = 1:numel(masks)
    nexttile; imshow(img_approx{k});
    title(sprintf('%s\nPSNR %.2f dB', labels{k}, psnr_val(k)));
end
docs = fullfile(here, '..', 'docs');
if exist(docs, 'dir')
    exportgraphics(tiles, fullfile(docs, 'image_blending.png'), 'Resolution', 110);
end

%% Bit-accurate model of rtl/mul_app.v (vectorised; mirrors the netlist)
function z = mul_app_model(a, b, mask)
    pp = @(i, j) bitand(bitget(a, i + 1), bitget(b, j + 1));
    zero = zeros(size(a));
    m = mask;

    % Stage 1
    z0 = pp(0, 0);
    [s1, c1] = ha(m, 1, pp(1, 0), pp(0, 1));
    [s2, c2] = fa(m, 2, pp(2, 0), pp(1, 1), pp(0, 2));
    [s3, c3] = fa(m, 3, pp(3, 0), pp(2, 1), pp(1, 2));
    [s4, c4] = fa(m, 4, pp(4, 0), pp(3, 1), pp(2, 2));
    [m1, n1] = fa(m, 4, pp(1, 3), pp(0, 4), zero);
    [s5, c5] = fa(m, 5, pp(5, 0), pp(4, 1), pp(3, 2));
    [m2, n2] = fa(m, 5, pp(2, 3), pp(1, 4), pp(0, 5));
    [s6, c6] = fa(m, 6, pp(6, 0), pp(5, 1), pp(4, 2));
    [s7, c7] = fa(m, 7, pp(7, 0), pp(6, 1), pp(5, 2));
    [s8, c8] = fa(m, 8, zero, pp(7, 1), pp(6, 2));
    [m3, n3] = fa(m, 6, pp(3, 3), pp(2, 4), pp(1, 5));
    [m4, n4] = fa(m, 7, pp(4, 3), pp(3, 4), pp(2, 5));
    [m5, n5] = fa(m, 8, pp(5, 3), pp(4, 4), pp(3, 5));
    [m6, n6] = fa(m, 9, pp(6, 3), pp(5, 4), pp(4, 5));
    [m7, n7] = fa(m, 10, pp(7, 3), pp(6, 4), pp(5, 5));
    [m8, n8] = fa(m, 11, zero, pp(7, 4), pp(6, 5));

    % Stage 2
    z1 = s1;
    [x1, y1] = ha(m, 2, c1, s2);
    [x2, y2] = fa(m, 3, c2, s3, pp(0, 3));
    [x3, y3] = fa(m, 4, c3, s4, m1);
    [x4, y4] = fa(m, 5, c4, s5, m2);
    [x5, y5] = fa(m, 6, c5, s6, m3);
    [x6, y6] = fa(m, 7, c6, s7, m4);
    [x7, y7] = fa(m, 8, c7, s8, m5);
    [x8, y8] = fa(m, 9, c8, m6, pp(7, 2));
    [j1, k1] = ha(m, 6, n2, pp(0, 6));
    [j2, k2] = fa(m, 7, n3, pp(1, 6), pp(0, 7));
    [j3, k3] = fa(m, 8, n4, pp(2, 6), pp(1, 7));
    [j4, k4] = fa(m, 9, n5, pp(3, 6), pp(2, 7));
    [j5, k5] = fa(m, 10, n6, pp(4, 6), pp(3, 7));
    [j6, k6] = fa(m, 11, n7, pp(5, 6), pp(4, 7));
    [j7, k7] = fa(m, 12, n8, pp(6, 6), pp(5, 7));
    [j8, k8] = ha(m, 13, pp(7, 6), pp(6, 7));

    % Stage 3
    z2 = x1;
    [l1, r1] = ha(m, 3, y1, x2);
    [l2, r2] = ha(m, 4, y2, x3);
    [l3, r3] = fa(m, 5, y3, x4, n1);
    [l4, r4] = fa(m, 6, y4, x5, j1);
    [l5, r5] = fa(m, 7, y5, x6, j2);
    [l6, r6] = fa(m, 8, y6, x7, j3);
    [l7, r7] = fa(m, 9, y7, x8, j4);
    [l8, r8] = fa(m, 10, y8, m7, j5);
    [l9, r9] = ha(m, 11, m8, j6);
    [l10, r10] = ha(m, 12, pp(7, 5), j7);

    % Stage 4
    z3 = l1;
    [p1, q1] = ha(m, 4, r1, l2);
    [p2, q2] = ha(m, 5, r2, l3);
    [p3, q3] = ha(m, 6, r3, l4);
    [p4, q4] = fa(m, 7, r4, l5, k1);
    [p5, q5] = fa(m, 8, r5, l6, k2);
    [p6, q6] = fa(m, 9, r6, l7, k3);
    [p7, q7] = fa(m, 10, r7, l8, k4);
    [p8, q8] = fa(m, 11, r8, l9, k5);
    [p9, q9] = fa(m, 12, r9, l10, k6);
    [p10, q10] = fa(m, 13, r10, j8, k7);
    [p11, q11] = ha(m, 14, pp(7, 7), k8);

    % Stage 5: final vector addition
    z4 = p1;
    [z5, v1] = ha(m, 5, q1, p2);
    [z6, v2] = fa(m, 6, q2, p3, v1);
    [z7, v3] = fa(m, 7, q3, p4, v2);
    [z8, v4] = fa(m, 8, q4, p5, v3);
    [z9, v5] = fa(m, 9, q5, p6, v4);
    [z10, v6] = fa(m, 10, q6, p7, v5);
    [z11, v7] = fa(m, 11, q7, p8, v6);
    [z12, v8] = fa(m, 12, q8, p9, v7);
    [z13, v9] = fa(m, 13, q9, p10, v8);
    [z14, v10] = fa(m, 14, q10, p11, v9);
    z15 = bitor(q11, v10);   % final carry v10 is kept (was dropped before)

    bits = [z0, z1, z2, z3, z4, z5, z6, z7, z8, z9, z10, z11, z12, z13, z14, z15];
    z = bits * (2 .^ (0:15))';
end

% HAA: sum = a | b (approx) or a ^ b (exact), carry = a & b
function [s, c] = ha(mask, col, a, b)
    if bitget(mask, col + 1)
        s = bitor(a, b);
    else
        s = bitxor(a, b);
    end
    c = bitand(a, b);
end

% FAA: sum = (a ^ b) | cin (approx) or a ^ b ^ cin (exact), carry = majority
function [s, c] = fa(mask, col, a, b, cin)
    if bitget(mask, col + 1)
        s = bitor(bitxor(a, b), cin);
    else
        s = bitxor(bitxor(a, b), cin);
    end
    c = bitor(bitor(bitand(a, b), bitand(b, cin)), bitand(cin, a));
end
