function [d_static, path_idx] = estimate_static_music_range(combined_CSI, f_step, num_PSD_grid, path)
% ESTIMATE_STATIC_MUSIC_RANGE Estimate a static range from all BLE frames.
%
% Purpose:
%   Apply the original single-frame MUSIC estimator to every BLE frame and
%   obtain a global static range from the summed pseudo-spectrum.
%
% Inputs:
%   combined_CSI    - complex BLE signal matrix
%   f_step          - frequency interval between neighboring channels in Hz
%   num_PSD_grid    - number of MUSIC distance-grid points
%   path            - communication path used for static distance estimation
%                     path = 0: automatic determine communication path
%                     path = 1~num_paths: specify communication path
%
% Outputs:
%   d_static        - static distance estimated
%   path_idx        - index of communication path selected when path = 0

dist_max = 0.5*physconst('LightSpeed')/f_step; % maximum MUSIC range estimate in meters
[num_channels, num_paths, num_frames] = size(combined_CSI);

if nargin <= 3 || (path < 1 || path > num_paths)
    path = 0;
    d_path = zeros(num_paths, num_frames);
    PSD_path = zeros(num_PSD_grid, num_paths, num_frames);
end

PSD = zeros(num_PSD_grid, num_frames);

for i = 1 : num_frames
    if path > 0 && (path >= 1 && path <= num_paths)
        [~, PSD(:, i)] = music_range_singleframe( ...
            combined_CSI(:, path, i), 0:num_channels-1, f_step, num_PSD_grid);
        PSD(:, i) = PSD(:, i) / max(PSD(:, i)); % normalize each PSD curve
    elseif path == 0
        for j = 1 : num_paths
            [d_path(j, i), PSD_path(:, j, i)] = music_range_singleframe( ...
                combined_CSI(:, j, i), 0:num_channels-1, f_step, num_PSD_grid);
            PSD_path(:, j, i) = PSD_path(:, j, i) / max(PSD_path(:, j, i)); % normalize each PSD curve
        end
    else
        error('Incorrect path %d to extract CSI data!', path);
    end
end

if path == 0
    [~, path_idx] = min(mean(d_path, 2));
    PSD = squeeze(PSD_path(:, path_idx, :));
else
    path_idx = path;
end

r_grid = (0:num_PSD_grid-1) * dist_max/num_PSD_grid;
PSD_sum = sum(PSD, 2) / num_frames;
[~, idx_static] = max(PSD_sum);
d_static = r_grid(idx_static);
end
