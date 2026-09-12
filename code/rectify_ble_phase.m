function [phase_uniform, t_uniform] = rectify_ble_phase( ...
    t_nonuniform, phase_nonuniform, fs_uniform, b_bp, a_bp)
% RECTIFY_BLE_PHASE Resample rectify BLE phase.
%
% Purpose:
%   Resample the recovered phase onto a uniform sampling rate, and apply the original
%   Butterworth bandpass filter.
%
% Inputs:
%   t_nonuniform        - BLE timestamp vector in seconds
%   phase_nonuniform    - recovered BLE phase vector in radians
%   fs_uniform          - uniform resampling rate in Hz
%   b_bp, a_bp          - filter coefficients of bandpass Butterworth filter
%
% Outputs:
%   phase_uniform       - phase waveform after uniformly resampling and bandpass filtering
%   t_uniform           - uniform timestamp in seconds

min_t_len = min(length(t_nonuniform), length(phase_nonuniform));
t_uniform = (t_nonuniform(1) : 1/fs_uniform : t_nonuniform(min_t_len)).';

idx = (1 : min_t_len);
phase_uniform = interp1(t_nonuniform(idx), phase_nonuniform(idx), t_uniform, 'spline');

phase_uniform = filtfilt(b_bp, a_bp, phase_uniform);
phase_uniform = smoothdata(phase_uniform, 'sgolay');
end
