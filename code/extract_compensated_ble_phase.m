function [phase_recovered, CSI_compensated] = ...
    extract_compensated_ble_phase(CSI, f_step, d_static)
% EXTRACT_COMPENSATED_BLE_PHASE Compensate range phase and recover BLE phase.
%
% Purpose:
%   Apply the original MUSIC range compensation, fuse BLE channels, and
%   calculate direct and square-domain phase-unwrapping results.
%
% Inputs:
%   CSI             - num_channels-by-num_frames combined complex BLE signal matrix
%   f_step          - frequency interval between neighboring channels in hertz
%   d_static        - static range estimate in meters by MUSIC
%
% Outputs:
%   phase_recovered - num_frames-by-1 square-domain recovered phase in radians
%   CSI_compensated - range-compensated complex BLE CSI matrix

c = physconst('lightspeed');
[num_channels, ~] = size(CSI);
channel_id = (0:num_channels-1)';  % channel IDs

delta_f_vector = channel_id * f_step;
phase_compensation = exp(1j * 4 * pi * delta_f_vector * d_static / c);
CSI_compensated = CSI .* phase_compensation;

CSI_sum = sum(CSI_compensated, 1).';

phase_doubled_unwrapped = unwrap(angle(CSI_sum .^ 2));
phase_recovered = phase_doubled_unwrapped / 2;
end
