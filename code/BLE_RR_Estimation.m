function [resp_rate, phase_uniform, t_uniform] = BLE_RR_Estimation( ...
    CSI, f_step, t_nonuniform, option)
% BLE_RR_ESTIMATION Estimate respiration rate using BLE CS data
%
% Inputs:
%   CSI                 - BLE CSI data matrix (C x P x F)
%                         where C ~ number of channels
%                               P ~ number of communication paths
%                               F ~ number of frames
%   f_step              - frequency interval between neighboring channels in Hz
%   t_nonuniform        - timestamps of nonuniformly sampled CSI data
%   option:
%       num_PSD_grid    - number of MUSIC distance-grid points
%       path            - communication path used for static distance estimation
%                         path = 0: automatic determine communication path
%                         path = 1~num_paths: specify communication path
%       fs_uniform      - uniform resampling rate in Hz
%       flt_num, flt_den - filter coefficients of bandpass Butterworth filter
%       fft_param       - parameters of basic FFT approach including
%                         [FFT_search_band, FFT_zero_padding_factor]
%                         where FFT_search_band ~ peak-search frequency range in Hz
%                               fft_len_factor  ~ factor of FFT length extension (>= 1)
%       welch_param     - parameters of Welch PSD including [win_sec, nOverlap_sec, nfft]
%                         where win_sec         ~ Welch window length in seconds
%                               nOverlap_sec    ~ Welch overlap length in seconds
%                               nfft            ~ FFT length used by pwelch
%
% Outputs:
%   resp_rate           - estimated respiration rate in bpm
%   phase_uniform       - phase after uniform resampling
%   t_uniform           - timestamps after uniform resampling

%% Extract algorithm parameters
nValidArgin = 3;    % number of valid input arguments except option

if nargin <= nValidArgin || ~isfield(option, 'num_PSD_grid')
    num_PSD_grid = 512;
else
    num_PSD_grid = option.num_PSD_grid;
end

if nargin <= nValidArgin || ~isfield(option, 'path')
    com_path = 0;
else
    com_path = option.path;
end

if nargin <= nValidArgin || ~isfield(option, 'fs_uniform')
    fs_uniform = 10;
else
    fs_uniform = option.fs_uniform;
end

if nargin <= nValidArgin || ~isfield(option, 'flt_den')
    flt_den = 1;
else
    flt_den = option.flt_den;
end

if nargin <= nValidArgin || ~isfield(option, 'flt_num')
    flt_num = 1;
else
    flt_num = option.flt_num;
end

if nargin <= nValidArgin || (~isfield(option, 'fft_param') && ~isfield(option, 'welch_param'))
    est_algorithm = 'basic_FFT';
    FFT_search_band = [0, 0.5*fs_uniform];
    FFT_zero_padding_factor = 1;
elseif isfield(option, 'fft_param')
    est_algorithm = 'basic_FFT';
    FFT_search_band = option.fft_param(1:2);
    FFT_zero_padding_factor = option.fft_param(3);
elseif isfield(option, 'welch_param')
    est_algorithm = 'Welch_PSD';
    win_sec = option.welch_param(1);
    nOverlap_sec = option.welch_param(2);
    nfft = option.welch_param(3);
else
    error('Invalid parameter settings of estimation algorithm!');
end

%% Static distance estimation by MUSIC
[d_static, path_idx] = estimate_static_music_range(CSI, f_step, num_PSD_grid, com_path);
CSI_path = squeeze(CSI(:, path_idx, :));

%% Phase compensation using static distance estimate
[phase_nonuniform, ~] = extract_compensated_ble_phase(CSI_path, f_step, d_static);

%% BLE phase waveform extraction, resampling, and filtering
[phase_uniform, t_uniform] = rectify_ble_phase(...
    t_nonuniform, phase_nonuniform, fs_uniform, flt_num, flt_den);

%% Respiration rate estimation by BLE phase waveform
if strcmpi(est_algorithm, 'basic_FFT')
    [resp_freq] = est_peak_freq_fft(phase_uniform, fs_uniform, FFT_search_band, FFT_zero_padding_factor);

else
    window = round(win_sec * fs_uniform);
    nOverlap = round(nOverlap_sec * fs_uniform);
    
    [resp_freq, ~, ~] = est_peak_freq_welch(phase_uniform, fs_uniform, nfft, window, nOverlap);
end

resp_rate = resp_freq * 60;

end