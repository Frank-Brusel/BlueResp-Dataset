function [resp_rate, resp_wave] = estimate_RR_resp_waveform(resp_wave, fs, option)
% ESTIMATE_GT_RESPIRATION_WELCH Estimate chest-strap respiration rate with Welch PSD.
%
% Purpose:
%   Apply the original Welch PSD calculation and select the largest spectral
%   peak within the prescribed chest-strap respiration-rate range.
%
% Inputs:
%   resp_wave           - chest-strap respiration waveform
%   fs                  - chest-strap sampling rate in Hz
%   option:
%       fft_param       - parameters of basic FFT approach including
%                         [FFT_search_band, FFT_zero_padding_factor]
%                         where FFT_search_band ~ peak-search frequency range in Hz
%                               fft_len_factor  ~ factor of FFT length extension (>= 1)
%       welch_param     - parameters of Welch PSD including [win_sec, nOverlap_sec, nfft]
%                         where win_sec         ~ Welch window length in seconds
%                               nOverlap_sec    ~ Welch overlap length in seconds
%                               nfft            ~ FFT length used by pwelch
%       RR_bpm_range    - respiration rate range in BPM
%
% Outputs:
%   resp_rate           - estimated chest-strap respiration rate in BPM
%   resp_wave           - respiration waveform after preprocessing

nValidArgin = 2;    % number of input arguments except option

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
    FFT_search_band = [0, 0.5*fs];
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

% passband filtering
resp_wave = filtfilt(flt_num, flt_den, resp_wave);

% apply Savitzky-Golay filter to smooth the waveform and reduce noise
resp_wave = smoothdata(resp_wave, 'sgolay');
resp_wave = resp_wave / max(abs(resp_wave));

% estimate respiration rate
if strcmpi(est_algorithm, 'basic_FFT')
    [resp_freq] = est_peak_freq_fft(resp_wave, fs, FFT_search_band, FFT_zero_padding_factor);

else
    window = round(win_sec * fs);
    nOverlap = round(nOverlap_sec * fs);
    
    [resp_freq, ~, ~] = est_peak_freq_welch(resp_wave, fs, nfft, window, nOverlap);
end

resp_rate = resp_freq * 60;

end
