function [wave, t] = load_resp_waveform(resp_file, fs)
% LOAD_RESP_WAVEFORM Load and preprocess the chest-strap waveform.
%
% Purpose:
%   Decode hexadecimal chest-strap samples, filter the waveform, and create
%   its original timestamps.
%
% Inputs:
%   resp_file       - chest-strap hexadecimal text file
%   fs              - chest-strap sampling rate in hertz
%
% Outputs:
%   wave            - respiration waveform
%   t               - timestamps in seconds

%% Read and decode respiration data
fid = fopen(resp_file, 'r');
if fid == -1
    error('Failed to open respiration data file!');
end

fileLines = textscan(fid, '%s', 'Delimiter', '\n');
fileLines = fileLines{1};
fclose(fid);

numLines = length(fileLines);
wave = zeros(numLines, 1);
validCount = 0;

for i = 1 : numLines
    lineStr = strtrim(fileLines{i});
    if strcmp(lineStr, 'CC')
        continue;
    end

    parts = strsplit(lineStr, ' ');
    parts = parts(~cellfun('isempty', parts));

    if length(parts) >= 7
        highByte = hex2dec(parts{6});
        lowByte = hex2dec(parts{7});
        waveValue = highByte * 256 + lowByte;

        validCount = validCount + 1;
        wave(validCount) = waveValue;
    end
end

wave = wave(1:validCount);
if isempty(wave)
    error('Chest-strap data were not extracted successfully!');
end

%% Respiration data processing
t = (0:length(wave)-1) * (1/fs); % time stamps

% zero mean
wave = wave - mean(wave);  
wave = wave / max(abs(wave));

