clear all;
addpath(fullfile(fileparts(mfilename('fullpath')), 'util'));
% Set random number generation for reproducibility
rng('default') 

debug = true;

% Global Parameters (Literally)
earthRadius = 6371e3; 



% Radar parameters
fc         = 10.7e9;              % Operating frequency (Hz)
prf        = 750;
pri        = 1/prf;
maxrng     = time2range(pri);     % Maximum range (m)
bw         = 240e6;                % Bandwidth (Hz)
fs         = 2*bw;                % Sampling Frequency (Hz)
rngres     = 0.6;                 % Range resolution (m)
tbprod     = pri*bw;              % Time-bandwidth product
[lambda,c] = freq2wavelen(fc);    % Wavelength (m)
rx_Nf      = 1.4;                 % Recevier Noise Figure
numPulses  = 50;                  % Number of pulses to record 
rxGain_dB  = 17;

scene = radarScenario(UpdateRate=prf);

% Satellite Parameters
speed = 0;%7.62e3;                   % Satellite Speed (m/s)
r = 1e3;                        % Orbit Radius (m)
yaw = 180;

gainTx = 34.0; % Gain (dBi)
EIRP = 45.1; % Effective Isotropic Radiated Power
peakPower = 10^((EIRP-gainTx)/10);

initPos = [r 0 0];
initVel = [0 speed 0];


accBody = [0 speed^2/(r+earthRadius) 0];
angVelBody = [0 0 speed/(r+earthRadius)];

% Positions (column)
txPos = initPos(:);
rxPos = [0;0;0];


% TX orientation: yaw = az_tx, pitch = -el_tx
initOrientTx = quaternion([0, -90, 0], 'eulerd', 'ZYX', 'frame');




% Create trajectory and platforms
traj = kinematicTrajectory('SampleRate',prf, ...
    'Position',initPos, ...
    'Velocity',initVel, ...
    'Orientation',initOrientTx, ...
    'AccelerationSource','Property', ...
    'Acceleration',accBody, ...
    'AngularVelocitySource','Property', ...
    'AngularVelocity',angVelBody);

% RX->Target LOS
tgtPos = [0 2000 0];   % wherever your target is
v_rx_to_tgt = tgtPos(:) - rxPos(:);
az_rx = atan2d(v_rx_to_tgt(2), v_rx_to_tgt(1));
el_rx = atan2d(v_rx_to_tgt(3), norm(v_rx_to_tgt(1:2)));
initOrientRx = quaternion([az_rx + 180, -el_rx, 0], 'eulerd', 'ZYX', 'frame');

txPlat  = platform(scene,Trajectory=traj);
rxPlat  = platform(scene,Position=rxPos.', Orientation=initOrientRx); % note row vector allowed
tgtPlat = platform(scene, Position=tgtPos);

%PlotScenario(txPlat, rxPlat, tgtPlat, 400);

% Waveform
data = decode_starlink_signal('output.data');





% Figure out the original sample rate of the data
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

figure(5)
plot(abs(data))


% Create waveform
waveform = StarLinkWaveform(data, fs, prf);
fprintf('Waveform output power: %.1f dB\n', mag2db(rms(waveform.IQData(:))));
fprintf('Waveform length: %d\n', length(waveform.IQData(:)));

waveform_samples = length(data);
expected_samples = round(fs * pri);
fprintf('Waveform samples: %d\n', waveform_samples);
fprintf('Expected samples per PRI: %d\n', expected_samples);



% Transmitter
transmitter = phased.Transmitter(PeakPower=peakPower,Gain=gainTx,LossFactor=0);

% Transmit antenna
txAntenna   = phased.IsotropicAntennaElement(FrequencyRange=[9e9 11e9]);
radiator    = phased.Radiator(Sensor=txAntenna,PropagationSpeed=c, OperatingFrequency=fc);

% Bistatic transmitter
biTx        = bistaticTransmitter(Waveform=waveform, ...
    Transmitter=transmitter, ...
    TransmitAntenna=radiator); 


% Receive antennas
rxant_ref = phased.IsotropicAntennaElement(FrequencyRange=[9e9 11e9]);
collector_ref = phased.Collector(Sensor=rxant_ref,...
    PropagationSpeed=c,...
    OperatingFrequency=fc);

rxant_sig = phased.IsotropicAntennaElement(FrequencyRange=[9e9 11e9]);

collector_sig = phased.Collector(Sensor=rxant_sig,...
    PropagationSpeed=c,...
    OperatingFrequency=fc);



% Receiver
receiver_ref = phased.Receiver(Gain=rxGain_dB, SampleRate=fs, NoiseFigure=rx_Nf, SeedSource='Property');
receiver_sig  = phased.Receiver(Gain=rxGain_dB, SampleRate=fs, NoiseFigure=rx_Nf, SeedSource='Property');


bistatic_delay = (r + 200) / c;          % ~1.67 ms
window = pri;    % add delay on top of CPI

% Bistatic receiver
biRx        = bistaticReceiver(ReceiveAntenna=collector_sig, ...
    Receiver=receiver_sig, ...
    SampleRate=fs, ...
    WindowDuration= window,MaxCollectDurationSource='Property', ...
    MaxCollectDuration=bistatic_delay + pri);





% Load reflector geometry for RCS calculation (Antenna Toolbox platform)
p = platform;
p.FileName = 'tetrahedra.stl';
p.Units = 'm';

% Initialize Datacube for reference
numSamples         = round(window*fs); % Number of range samples
numElements        = 1; % Number of elements in receive array
ref_cube           = zeros(numSamples,numPulses,like=1i); % Datacube
% Initialize datacube for signal
sig_cube           = zeros(numSamples,numPulses,like=1i); % Datacube


size(ref_cube)
advance(scene);
t = scene.SimulationTime; 

tEnd = nextTime(biRx);

num_time_steps_rem = numPulses;
time_steps = 0;
endIdx = 0;
tot_time = 0;
samplesPerPri = fs*pri;
biRx.WindowDuration = pri; % Give it some breathing room

% For Free Space Reference Channel
freespace = phased.FreeSpace( ...
    'OperatingFrequency', fc, ...
    'SampleRate', fs, ...
    'PropagationSpeed', physconst('LightSpeed'));
if debug
    
end

 tic;

 

% % Simulate CPI
for pIdx = 1:numPulses


    % Use actual ranges from scene
    poses   = platformPoses(scene,'rotmat');

    txPose = poses(1);
    rxPose = poses(2);
    tgtPose = poses(3);

    % Reference Channel
    originPos = txPose.Position(:);      % 3x1
    destPos   = rxPose.Position(:);      % colocated receiver pose
    originVel = txPose.Velocity(:);      % if available, else zeros(3,1)
    destVel   = rxPose.Velocity(:);

    % Calculate paths
    proppaths = bistaticFreeSpacePath(fc, ...
        poses(1),poses(2),poses(3));

     % Transmit
    [txSig,txInfo] = transmit(biTx,proppaths,t);

  
    % Recreate datacubes using samples: numSamples = round(requiredWindow * fs);

    assert(txInfo.SampleRate == biRx.SampleRate, 'SampleRate mismatch: resample waveform or set receiver SampleRate');

    % compute radiating angles from tx to rx
    [rngs,radAng] = rangeangle(destPos, originPos);  % dest, origin order as needed

    txRadiated = radiator(txSig(:,1), radAng);   
    propagated = freespace(txRadiated, originPos, destPos, originVel, destVel);
    % collect into reference RX sensors
    assert(all(abs(radAng(1,:)) <= 180 + 1e-12), 'az out of bounds');
    assert(all(abs(radAng(2,:)) <=  90 + 1e-12), 'el out of bounds');
    refCollected = collector_ref(propagated, radAng);
    [~, rxAng] = rangeangle(originPos, destPos, rxPose.Orientation);
    fprintf('RX angle of arrival: [%.2f, %.2f]\n', rxAng);


    % apply receiver front-end
    refIQ = receiver_ref(refCollected);


    % Update target reflection coefficient and get angles
    [Rtx,fwang] = rangeangle(poses(1).Position(:),tgtPose.Position(:),tgtPose.Orientation.');
    [Rrx,bckang] = rangeangle(poses(2).Position(:),tgtPose.Position(:),tgtPose.Orientation.');

    fprintf('Rtx = %.3f km\n', Rtx/1e3);
    fprintf('Rrx = %.3f km\n', Rrx/1e3);

    rcsLinear = 2000;%rcs(p,fc,TransmitAngle=fwang,ReceiveAngle=bckang,Polarization="VV",Scale="linear");

    rgain = sqrt(4*pi./lambda^2*rcsLinear);
    proppaths(2).ReflectionCoefficient = rgain;

    fprintf('rcsLinear: %.4f\n', rcsLinear);
    fprintf('rgain: %.4f\n', sqrt(rcsLinear));
    proppaths(2).ReflectionCoefficient = sqrt(rcsLinear);
    fprintf('Path 2 RC: %.4f\n', proppaths(2).ReflectionCoefficient);
    fprintf('Path 2 loss: %.1f dB\n', proppaths(2).PathLoss);
    fprintf('Path 2 length: %.1f m\n', proppaths(2).PathLength);

    % Receive
    [sigIQ,rxInfo] = receive(biRx,txSig,txInfo,proppaths);


    % Add I/Q to data vector
    numSamples = size(sigIQ,1);
    startIdx = endIdx + 1;
    endIdx = startIdx + numSamples - 1;

    numRxSamples = size(sigIQ, 1);
    actualSamples = min(numRxSamples, samplesPerPri);
    sig_cube(1:actualSamples, pIdx) = sigIQ(1:actualSamples);
    ref_cube(1:actualSamples, pIdx) = refIQ(1:actualSamples);

    % Advance scene
    advance(scene);
    t = scene.SimulationTime;
if debug

    fprintf('txSig power:      %.1f dB\n', mag2db(rms(txSig(:))));
    fprintf('txRadiated power: %.1f dB\n', mag2db(rms(txRadiated(:))));
    fprintf('propagated power: %.1f dB\n', mag2db(rms(propagated(:))));
    fprintf('refCollected power: %.1f dB\n', mag2db(rms(refCollected(:))));
    fprintf('refIQ power:      %.1f dB\n', mag2db(rms(refIQ(:))));

    fprintf('proppaths size: %d\n', numel(proppaths));
    fprintf('t value: %.6f\n', t);
    fprintf('biTx locked: %d\n', isLocked(biTx));
    fprintf('sigIQ power: %.1f dB\n', mag2db(rms(sigIQ(:))));
    P_tx_dBW     = 10*log10(peakPower) + gainTx;   % EIRP
    L_path2_dB   = proppaths(2).PathLoss;
    RC_dB        = 20*log10(proppaths(2).ReflectionCoefficient);
    P_rx_tgt_dBW = P_tx_dBW - L_path2_dB + RC_dB + rxGain_dB;
    fprintf('Expected target return: %.1f dBW\n', P_rx_tgt_dBW);
    fprintf('Noise floor:            %.1f dBW\n', mag2db(rms(sigIQ(:))));
    P_tx_dBW     = EIRP;                            
    L_path2_dB   = proppaths(2).PathLoss;           % 246 dB
    noise_dBW    = mag2db(rms(sigIQ(:)));           % -104.4 dB (noise floor)
    required_SNR = 10;                               % dB minimum to detect

    % Required received power
    P_rx_required = noise_dBW + required_SNR;
    fprintf('Required RX power: %.1f dBW\n', P_rx_required);

    % Required RCS
    RCS_dB_required = P_rx_required - P_tx_dBW + L_path2_dB - rxGain_dB;
    RCS_lin_required = db2pow(RCS_dB_required);
    fprintf('Required RCS: %.1f dB = %.1e m^2\n', RCS_dB_required, RCS_lin_required);
    % Check each path
for k = 1:numel(proppaths)
    fprintf('Path %d AngleOfDeparture: [%.2f, %.2f]\n', k, proppaths(k).AngleOfDeparture);
end
end



    % Estimate Remaining Time
    time = toc;
    tic;
    tot_time = time+tot_time;
    time_steps = time_steps + 1;
    avg_step_time = tot_time/time_steps;
    num_time_steps_rem = numPulses - time_steps;
    fprintf("Time Steps Remaining: %i \nEstimated Time Remaining: %g\n",  num_time_steps_rem, avg_step_time * num_time_steps_rem);
end




% Visualize raw received signal
timeVec = (0:(size(ref_cube(:),1) - 1))*1/fs;
figure(1)
cubedata = ref_cube(:)';
plot(timeVec,abs(cubedata))
grid on
axis tight
xlabel('Time (sec)')
ylabel('Magnitude (dB)')
title('Raw Received Signal')

figure(3)
squint = 0;
% for pIdx = 1:numPulses
% 
%     fd = 2*speed*cos(squint_angle)/lambda;   % Doppler shift
%     t_pulse = (0:numSamples-1).'/fs;
%     sig_cube(:,pIdx) = sig_cube(:,pIdx) .* exp(-1j*2*pi*fd*t_pulse);
% end
integrated_sig = sum(sig_cube, 2);    % sum along pulse dimension
integrated_ref = sum(ref_cube, 2);

timeVec = (0:length(sig_cube) - 1)*1/fs;
plot(timeVec, mag2db(abs(integrated_sig)))
figure(2)
% Matched filter the first pulse just to check

matched_output = xcorr(integrated_sig, integrated_ref);
plot(abs(matched_output));
title('Matched Filter Output (Pulse 1)');

[val, idx] = max(abs(matched_output));
timeVec = (0:length(matched_output) - 1)*1/fs;
middle = ceil(length(matched_output)/2);;
delay = abs(idx-middle)/fs;
distance = delay*3e8;


figure()
range_ax = ((0:length(matched_output)-1) - floor(length(matched_output)/2)) * c/fs;
plot(range_ax, mag2db(abs(matched_output)))
xlabel('Differential Range (m)')
ylabel('Magnitude (dB)')
grid on
xlim([-1000 1000])   % zoom in around zero

fprintf('sig_cube max: %.1f dB\n', mag2db(max(abs(sig_cube(:)))));
fprintf('ref_cube max: %.1f dB\n', mag2db(max(abs(ref_cube(:)))));
fprintf('Ratio: %.1f dB\n', mag2db(max(abs(sig_cube(:)))) - mag2db(max(abs(ref_cube(:)))));


proppaths = bistaticFreeSpacePath(fc, poses(1), poses(2), poses(3));
for k = 1:numel(proppaths)
    fprintf('Path %d:\n', k);
    fprintf('  PathLength: %.1f m\n', proppaths(k).PathLength);
    fprintf('  PathLoss: %.1f dB\n', proppaths(k).PathLoss);
    fprintf('  ReflectionCoefficient: %.6f\n', proppaths(k).ReflectionCoefficient);
end





