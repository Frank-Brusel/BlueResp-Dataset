function [peak_freq_est] = est_peak_freq_fft(s, fs, freq_band, fft_len_factor)
% EST_peak_freq_fft Estimate peak (dominant) frequency of given signal by basic FFT.
%
% Purpose:
%   Apply the original mean removal, Hamming window, zero-padded FFT, and
%   band-limited maximum search to estimate the respiration rate (RR).
%
% Inputs:
%   s               - signal waveform
%   fs              - sampling rate in Hz
%   freq_band       - frequency range in Hz for peak search
%   fft_len_factor  - factor of FFT length extension (>= 1)
%
% Outputs:
%   peak_freq_est   - estimated respiration frequency in Hz

s = s - mean(s);
L = length(s);
s_windowed = s .* hamming(L);

NFFT = 2^nextpow2(L * fft_len_factor);
Y = fft(s_windowed, NFFT);
Y_mag = abs(Y(1:NFFT/2+1));

f = fs * (0:(NFFT/2)) / NFFT;
valid_idx = find(f >= freq_band(1) & f <= freq_band(2));

if ~isempty(valid_idx)
    [~, peak_loc] = max(Y_mag(valid_idx));
    target_idx = valid_idx(peak_loc);
    peak_freq_est = f(target_idx);
else
    peak_freq_est = 0;
end
end
