function [d_est, PSD_MUSIC] = music_range_singleframe( ...
    s, channel_id, fc_step, num_PSD_grid)
% MUSIC_RANGE_SINGLEFRAME Estimate range from one complex BLE channel frame.
%
% Purpose:
%   Implement the original single-frame MUSIC pseudo-spectrum calculation
%   and select the distance associated with its maximum value.
%
% Inputs:
%   s            - Complex channel vector with one value per BLE channel.
%   channel_id   - Channel-index vector corresponding to s.
%   fc_step      - Scalar frequency interval between channels in hertz.
%   num_PSD_grid - Scalar number of distance-grid points.
%
% Outputs:
%   d_est     - Scalar MUSIC range estimate in meters.
%   PSD_MUSIC - num_PSD_grid-by-1 normalized MUSIC pseudo-spectrum.
%
% Processing:
%   Uses the original sliding-subarray covariance loop, eigendecomposition,
%   noise-subspace projection, distance scan, and maximum-peak selection.
%
% Notes:
%   The original implementation assumes one signal source and W = floor(N/2).

c = physconst('lightspeed');
s = s(:);
N = length(s);
W = floor(N/2);
L = N - W + 1;
dist_max = 0.5*c/fc_step; % Scalar global MUSIC range estimate in meters

R = zeros(W, W);
for l = 1:L
    x_l = s(l:l+W-1);
    R = R + x_l * x_l';
end
R = R / L;

[V, D] = eig(R);
[~, idx] = sort(real(diag(D)), 'descend');
V = V(:, idx);
Ns = 1;
En = V(:, Ns+1:end);
G = En * En';
r = (0:num_PSD_grid-1) * dist_max/num_PSD_grid;
PSD_MUSIC = zeros(num_PSD_grid, 1);
f0 = channel_id(1:W).' * fc_step;

for k = 1:num_PSD_grid
    a = exp(-1j * 4*pi * f0 * r(k) / c);
    PSD_MUSIC(k) = 1 ./ real(a' * G * a);
end
PSD_MUSIC = PSD_MUSIC / max(PSD_MUSIC);

[~, idx_max] = max(PSD_MUSIC);
d_est = r(idx_max);
end
