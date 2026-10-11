BLE Channel Sounding Respiration Dataset
Dataset README

==================================================
1. Dataset Overview & Categories
==================================================
This dataset supports data archiving, loading, and algorithm reproduction for BLE Channel Sounding respiration monitoring. It provides paired BLE phase measurements and ground-truth chest-belt respiratory signals.

The dataset contains 1,018 records in total:
Dataset_Paper_969/: 969 complete records of human respiration, categorized into Normal (normal breathing) and Mixed (includes Breath Holding stages).
 Dataset_Empty_49/: 49 Vacant / Empty records used as negative controls (no human present, no reference signal).

Experimental Conditions:
Records are structured hierarchically by: Environment -> Subject -> Angle -> Record
Environments: Outdoor, Indoor
 Subjects: A, B, C
 Orientations: 0deg, 45deg, 90deg, 180deg, and COR (corridor).
 Distances (board-to-board): 50cm, 60cm, 70cm, 80cm, 90cm, 100cm.

==================================================
2. Directory Structure
==================================================
Project root: D:\Matlab\测数据_7_20

Dataset_Paper_969/
|-- Outdoor/
|   |-- A/0deg/<record folder>/
|   |-- B/0deg/<record folder>/
|   `-- C/
|       |-- 0deg/<record folder>/
|       |-- 45deg/<record folder>/
|       |-- 90deg/<record folder>/
|       `-- 180deg/<record folder>/
`-- Indoor/
    `-- C/0deg/<COR record folder>/

Dataset_Empty_49/
`-- <Empty record folder>/

==================================================
3. File Naming Convention and Data Formats
==================================================
Record-folder naming format:
yyyyMMddTHHmmss_<A|B|C>_<distance>cm_<Normal|Mixed>_<0deg|45deg|90deg|180deg|COR>_<trial>

Each main record contains exactly these five file types (Empty records lack the reference TXT):
1. <T_ref>.txt: Paired chest-format reference signal. (Timestamp-only filename).
2. <T_ble>_iq.txt: BLE I/Q samples.
3. distance_data_<T_ble>.csv: BLE frame timing and link/distance fields.
4. can_log_<T_ble>.csv: Auxiliary CAN log (not used in the current pipeline).
5. can_log_<T_ble>.txt: Auxiliary CAN text log.

Data Formats:
 IQ TXT: Headerless whitespace-separated numeric matrix (79 columns for 79 frequency points).
 distance_data CSV: Provides BLE timing (Duration_ms).
 Reference TXT: Contains space-separated hexadecimal fields. The loader decodes fields 6/7 as high/low bytes to construct the ground-truth waveform (fs_gt = 50 Hz).

==================================================
4. Processing Pipeline
==================================================
BLE Pipeline:
 IQ + CSV timing -> combined_CSI
 MUSIC static-distance estimation (512 grid points) & automatic path selection
 Static-distance phase compensation & fusion
 Unwrapping in the squared domain -> Spline interpolation to 5 Hz
 Butterworth bandpass filtering ([0.1 0.8] Hz) -> sgolay smoothing -> BLE Phase Waveform
 FFT maximum within search band -> BLE Respiratory Rate (BPM)

Ground-Truth (GT) Pipeline:
 Load hexadecimal values -> Mean removal & amplitude normalization.
 Bandpass filtfilt -> SG smoothing -> GT Waveform.
 Welch PSD global maximum -> GT Respiratory Rate (BPM).

==================================================
5. MATLAB Code and Dependencies
==================================================
Shared main program: code/kw45_Resp_main.m.

Main dependencies in code/:
 load_kw45_ble_measurement.m: Reads IQ + timing CSV.
 BLE_RR_Estimation.m: Entry point for BLE waveform and RR estimation.
 estimate_static_music_range.m / music_range_singleframe.m: MUSIC calculations.
 extract_compensated_ble_phase.m / rectify_ble_phase.m: Phase recovery & filtering.
 load_resp_waveform.m: Reference TXT decoding.
 estimate_RR_resp_waveform.m: GT filtering and RR estimation.
 est_peak_freq_fft.m / est_peak_freq_welch.m: Spectral peak finders.

Environment requirement: MATLAB R2023b (or newer) with the Signal Processing Toolbox.

==================================================
6. How to Run
==================================================
The shared main script code/kw45_Resp_main.m automatically handles Normal, Breath-Holding (Mixed), and Vacant records.

1. In MATLAB, set your Current Folder to DataSet/code.
2. Open kw45_Resp_main.m.
3. Set the main_folder variable to the full path of the record directory you want to process.
4. Run the script.

Behavior:
 The program will automatically locate the paired IQ and CSV files based on the folder timestamp.
 If a reference TXT is found (Normal/Mixed records), it will process both the BLE and Ground-Truth signals and output a comparison plot.
 If no reference TXT is found (Vacant scenes), it will automatically skip the GT branch and only output the BLE waveform and estimated RR.
 For Breath-Holding records, the entire sequence is processed continuously; the code does not automatically split the record into pre-hold/hold/recovery stages.

==================================================
7. Notes and Precautions
==================================================
 Do not overwrite original data: The scripts do not write back to the data folders. Save any needed workspace variables or generated plots to a separate external directory.
 Metadata: Use metadata/dataset_index.csv for data selection and pairing (filtering by scene, subject, distance_cm, etc.).
 File Pairing: Always rely on the automatic timestamp matching handled by the main script. Do not attempt to rename the .txt reference files to match the BLE timestamps, as they maintain their own hardware acquisition offsets.