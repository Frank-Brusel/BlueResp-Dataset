function [combined_CSI, t] = load_kw45_ble_measurement(IQ_file, dist_file, rows_per_frame)
% LOAD_KW45_BLE_MEASUREMENT Load KW45 IQ data and construct BLE channel signals.
%
% Purpose:
%   Load IQ samples and timestamps, align their common frame count, and
%   construct one complex multi-channel signal vector for each BLE frame.
%
% Inputs:
%   IQ_file         - IQ raw data file
%   dist_file       - distance data file with timestamps
%   rows_per_frame  - number of IQ rows per BLE CS frame (measurement)
%
% Outputs:
%   combined_CSI    - complex BLE channel CSI matrix of size C x P x F,
%                     where C ~ number of channels, 
%                           P ~ number of paths, 
%                           F ~ number of frames 
%   t               - timestamps of BLE CS frames in seconds

data = load(IQ_file);
[num_rows, num_channels] = size(data);
num_frames = num_rows / rows_per_frame;
num_paths = rows_per_frame / 4;

log_table = readtable(dist_file);
actual_time_raw = log_table.Duration_ms;
delta_t_s = actual_time_raw / 10000;
t_csv = cumsum(delta_t_s);
num_csv_frames = length(t_csv);

if num_frames > num_csv_frames
    num_extra_frames = num_frames - num_csv_frames;
    num_frames = num_csv_frames;
    data = data(1:num_frames * rows_per_frame, :);
    t = t_csv;
    fprintf('Notice: IQ data contain %d extra frames and were truncated to the CSV-aligned portion.\n', ...
        num_extra_frames);
elseif num_frames < num_csv_frames
    t = t_csv(1:num_frames);
    fprintf('Notice: CSV data contain %d extra frames and were truncated to the IQ-aligned portion.\n', ...
        num_csv_frames - num_frames);
else
    t = t_csv;
end

combined_CSI = zeros(num_channels, num_paths, num_frames);
for i = 1 : num_frames
    for j = 1 : num_paths
        idx = (i-1)*rows_per_frame + (j-1)*num_paths;
        init = data(idx+1, :) + 1j * data(idx+2, :);
        refl = data(idx+3, :) + 1j * data(idx+4, :);

        combined_CSI(:, j, i) = (init .* refl).';
    end
end
end
