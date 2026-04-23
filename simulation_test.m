clear all;
addpath(fullfile(fileparts(mfilename('fullpath')), 'util'));
% Set random number generation for reproducibility
rng('default') 

% Global Parameters (Literally)
earthRadius = 6371e3; 



% Radar parameters
fc         = 10.7e9;              % Operating frequency (Hz)
prf        = 750;
pri        = 1/prf;
maxrng     = time2range(pri);     % Maximum range (m)
bw         = 24e6;               % Bandwidth (Hz)
fs          = 2*bw;                % Sampling Frequency (Hz)
rngres     = 0.6;                 % Range resolution (m)
tbprod     = pri*bw;              % Time-bandwidth product
[lambda,c] = freq2wavelen(fc);    % Wavelength (m)


scene = radarScenario(UpdateRate=prf);

% Satellite Parameters
speed = 7.62e3;                   % Satellite Speed (m/s)
r = earthRadius + 500e3;          % Orbit Radius (m)
yaw = 90;

initPos = [r 0 0];
initVel = [0 speed 0];
initOrient = quaternion([yaw 0 0], 'eulerd', 'ZYX', 'frame');

accBody = [0 speed^2/r 0];
angVelBody = [0 0 speed/r];

traj = kinematicTrajectory('SampleRate',prf, ...
    'Position',initPos, ...
    'Velocity',initVel, ...
    'Orientation',initOrient, ...
    'AccelerationSource','Property', ...
    'Acceleration',accBody, ...
    'AngularVelocitySource','Property', ...
    'AngularVelocity',angVelBody);


% Define platforms
txPlat  = platform(scene,Trajectory=traj);
rxPlat  = platform(scene,Position=[earthRadius 0 0],Orientation=rotz(135).');
tgtPlat = platform(scene, Position=[earthRadius, 200, 0]);

PlotScenario(txPlat, rxPlat, tgtPlat, 400);

% Waveform
data = decode_starlink_signal('output.data');
% Take one frame
data = data(1:ceil(length(data)/3));
if isempty(data)
    error('Decoded data is empty.');
end
data = data(:);                      % column vector
if ~isnumeric(data)
    error('Decoded data must be numeric samples (real or complex).');
end







% Calculate number of chips that gives integer fs/prf
numChips = floor(pri * fs);          % integer number of samples per PRI

chip_wid = pri / numChips;           % clean chip width

% Trim or pad data to match
data = data(1:numChips);             % trim to exact length


waveform = StarLinkWaveform(data, fs, prf);
  




gain = 34.0; % Gain (dBi)
EIRP = 45.1; % Effective Isotropic Radiated Power
peakPower = 10^((EIRP-gain)/10);


% Transmitter
transmitter = phased.Transmitter(PeakPower=peakPower,Gain=gain,LossFactor=0);

% Transmit antenna
txAntenna   = phased.SincAntennaElement(FrequencyRange=[9e9 11e9]);
radiator    = phased.Radiator(Sensor=txAntenna,PropagationSpeed=c, OperatingFrequency=fc);

% Bistatic transmitter
biTx        = bistaticTransmitter(Waveform=waveform, ...
    Transmitter=transmitter, ...
    TransmitAntenna=radiator); 

% Receive antenna
numPulses = 750; % Number of pulses to record 
rxAntenna = phased.ShortDipoleAntennaElement(AxisDirection='Z');
rxarray   = phased.ULA(16,lambda/2,Element=rxAntenna);
collector = phased.Collector(Sensor=rxarray,...
    PropagationSpeed=c,...
    OperatingFrequency=fc);

Arx         = 1;                    % m²
rxGain_lin  = 4*pi*Arx/lambda^2;   % aperture → gain
rxGain_dB   = 10*log10(rxGain_lin);

% Receiver
receiver  = phased.Receiver(Gain=rxGain_dB,SampleRate=fs,NoiseFigure=6,SeedSource='Property');

% Bistatic receiver
biRx        = bistaticReceiver(ReceiveAntenna=collector, ...
    Receiver=receiver, ...
    SampleRate=fs, ...
    WindowDuration=pri*numPulses);

% Load reflector geometry for RCS calculation (Antenna Toolbox platform)

p = platform;
p.FileName = 'tetrahedra.stl';
p.Units = 'm';
% p.FileName = "tetrahedra.stl";   % <-- replace with your actual filename
% p.Units = "m";
%mesh(p, MaxEdgeLength=lambda/10);    % mesh at ~lambda/10 for accuracy at fc



% Initialize datacube
numSamples  = round(fs*pri); % Number of range samples
numElements = collector.Sensor.NumElements; % Number of elements in receive array
y           = zeros(numSamples*numPulses,numElements,like=1i); % Datacube
endIdx      = 0; % Index into datacube


advance(scene);
t = scene.SimulationTime; 

tEnd = nextTime(biRx); 

num_time_steps_rem = numPulses;

% Bistatic link budget check
txPower_dBW  = 10*log10(peakPower);
txGain_dB    = gain;

% Approximate ranges
Rtx_approx   = 500e3;              % satellite altitude ~500km
Rrx_approx   = 200;                % target very close to rx

% Free space path loss
FSPL_tx  = 20*log10(4*pi*Rtx_approx*fc/c);
FSPL_rx  = 20*log10(4*pi*Rrx_approx*fc/c);

% RCS (reflectorCorner is strong — roughly 10-20 dBsm)
rcs_dBsm = 15;

% Bistatic radar equation (dB)
rxPower_dB = txPower_dBW + txGain_dB - FSPL_tx + rcs_dBsm - FSPL_rx;

% Noise power
kB         = 1.38e-23;
T0         = 290;
NF_dB      = 6;
noisePwr_dB = 10*log10(kB*T0*fs) + NF_dB;

SNR_dB = rxPower_dB - noisePwr_dB;

fprintf('TX Power:       %.1f dBW\n',  txPower_dBW);
fprintf('TX Gain:        %.1f dBi\n',  txGain_dB);
fprintf('FSPL TX→TGT:   %.1f dB\n',   FSPL_tx);
fprintf('FSPL TGT→RX:   %.1f dB\n',   FSPL_rx);
fprintf('RCS:            %.1f dBsm\n', rcs_dBsm);
fprintf('Noise Power:    %.1f dBW\n',  noisePwr_dB);
fprintf('Expected SNR:   %.1f dB\n',   SNR_dB);
fprintf('EIRP: %.1f dBW\n', 10*log10(peakPower) + gain);





% Simulate CPI
while t < tEnd
    tic;
% Use actual ranges from scene
advance(scene);
poses   = platformPoses(scene,'rotmat');

     % Get platform positions
    %poses = platformPoses(scene,'rotmat');
     % Calculate paths
    proppaths = bistaticFreeSpacePath(fc, ...
        poses(1),poses(2),poses(3));
    % Update target reflection coefficient
    tgtPose = poses(3);
    [Rtx,fwang] = rangeangle(poses(1).Position(:),tgtPose.Position(:),tgtPose.Orientation.');
    [Rrx,bckang] = rangeangle(poses(2).Position(:),tgtPose.Position(:),tgtPose.Orientation.');
    fprintf('Rtx = %.3f km\n', Rtx/1e3);
    fprintf('Rrx = %.3f km\n', Rrx/1e3);
    
    rcsLinear = rcs(p,fc,TransmitAngle=fwang,ReceiveAngle=bckang,Polarization="VV",Scale="linear");
    rgain = sqrt(4*pi./lambda^2*rcsLinear);
    proppaths(2).ReflectionCoefficient = rgain;
     % Transmit
    [txSig,txInfo] = transmit(biTx,proppaths,t);

    % Receive
    [thisIQ,rxInfo] = receive(biRx,txSig,txInfo,proppaths);
        % Add I/Q to data vector
    numSamples = size(thisIQ,1);
    startIdx = endIdx + 1;
    endIdx = startIdx + numSamples - 1;
    y(startIdx:endIdx,:) = thisIQ;

        % Advance scene
    advance(scene);
    t = scene.SimulationTime;
    time = toc;
    num_time_steps_rem = num_time_steps_rem -1;
    fprintf("Time Steps Remaining: %i \nEstimated Time Remaining: %g\n",  num_time_steps_rem, time*num_time_steps_rem);
end

% Visualize raw received signal
timeVec = (0:(size(y,1) - 1))*1/fs;
figure()
plot(timeVec,mag2db(abs(sum(y,2))))
grid on
axis tight
xlabel('Time (sec)')
ylabel('Magnitude (dB)')
title('Raw Received Signal')
figure(4)
matched = xcorr(sum(y,2), data);
plot(abs(matched))



