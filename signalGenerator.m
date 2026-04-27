% test_signal_chain.m
% Standalone test to verify bistatic signal chain without biRx
clear all;
addpath(fullfile(fileparts(mfilename('fullpath')), 'util'));
rng('default');
delete 'ref_datacube.mat';
delete 'sig_datacube.mat';
debug = false;
%% Parameters
fc      = 10.7e9;
bw      = 240e6;
fs      = 256e6;
prf     = 750;
pri     = 1/prf;
[lambda, c] = freq2wavelen(fc);
rx_Nf   = 1.7;
rxGain_dB = 21;
gainTx  = 34.0;
EIRP    = 45.1;
peakPower = 10^((EIRP - gainTx)/10);
rcsLinear = 10e8;   % artificially high to force detection
pulse_num = 1000;

%% Geometry
r       = 500e3;                     % TX altitude (m)
velocity = 7500;
tgt_distance = 200;
txPos   = [-5000; 0; r];
rxPos   = [0; 0; 0];
tgtPos  = [0; tgt_distance; 0];

fprintf('=== Geometry ===\n');
fprintf('TX pos:  [%.1f, %.1f, %.1f] m\n', txPos);
fprintf('RX pos:  [%.1f, %.1f, %.1f] m\n', rxPos);
fprintf('TGT pos: [%.1f, %.1f, %.1f] m\n', tgtPos);
fprintf('TX-TGT range: %.1f m\n', norm(tgtPos - txPos));
fprintf('RX-TGT range: %.1f m\n', norm(tgtPos - rxPos));

%% Velocities (static for this test)
txVel  = [velocity; 0; 0];
rxVel  = [0; 0; 0];
tgtVel = [0; 0; 0];

%% Platform orientations
% TX points nadir (-Z)
initOrientTx = quaternion([0, -90, 0], 'eulerd', 'ZYX', 'frame');
Rtx = rotmat(initOrientTx, 'frame');

% RX points toward target
v_rx_to_tgt = tgtPos - rxPos;
az_rx = atan2d(v_rx_to_tgt(2), v_rx_to_tgt(1));
el_rx = atan2d(v_rx_to_tgt(3), norm(v_rx_to_tgt(1:2)));
initOrientRx = quaternion([az_rx + 180, -el_rx, 0], 'eulerd', 'ZYX', 'frame');
Rrx = rotmat(initOrientRx, 'frame');

%% Antennas
txAntenna = phased.IsotropicAntennaElement(FrequencyRange=[9e9 11e9]);
rxAntenna = phased.IsotropicAntennaElement(FrequencyRange=[9e9 11e9]);

radiator  = phased.Radiator(Sensor=txAntenna, PropagationSpeed=c, OperatingFrequency=fc);
collector = phased.Collector(Sensor=rxAntenna, PropagationSpeed=c, OperatingFrequency=fc);

%% Transmitter and Receiver
transmitter  = phased.Transmitter(PeakPower=peakPower, Gain=gainTx, LossFactor=0);
receiver_out = phased.Receiver(Gain=rxGain_dB, SampleRate=fs, NoiseFigure=rx_Nf, SeedSource='Property');

%% Generate test waveform (simple complex sinusoid for testing)
numSamples = round(fs * pri);
data = decode_starlink_signal('output.data');
fs_data = fs * length(data) / round(fs*pri*3);  % ≈ 15x fs
fprintf('Estimated data sample rate: %.3f MHz\n', fs_data/1e6);

[P, Q]  = rat(fs / fs_data);          % rational approximation of ratio
data    = resample(data, P, Q);        % resample to simulation fs

fprintf('Resample Factor: %d\n', P/Q);
fprintf('Resampled length: %d\n', length(data));
fprintf('Expected length:  %d\n', round(fs * pri));

% Take one frame
data = data(1:ceil(length(data)/3));
if isempty(data)
    error('Decoded data is empty.');
end
data = data(:);                      % column vector
if ~isnumeric(data)
    error('Decoded data must be numeric samples (real or complex).');
end

test_sig = data;
sym_len = ceil(length(data)/302);



% t_vec      = (0:numSamples-1).' / fs;
% test_sig   = exp(1j * 2*pi * 1e6 * t_vec);   % 1 MHz tone
% fprintf('\n=== Waveform ===\n');
% fprintf('Samples: %d\n', numSamples);
% fprintf('Waveform power: %.1f dB\n', mag2db(rms(test_sig)));

%% Freespace objects
fs_tx_tgt = phased.FreeSpace(...
    'OperatingFrequency', fc, ...
    'SampleRate', fs, ...
    'PropagationSpeed', c, ...
    'TwoWayPropagation', false);

fs_tgt_rx = phased.FreeSpace(...
    'OperatingFrequency', fc, ...
    'SampleRate', fs, ...
    'PropagationSpeed', c, ...
    'TwoWayPropagation', false);

fs_direct = phased.FreeSpace(...
    'OperatingFrequency', fc, ...
    'SampleRate', fs, ...
    'PropagationSpeed', c, ...
    'TwoWayPropagation', false);
numSamples = ceil(pri*fs);

m_ref = matfile('ref_datacube.mat', 'Writable', true);
m_ref.data(1,1:numSamples) = complex(zeros(1,numSamples));  % preallocate type
m_sig = matfile('sig_datacube.mat', 'Writable', true);
m_sig.data(1,1:numSamples) = complex(zeros(1,numSamples));  % preallocate type
m_traj = matfile('traj_data.mat', 'Writable',true);
m_traj.data(1,1:3) = zeros(1,3);

% Precompute full waveform length needed
samples_per_pulse = round(fs / prf);
total_samples_needed = samples_per_pulse * pulse_num;

% Make sure decoded data is long enough
if length(data) < total_samples_needed
    % Tile the data if needed
    reps = ceil(total_samples_needed / length(data));
    data = repmat(data, reps, 1);
end





for idx = 1:pulse_num
     if mod(idx,10)==0
         fprintf("Pulse Number: %i\n", idx);
     end
     % Extract consecutive chunk for this pulse
    start_idx = (idx-1) * samples_per_pulse + 1;
    end_idx   = start_idx + samples_per_pulse - 1;
    test_sig  = data(start_idx:end_idx);
%% Update positions
txPos = txPos + pri*txVel;
rxPos = rxPos + pri*rxVel;
tgtPos = tgtPos + pri*tgtVel;
m_traj.data(idx, 1:3)= [txPos(1) txPos(2) txPos(3)];
%% Step 1 - Transmit
tx_out = transmitter(test_sig);

%% Step 2 - Radiate toward target
[~, aod_tgt] = rangeangle(tgtPos, txPos, Rtx);
tx_radiated_tgt = radiator(tx_out, aod_tgt);

%% Step 3 - Propagate TX to target
sig_at_tgt = fs_tx_tgt(tx_radiated_tgt, txPos, tgtPos, txVel, tgtVel);

%% Step 4 - Apply RCS
sig_reflected = sig_at_tgt * sqrt(rcsLinear);

%% Step 5 - Propagate target to RX
sig_at_rx = fs_tgt_rx(sig_reflected, tgtPos, rxPos, tgtVel, rxVel);

%% Step 6 - Collect at RX
[~, aoa_tgt] = rangeangle(tgtPos, rxPos, Rrx);
sig_collected = collector(sig_at_rx, aoa_tgt);

%% Step 7 - Apply receiver
sig_final = receiver_out(sig_collected).';

m_sig.data(idx, 1:samples_per_pulse) = sig_final(1:samples_per_pulse);

%% Step 8 - Direct path reference
[~, aod_rx] = rangeangle(rxPos, txPos, Rtx);
tx_radiated_rx = radiator(tx_out, aod_rx);
sig_direct = fs_direct(tx_radiated_rx, txPos, rxPos, txVel, rxVel).';

m_ref.data(idx, 1:samples_per_pulse) = sig_direct(1:samples_per_pulse);  % write one row at a time






if debug
    fprintf('\n=== Signal Chain ===\n');
    fprintf('Step 1 - TX output power:        %.1f dBW\n', mag2db(rms(tx_out)));
    fprintf('Step 2 - AOD to target: [%.2f, %.2f] deg\n', aod_tgt);
    fprintf('Step 2 - Radiated toward target: %.1f dBW\n', mag2db(rms(tx_radiated_tgt)));
    fprintf('Step 3 - Signal at target:       %.1f dBW\n', mag2db(rms(sig_at_tgt)));
    fprintf('Step 4 - Reflected signal:       %.1f dBW (RCS=%.1f dBm^2)\n', ...
    mag2db(rms(sig_reflected)), 10*log10(rcsLinear));
    fprintf('Step 5 - Signal at RX:           %.1f dBW\n', mag2db(rms(sig_at_rx)));
    fprintf('Step 6 - AOA from target: [%.2f, %.2f] deg\n', aoa_tgt);
    fprintf('Step 6 - Collected signal:       %.1f dBW\n', mag2db(rms(sig_collected)));
    fprintf('Step 7 - Final signal:           %.1f dBW\n', mag2db(rms(sig_final)));
    fprintf('\n=== Reference Channel ===\n');
fprintf('Direct path signal at RX:        %.1f dBW\n', mag2db(rms(sig_direct)));
fprintf('=== Geometry ===\n');
fprintf('TX pos:  [%.1f, %.1f, %.1f] m\n', txPos);
fprintf('RX pos:  [%.1f, %.1f, %.1f] m\n', rxPos);
fprintf('TGT pos: [%.1f, %.1f, %.1f] m\n', tgtPos);
fprintf('TX-TGT range: %.1f m\n', norm(tgtPos - txPos));
fprintf('RX-TGT range: %.1f m\n', norm(tgtPos - rxPos));
fprintf("TX-RX range: %.1f m\n", norm(txPos-rxPos));
% Verify bistatic range geometry
c = physconst('LightSpeed');
txPos = [0; 0; 500e3];
rxPos = [0; 0; 0];
tgtPos = [0; 200; 0];

R_tx_tgt = norm(tgtPos - txPos);
R_rx_tgt = norm(tgtPos - rxPos);
R_tx_rx  = norm(rxPos  - txPos);

r_bistatic = R_tx_tgt + R_rx_tgt - R_tx_rx;

fprintf('R_tx_tgt:    %.4f m\n', R_tx_tgt);
fprintf('R_rx_tgt:    %.4f m\n', R_rx_tgt);
fprintf('R_tx_rx:     %.4f m\n', R_tx_rx);
fprintf('r_bistatic:  %.4f m\n', r_bistatic);
fprintf('Expected peak at sample offset: %.1f\n', r_bistatic * fs/c);
end

end

%% Step 9 - Expected power budget
fprintf('\n=== Power Budget ===\n');
R_tx_tgt = norm(tgtPos - txPos);
R_tgt_rx = norm(tgtPos - rxPos);
R_direct = norm(rxPos - txPos);

FSPL_tx_tgt = 20*log10(4*pi*R_tx_tgt/lambda);
FSPL_tgt_rx = 20*log10(4*pi*R_tgt_rx/lambda);
FSPL_direct = 20*log10(4*pi*R_direct/lambda);
RCS_dB      = 10*log10(rcsLinear);

P_tgt_dBW = EIRP - FSPL_tx_tgt + RCS_dB - FSPL_tgt_rx + rxGain_dB;
P_dir_dBW = EIRP - FSPL_direct + rxGain_dB;
Pn_dBW    = 10*log10(1.38e-23 * 290 * bw * 10^(rx_Nf/10));

fprintf('FSPL TX->TGT:     %.1f dB\n', FSPL_tx_tgt);
fprintf('FSPL TGT->RX:     %.1f dB\n', FSPL_tgt_rx);
fprintf('FSPL direct:      %.1f dB\n', FSPL_direct);
fprintf('RCS:              %.1f dBm^2\n', RCS_dB);
fprintf('Expected tgt pwr: %.1f dBW\n', P_tgt_dBW);
fprintf('Expected dir pwr: %.1f dBW\n', P_dir_dBW);
fprintf('Noise floor:      %.1f dBW\n', Pn_dBW);
fprintf('Expected tgt SNR: %.1f dB\n', P_tgt_dBW - Pn_dBW);
fclose('all');

% %% Plot
% sig_final = sum(sig_cube, 2);
% sig_direct = sum(ref_cube, 2);
% figure(1); clf;
% t_axis = (0:numSamples-1)/fs * 1e3;
% subplot(4,1,1)
% plot(t_axis, abs(sig_final))
% title('Target Return (after receiver)')
% xlabel('Time (ms)'); ylabel('Amplitude'); grid on;
% 
% subplot(4,1,2)
% plot(t_axis, abs(sig_direct))
% title('Direct Path Reference')
% xlabel('Time (ms)'); ylabel('Amplitude'); grid on;
% 
% subplot(4,1,3)
% corr_ref = xcorr(sig_final, sig_direct);
% corr_sig = xcorr(SSS_sequence, sig_direct);
% range_ax = ((0:length(corr_sig)-1) - floor(length(corr_sig)/2)) * c/fs;
% plot(range_ax, mag2db(abs(corr_ref)));
% title('Cross Correlation (Range Profile)')
% xlabel('Differential Range (m)'); ylabel('Magnitude (dB)'); grid on;
% xlim([-1000 1000])
% 
% subplot(4,1,4)
% corr_sig = xcorr(sig_direct, SSS_sequence);
% range_ax = ((0:length(corr_sig)-1) - floor(length(corr_sig)/2)) * c/fs;
% plot(range_ax, abs(corr_sig));
% title('Cross Correlation (Range Profile)')
% xlabel('Differential Range (m)'); ylabel('Magnitude (dB)'); grid on;
% xlim([-1000 1000])