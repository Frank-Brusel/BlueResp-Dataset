% ================================================ %
%  Main Program of KW45 BLE Respiration Estimation %
% ================================================ %

clear; clc; close;

%% ---------- Experiment Setup ---------- %%
% Extract data files from given data folder
% Dataset copy: resolve input from this script; algorithm settings below are unchanged.
code_folder = fileparts(mfilename('fullpath'));
dataset_root = fileparts(code_folder);
addpath(code_folder);
main_folder = fullfile(dataset_root, 'records', 'normal', 'subject_A', '60cm', ...
    '20260620T154541_A_60cm_6');
if ~isfolder(main_folder)
    error('Nonexisted data folder!');
else
    [~, folderName, ~] = fileparts(main_folder);
    timestamp = folderName(1:15);

    allFiles = dir(main_folder);
    iallFiles = allFiles(~[allFiles.isdir]);
    fileNames = {allFiles.name};

    idx_iq  = ~cellfun(@isempty, regexp(fileNames, ['^', timestamp, '_iq\.txt$'], 'once'));
    idx_csv = ~cellfun(@isempty, regexp(fileNames, ['^distance_data_', timestamp, '\.csv$'], 'once'));
    idx_txt = ~cellfun(@isempty, regexp(fileNames, '^\d{8}T\d{6}\.txt$', 'once'));

    IQ_file = fullfile(allFiles(idx_iq).folder, allFiles(idx_iq).name);
    dist_file = fullfile(allFiles(idx_csv).folder, allFiles(idx_csv).name);
    if ~all(~idx_txt)
        wave_file = fullfile(allFiles(idx_txt).folder, allFiles(idx_txt).name);
    end
end

% Setup experimental parameters
bf = @(ord, band, fs)(butter(ord, band/(fs/2), 'bandpass'));

rows_per_frame = 16;            % number of rows per two-way measurement in IQ data file
fc_step = 1e6;                  % step frequency (1 MHz)

num_PSD_grid = 512;             % number of grid points on x-axis of PSD
fs_uniform = 5;                % uniform frequency after resampling
BLE_filter_order = 4;           % Butterworth bandpass filter order
BLE_filter_band = [0.1, 0.8];   % passband of Butterworth bandpass filter
[b_bp, a_bp] = bf(BLE_filter_order, BLE_filter_band, fs_uniform);

fs_gt = 50;                     % frequency of ground-truth measurement
filter_order_gt = 4;            % filter order of denoising Butterworth filter for ground-truth measurement
filter_band_gt = [0.1, 0.8];    % passband of denoising Butterworth filter for ground-truth measurement
[b_bp_gt, a_bp_gt] = bf(filter_order_gt, filter_band_gt, fs_gt);

FFT_search_band = [0.1, 0.8];   % frequency band of interest
FFT_zero_padding_factor = 1.5;  % length scaling factor (>= 1) of FFT
Welch_win_sec = 10;             % window length of Welch's PSD estimation
Welch_nOverlap_sec = 5;         % overlapped length of Welch's PSD estimation
Welch_nfft = 2048;              % FFT length of Welch's PSD estimation
GT_Welch_nOverlap_sec = 5;      % validated Ground Truth Welch overlap length
GT_Welch_nfft = 8192;           % validated Ground Truth Welch FFT length

%% ---------- Respiration rate estimation using BLE CSI data ---------- %%
% Load KW45 BLE CSI data
[combined_CSI, t_nonuniform] = ...
    load_kw45_ble_measurement(IQ_file, dist_file, rows_per_frame);

% Respiration rate estimation
opt.num_PSD_grid = num_PSD_grid;
% opt.path = 4;                 % path = 0: automatic path selection
opt.fs_uniform = fs_uniform;
opt.flt_den = a_bp;
opt.flt_num = b_bp;
opt.fft_param = [FFT_search_band, FFT_zero_padding_factor];
% opt.welch_param = [Welch_win_sec, Welch_nOverlap_sec, Welch_nfft];

[resp_rate_bpm, phase_uniform, t_uniform] = ...
    BLE_RR_Estimation(combined_CSI, fc_step, t_nonuniform, opt);

%% ---------- Ground-truth respiration rate estimation ---------- %%
if ~all(~idx_txt)
    % Load chest-strap waveform data
    [resp_wave, t_gt] = load_resp_waveform(wave_file, fs_gt);

    % Ground-truth respiration rate estimation
    opt_gt.flt_den = a_bp_gt;
    opt_gt.flt_num = b_bp_gt;
    % opt_gt.fft_param = [FFT_search_band, FFT_zero_padding_factor];
    opt_gt.welch_param = [Welch_win_sec, GT_Welch_nOverlap_sec, GT_Welch_nfft];

    [resp_rate_bpm_gt, resp_wave] = estimate_RR_resp_waveform(resp_wave, fs_gt, opt_gt);
end

%% ---------- Plot waveform of BLE phase and ground-truth respiration ---------- %%
if ~all(~idx_txt)
    fprintf('Ground-truth respiration rate: %.1f bpm\n', resp_rate_bpm_gt);
end
fprintf('Estimated respiration rate:    %.1f bpm\n', resp_rate_bpm);

figure;
if ~all(~idx_txt)
    plot(t_gt, resp_wave, ...
         t_uniform, phase_uniform-mean(phase_uniform), 'LineWidth', 2); 
    legend('Ground truth', 'BLE phase');
else
    plot(t_uniform, phase_uniform-mean(phase_uniform), 'LineWidth', 2);
    legend('Uniformly resampled BLE phase');
end