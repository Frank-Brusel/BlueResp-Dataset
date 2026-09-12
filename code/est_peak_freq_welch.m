function [peak_freq, PSD, f] = est_peak_freq_welch(s, fs, NFFT, window, nOverlap, search_band)
% EST_PEAK_FREQ_WELCH Estimate peak (dominant) frequency of given signal by Welch's PSD.
%
% Inputs:
%   s           - signal waveform
%   fs          - sampling frequency in Hz
%   NFFT        - number of FFT points
%   window      - window used to divide the signal into segments 
%   nOverlap    - number to overlapping samples between adjoining segments
%   search_band - frequency band of interest for search
%
% Outputs:
%   peak_freq   - peak frequency estimated
%   PSD         - computed Welch's power spectrum density (PSD)
%   f           - frequency points

[PSD, f] = pwelch(s, window, nOverlap, NFFT, fs);

if nargin > 5
    idx = find(f >= search_band(1) & f <= search_band(2));
    if ~isempty(idx)
        f_tmp = f(idx);
        [~, idx_max] = max(PSD(idx));
        peak_freq = f_tmp(idx_max);
    else
        peak_freq = inf;
    end
else
    [~, idx_max] = max(PSD);
    peak_freq = f(idx_max);
end
end