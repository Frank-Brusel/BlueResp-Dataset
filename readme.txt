BLE Channel Sounding Respiration Dataset
Dataset User Guide / Dataset README
Last updated: 2026-09-12

Path convention: Unless otherwise stated, all paths below are relative to the DataSet root directory.
See Section 9 for code entry points and dependencies. Instructions for BLE and reference signal processing are provided in Sections 10 and 11, respectively.

==================================================
1. Dataset Overview
==================================================
This dataset supports data archiving, loading, and algorithm reproduction for BLE Channel Sounding respiration monitoring.
It contains 538 complete records: 369 Normal, 120 Breath Holding, and 49 Vacant records.
The records contain BLE I/Q data, BLE timing and link CSV files, auxiliary CAN logs, and reference signal TXT files for scenarios with a subject present.

records/ contains the existing input files. Directory names and successful loading do not change the provenance of the data.
See Section 6 for the definitions of the chest-belt measurement device, signal, and RR.

==================================================
2. Experimental Categories and Conditions
==================================================
normal: The normal-breathing scenario label. Records are organized by subject_A/B/C, distance between the two boards, and original record name.
breath_hold: The breath-holding scenario label. Records are organized by subject_B/C, distance, and original record name.
vacant: The empty-scene control label. Records are organized by distance and original record name, with no human reference signal TXT files.

subject is the subject identifier from the original directory. xxcm retains the original straight-line distance label between the two boards. The final number in a record name is the trial number.
For vacant scenes, distance denotes the experimental configuration used for comparison under the same setup; it does not indicate that a subject is present at that distance.
The Pre-hold, Hold, and Recovery stages of a BH record may belong to one continuous record rather than three separate files.

Distance/cm             50    60    70    80    90   100   Total
Normal A                20    23     0     3     0     3     49
Normal B                40    40    20    20    20    20    160
Normal C                40    40    20    20    20    20    160
BH B                    10    10    10    10    10    10     60
BH C                    10    10    10    10    10    10     60
Vacant                  20    23     0     3     0     3     49
0 indicates that no corresponding records currently exist; no additional experiment directories are created.

==================================================
3. Directory Structure
==================================================
DataSet/
|-- readme.txt                       Data categories, file pairing, and code usage instructions
|-- code/                            11 MATLAB entry-point and required function files; see Section 9
|-- records/                         538 complete records
|   |-- normal/
|   |   |-- subject_A/{50,60,80,100}cm/<record>/
|   |   |-- subject_B/{50,60,70,80,90,100}cm/<record>/
|   |   `-- subject_C/{50,60,70,80,90,100}cm/<record>/
|   |-- breath_hold/
|   |   |-- subject_B/{50,60,70,80,90,100}cm/<record>/
|   |   `-- subject_C/{50,60,70,80,90,100}cm/<record>/
|   `-- vacant/{50,60,80,100}cm/<record>/
`-- metadata/
    |-- dataset_index.csv           Index of scenarios, subjects, distances, and paired files
    `-- code_dependencies.json      MATLAB environment and function dependencies

The directory tree shows all top-level directories and metadata files in the package without expanding individual records.
Braces represent multiple existing directories. <record> represents a specific record directory with its original name, not a literal directory name.

==================================================
4. File Naming Convention and Pairing
==================================================
Record directory: yyyyMMddTHHmmss_subject-or-scenario_distance_trial.
yyyyMMddTHHmmss in a filename is the date-time identifier retained from the original record; it does not directly establish synchronization.
All files for a record remain in the same trial directory with their original filenames.

Example directory illustrating the naming convention:
records/normal/subject_A/60cm/20260620T154541_A_60cm_6/

All 5 files in this directory:
  20260620T154541_iq.txt             BLE I/Q
  distance_data_20260620T154541.csv  BLE timing and link fields
  can_log_20260620T154541.csv        Auxiliary CAN log
  can_log_20260620T154541.txt        Auxiliary CAN text log
  20260620T154538.txt                Reference signal TXT for the same record

The IQ file and distance_data CSV must use the same BLE timestamp. Do not use the CAN CSV as the timing input.
The reference TXT is associated through the same record directory and the reference_file field in dataset_index.csv, while retaining its own original timestamp.
In this example, the reference filename precedes the BLE filename by 3 s. The current production algorithm does not automatically crop signals or calibrate device clocks based on this difference.

==================================================
5. BLE Channel Sounding Data and Processing Pipeline
==================================================
The IQ files for all 538 records have 79 columns, corresponding to 79 frequency points. The production frequency step is fc_step = 1 MHz.
Each frame contains rows_per_frame = 16 rows organized into 4 communication paths.
For each path, 4 consecutive rows contain the I and Q components from both ends: rows 1/2 form one complex vector, and rows 3/4 form the other.
load_kw45_ble_measurement multiplies these vectors element by element to form combined_CSI with dimensions channels x paths x frames.

The timing input is the distance_data CSV. The current loading function reads Duration_ms and executes:
  delta_t_s = log_table.Duration_ms / 10000;
  t_csv = cumsum(delta_t_s);
This is the conversion used by the current production code. Do not change the divisor to 1000 based solely on the field name.
The Timestamp_ns field remains in the CSV, but the current loading function does not use it to construct the time axis.
If the IQ and CSV frame counts differ, the function truncates them to their common frame count in memory only, without writing back to either file.

Actual BLE processing pipeline:
  I/Q + CSV timing
  -> combined_CSI
  -> MUSIC static-distance estimation across all frames and automatic path selection
  -> Static-distance phase compensation
  -> Fusion by summing across frequency points
  -> Unwrapping in the squared domain, followed by division by 2, to handle pi ambiguity
  -> Spline interpolation to 5 Hz
  -> Butterworth bandpass filtering + filtfilt
  -> smoothdata(..., 'sgolay')
  -> BLE phase respiration waveform
  -> Mean removal, Hamming window, zero-padded FFT, and maximum within the search band -> RR (BPM)

Production settings: 512 MUSIC distance-grid points; automatic path selection; bandpass filtering using butter(4,[0.1 0.8]/(5/2),'bandpass');
FFT search band [0.1,0.8] Hz and zero-padding factor 1.5. SG uses the automatic window in smoothdata without an additional fixed window.
The 1076 CAN CSV/TXT files are retained as auxiliary records and are not used in the current respiration processing pipeline.

==================================================
6. Ground-Truth Respiratory Data
==================================================
Ground truth in physical measurements is acquired using a physical chest-belt respiratory sensor. The model specified in the manual is HKH-11C.
Hardware: chest-belt respiratory sensor.
Signal acquired by the device: reference / ground-truth respiration signal.
Value extracted from that signal: ground-truth respiratory rate (GT RR), in BPM.
There are currently 489 reference TXT files stored alongside their corresponding records: 369 Normal and 120 BH.

Loading function code/load_resp_waveform.m:
  Skips standalone CC lines. For lines containing at least 7 hexadecimal fields, reads fields 6/7.
  waveValue = highByte * 256 + lowByte;
  Constructs t_gt = (0:N-1)/fs_gt, subtracts the mean, and normalizes by the maximum absolute value.

code/estimate_RR_resp_waveform.m then applies bandpass filtfilt, SG smoothing, and amplitude normalization.
Production GT settings: fs_gt = 50 Hz; butter order parameter 4; passband [0.1,0.8] Hz;
Welch window 10 s (500 samples), overlap 5 s (250 samples), and NFFT 8192.
The current call does not pass the optional search band to est_peak_freq_welch; it selects the global maximum of the one-sided Welch PSD.

The reference signal is processed as a complete sequence. The current main program does not specify an additional cropping interval.
In the main program, resp_rate_bpm_gt is the reference RR, and resp_wave is the processed, normalized reference waveform.

==================================================
7. Breath-Holding Data Usage
==================================================
For records under records/breath_hold/, use the same BLE calls described in Section 10, changing only the record directory and input file paths.
If a reference TXT is available, use Section 11 to decode and process the reference waveform. Keep the complete continuous record; do not physically split it into three segments.
A single RR from the full record is a dominant spectral-peak candidate. It does not represent the actual RR during the Hold stage and cannot by itself establish breath holding.
The current code package has no automatic BH detector and does not automatically output Pre-hold/Hold/Recovery boundaries.

==================================================
8. Vacant-Scene Data Usage
==================================================
vacant is used for negative control / empty-scene comparison with the same BLE processing pipeline described in Section 10.
This scenario has no human reference TXT. Skip GT loading and do not create or fill in GT data.
Alternatively, change only main_folder in code/kw45_Resp_main.m to an existing vacant record path and run the program.
When no timestamp-only reference TXT is found, the main program skips the GT branch and outputs only the BLE waveform and spectral-peak RR.
A numerical estimate from vacant-scene data does not establish the detection of human respiration. The current code has no presence classifier.

==================================================
9. MATLAB Code: Entry Points and Dependencies
==================================================
Shared main program: code/kw45_Resp_main.m.
BLE and GT share this program and run in its BLE estimation and Ground-truth estimation sections, respectively.
There is no separate GT-only main script to name or create; call the two existing functions directly when processing GT separately.

code/ contains the following 11 files:
  kw45_Resp_main.m                 Selects a record, sets production parameters, runs BLE/reference processing, and plots the waveforms
  load_kw45_ble_measurement.m      Reads IQ + timing CSV and constructs combined_CSI and t_nonuniform
  BLE_RR_Estimation.m              Function entry point for BLE waveform and RR estimation
  estimate_static_music_range.m   MUSIC static-distance estimation across all frames and path selection
  music_range_singleframe.m       Single-frame MUSIC calculation
  extract_compensated_ble_phase.m Static compensation, channel fusion, and phase recovery in the squared domain
  rectify_ble_phase.m             Spline resampling, bandpass filtering, and SG smoothing
  load_resp_waveform.m            Reference TXT decoding, time-axis construction, mean removal, and normalization
  estimate_RR_resp_waveform.m      Entry point for reference waveform filtering, smoothing, and RR estimation
  est_peak_freq_fft.m             FFT peak frequency; returns Hz
  est_peak_freq_welch.m           Welch peak frequency and optional PSD/f outputs; frequency in Hz

Call hierarchy:
  kw45_Resp_main
  |-- load_kw45_ble_measurement
  |-- BLE_RR_Estimation
  |   |-- estimate_static_music_range -> music_range_singleframe
  |   |-- extract_compensated_ble_phase
  |   |-- rectify_ble_phase
  |   `-- est_peak_freq_fft (current BLE branch) / est_peak_freq_welch (existing optional branch)
  |-- load_resp_waveform
  `-- estimate_RR_resp_waveform
      `-- est_peak_freq_welch (current GT branch) / est_peak_freq_fft (existing optional branch)


MATLAB environment: The validated version is R2023b; the minimum version has not been determined.
MATLAB and Signal Processing Toolbox are required. Relevant functions include butter, filtfilt, hamming, and pwelch.
All custom dependencies are in code/; there are no external custom functions.
Before running, use which BLE_RR_Estimation -all to confirm that the current DataSet/code copy takes precedence.

These files perform data processing. The main program includes a basic waveform plot; paper-specific figure scripts and batch evaluation entry points are not included.
==================================================
10. How to Run BLE Processing
==================================================
The shared main program is code/kw45_Resp_main.m. In MATLAB, set Current Folder to DataSet/code,
open the file, set the fullfile arguments of main_folder to the record directory to be processed, and run kw45_Resp_main.
Select the record directory from the record_dir field in metadata/dataset_index.csv, keeping the production algorithm parameters unchanged.
The main program adds code/ to the path, extracts the BLE timestamp from the record directory name, and automatically locates the IQ and CSV files with that timestamp.
It does not use uigetfile or open a file-selection dialog.

To call the BLE functions separately, add code/ to the MATLAB path and configure the inputs as follows:
  IQ_file: The selected record's *_iq.txt file.
  dist_file: The distance_data_*.csv file with the same timestamp.
  rows_per_frame: 16; fc_step: 1e6 Hz.
  load_kw45_ble_measurement(IQ_file, dist_file, rows_per_frame)
      Returns combined_CSI and t_nonuniform.
  BLE_RR_Estimation(combined_CSI, fc_step, t_nonuniform, opt)
      Returns resp_rate_bpm, phase_uniform, and t_uniform.

opt contains num_PSD_grid, fs_uniform, flt_num, flt_den, and fft_param.
Use the existing configuration in the main program; see Section 5 for parameter definitions and the processing pipeline.
phase_uniform is the processed BLE phase waveform (rad), t_uniform is time (s), and resp_rate_bpm is in BPM.
When selecting another record, change only the input paths and preserve the IQ/CSV pairing rule in Section 4.

The existing main program begins with clear, clc, and close, which clear the workspace and Command Window and close the current figure.
Save any workspace variables you need before running. Calling the functions separately does not execute the main program's initialization statement.

==================================================
11. How to Run Ground-Truth Processing
==================================================
The shared main program kw45_Resp_main.m searches the same record directory for a reference TXT whose filename contains only a timestamp.
It executes the reference signal branch when this file is present and skips it otherwise; no additional GT main script is required.
The reference file is associated with the BLE record through reference_file in dataset_index.csv.
Do not use *_iq.txt or can_log_*.txt as the reference input.

To process a reference signal separately, add code/ to the MATLAB path and set:
  wave_file: The path to the selected record's reference TXT.
  fs_gt: 50 Hz, consistent with the sampling convention of the current records.
  load_resp_waveform(wave_file, fs_gt)
      Returns the decoded and normalized resp_wave and its time axis t_gt.
  estimate_RR_resp_waveform(resp_wave, fs_gt, opt_gt)
      Returns resp_rate_bpm_gt and the further processed resp_wave.

opt_gt uses the flt_num, flt_den, and welch_param configuration from the main program.
The Welch parameters are [10, 5, 8192]; see Section 6 for the remaining preprocessing details.
resp_wave is the normalized reference waveform, t_gt is in s, and resp_rate_bpm_gt is in BPM.
The current call processes the complete sequence without automatically aligning the absolute BLE/reference clocks or writing back to the reference TXT.

==================================================
12. Expected Outputs and Saving Results
==================================================
Workspace outputs of the main program:
  combined_CSI, t_nonuniform: Complex CSI and the BLE time axis obtained from the paired inputs.
  phase_uniform, t_uniform: The BLE phase waveform and time axis after compensation, resampling, filtering, and smoothing.
  resp_rate_bpm: BLE RR in BPM.
  resp_wave, t_gt: The processed reference waveform and its time axis, when a reference file is present.
  resp_rate_bpm_gt: Reference RR in BPM, when a reference file is present.
  opt, opt_gt: The algorithm configurations used for the run.

The main program produces a basic waveform overlay plot; it plots only BLE when no reference file is present.
The plot uses each signal's own relative time axis without absolute-time synchronization, cropping to the overlapping interval, or BLE/reference amplitude matching.
The current FFT function does not return FFT arrays. A separate call to est_peak_freq_welch can return its PSD and frequency axis.
The code package does not automatically output paper figures, BH labels, presence classifications, batch performance statistics, or clock-aligned waveforms.

The main program and algorithm functions do not call save/writetable or write files to record directories.
To save results, choose a separate output directory outside DataSet and save the waveforms, time axes, RR values, and configurations without overwriting existing outputs.

==================================================
13. Notes and Precautions
==================================================
records/ contains protected inputs and must not be overwritten directly.
Do not rewrite IQ, timing CSV, or reference TXT files, or change filename timestamps, experiment labels, or BH intervals.
Save new results to a separate output directory outside DataSet. Keep code, records, and essential metadata in the data package.

Actual fields in metadata/dataset_index.csv:
  record_id, scene, subject, distance_cm, trial, timestamp, record_dir;
  ble_iq_file, ble_timestamp_file, reference_file, reference_timestamp, gt_file;
  can_csv_file, can_txt_file, bh_start, bh_end, notes.
Paths are relative to DataSet. ble_timestamp_file points to the distance_data CSV, and reference_file points to the reference TXT.
gt_file, bh_start, and bh_end are currently blank. Do not replace blanks with 0, predefined RR values, or inferred event times.
Select records from the index by record_id or by conditions such as scene, subject, and distance_cm,
then join the path fields to the DataSet root directory to locate the corresponding input files.

metadata/code_dependencies.json records the MATLAB version, required toolboxes, and complete custom function dependencies.
These two files provide information about code provenance and the runtime environment; use dataset_index.csv for data selection and pairing.

DataSet/code does not depend on historical migration records or require machine-specific drive letters or user directories.

DataSet/code provides signal loading, waveform processing, and RR estimation. Reproducing all paper figures, historical window analyses,
or batch statistics requires the corresponding modules from the original project. This README does not present those unpackaged features as independently supported capabilities.
