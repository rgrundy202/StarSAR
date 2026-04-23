clear
addpath(fullfile(fileparts(mfilename('fullpath')), 'util'));

% RF parameters
fc = 10.7e9;                                    % Carrier frequency (Hz)
c = physconst('LightSpeed');                    % Speed of propagation (m/s)
bw = 240e6;                                     % Bandwidth (Hz)
fs = bw;                                        % Sample rate (Hz)
lambda = freq2wavelen(fc);                      % Wavelength (m)

% Satellite Parameters
height = 340e3;                                 % Satellite Height
earth_radius = 6.371e6;                         % Earth Radius
velocity = 28e6/3600;                           % Satellite Velocity (s)
sat_omega = 4*pi^2*(height+earth_radius)/velocity;
inclination = pi/2;
init_time = 0; 




%% Configure transmitter
% Using Beam Tx1 from FCC filing  

EIRP = 45.1103;                                 % Effective Isotropic Radiated Power (dBW)
Gtx = 34;                                       % Tx peak antenna gain (dB)
Pt = 10^((EIRP-Gtx)/10);
transmitter = phased.Transmitter('Gain',Gtx,'PeakPower',Pt);
element = phased.ShortDipoleAntennaElement(AxisDirection = 'Z');
radiator = phased.Radiator('Sensor',element,'OperatingFrequency',fc,'Polarization','Combined');

% Configure a uniform rectangular array for surveillance receiver
sizeArray = [6 6]; 
rxarray = phased.URA('Element',element,'Size',sizeArray,'ElementSpacing',[lambda/2,lambda/2]);
numEleRx = getNumElements(rxarray);

% Configure surveillance receiver
Grx = 40;                                       % Rx antenna gain (dB) 
NF = 2.9;                                       % Noise figure (dB) 
collector = phased.Collector('Sensor',rxarray,'OperatingFrequency',fc,'Polarization','Combined');
receiver = phased.Receiver('AddInputNoise',true,'Gain',Grx, ...
         'NoiseFigure',NF,'SampleRate',fs);


% Configure a crossed-dipole antenna
antenna_ref = phased.CrossedDipoleAntennaElement;


% Configure a conformal array for the reference receiver
element_ref = phased.ConformalArray;
element_ref.Element = antenna_ref;

% Configure reference receiver
collector_ref = phased.Collector('Sensor',element_ref,'OperatingFrequency',fc,'Polarization','Combined');
receiver_ref = clone(receiver);

%% Platforms
% Transmitter platform
% Construct struct representing satellite
sat_struct = struct();
sat_struct.abs_velocity  = velocity;
sat_struct.height = height;    
sat_struct.inclination = inclination;
sat_struct.pos = [0,0,0];
sat_struct.vel = [0,0,0];

% Get initial position
sat_struct = getPos(sat_struct, init_time);
txpos = sat_struct.pos;                         % Transmitter position (m)

txvel = sat_struct.vel;                         % Transmitter velocity (m/s)
txplatform = phased.Platform('InitialPosition',txpos,'Velocity',txvel,...
    'OrientationAxesOutputPort',true,'OrientationAxes',azelaxes(0,0)); 

% Passive radar platform
earth_rad = 6378e3;                             % Earth radius (m)
rxpos = [earth_rad; 0; 0];                         % Radar positions (m)
rxvel = zeros(3,1);                             % Radar velocities (m/s)
radarplatform = phased.Platform('InitialPosition',rxpos,'Velocity',rxvel,...
    'OrientationAxesOutputPort',true,'OrientationAxes',azelaxes(0,0));

% Target platform
tgtpos = [earth_rad; 400; 10];                         % Target position (m)
tgtvel = [0; 0; 0];                        % Target velocity (m/s)
tgtplatform = phased.Platform('InitialPosition',tgtpos,'Velocity',tgtvel,...
    'OrientationAxesOutputPort',true,'OrientationAxes',azelaxes(0,0)); 

helperCreateBistaticScenario(txpos,rxpos,tgtpos);
[tgtTruth] = helperBistaticGroundTruth(...
    lambda,txpos,txvel,rxpos,rxvel,tgtpos,tgtvel);

% One-way free-space propagation channel from the transmitter to passive radar receiver
basechannel = phased.FreeSpace(PropagationSpeed=c,OperatingFrequency=fc, ...
    SampleRate=fs,TwoWayPropagation=false);

% One-way free-space propagation channel from the transmitter to the target
txchannel = clone(basechannel);

% One-way free-space propagation channel from the target to passive radar receiver
rxchannel = clone(basechannel);

% Create a target
smat = 2*eye(2);
target = phased.RadarTarget('PropagationSpeed',c, ...
    'OperatingFrequency',fc,'EnablePolarization',true,...
        'Mode','Bistatic','ScatteringMatrix',smat);

sig = decode_starlink_signal('output.data');
pri = 1/750;                                  % Pulse repetition interval (s)
numPulse = 3;                                  % Number of pulses


% Transmitted signal
txsig = transmitter(sig);

numSample = size(sig, 1);  
% Radar data cube obtained at reference receiver
Xref = complex(zeros([numSample,1,numPulse])); 

% Radar data cube obtained at surveillance receiver
X = complex(zeros([numSample,numEleRx,numPulse]));

% Transmitted signal
txsig = transmitter(sig);

for idxPulse = 1:numPulse

    time = init_time+(idxPulse-1)*pri;
    
    % Update transmitter position
    sat_struct = getPos(sat_struct, time);
    txpos = sat_struct.pos;                         % Transmitter position (m)
    txvel = sat_struct.vel;                         % Transmitter velocity (m/s)
    txplatform = phased.Platform('InitialPosition',txpos,'Velocity',txvel,...
    'OrientationAxesOutputPort',true,'OrientationAxes',azelaxes(0,0)); 


    % Update separate transmitter, radar and target positions
    [tx_pos,tx_vel,tx_ax] = txplatform(pri);
    [radar_pos,radar_vel,radar_ax] = radarplatform(pri);

    % Calculate the transmit angle as seen by the transmitter
    [~,txang_base] = rangeangle(radar_pos,tx_pos,tx_ax);

    % Radiate signal towards the radar receiver
    radtxsig_base = radiator(txsig(:,idxPulse),txang_base,tx_ax);

    % Collect signal at different radar receivers
    % Propagate the signal from the transmitter to each radar
    rxchansig_base = basechannel(radtxsig_base,tx_pos,radar_pos, ...
        tx_vel,radar_vel);

    % Calculate the receive angle
    [~,rxang_base] = rangeangle(tx_pos,radar_pos,radar_ax);

    % Collect signal at the reference receive antenna
    rxsig_ref = collector_ref(rxchansig_base,rxang_base,radar_ax);

    % Receive signal at the reference receiver
    Xref(:,:,idxPulse) = receiver_ref(rxsig_ref);

    % Collect direct-path interference signal at the surveillance
    % receive array
    rxsig_int = collector(rxchansig_base,rxang_base,radar_ax);

    % Receive direct-path interference signal at the surveillance receiver
    X(:,:,idxPulse) = receiver(rxsig_int);
    reset(txplatform)
    reset(radarplatform)
end


for idxPulse = 1:numPulse
    % Update transmitter, radar and target positions
    [tx_pos,tx_vel,tx_ax] = txplatform(pri);
    [radar_pos,radar_vel,radar_ax] = radarplatform(pri);
    [tgt_pos,tgt_vel,tgt_ax] = tgtplatform(pri);

    % Calculate the transmit angle for tx-to-target path
    [~,txang] = rangeangle(tgt_pos,tx_pos,tx_ax);

    % Radiate signal towards the target
    radtxsig = radiator(txsig(:,idxPulse),txang,tx_ax);

    % Propagate the signal from the transmitter to the target
    txchansig = txchannel(radtxsig,tx_pos,tgt_pos, ...
        tx_vel,tgt_vel);

    % Reflect the signal off the target
    [~,fwang] = rangeangle(tx_pos,tgt_pos,tgt_ax(:,:,1));
    [~,bckang] = rangeangle(radar_pos,tgt_pos,tgt_ax(:,:,1));
    tgtsig = target(txchansig,fwang,bckang,tgt_ax(:,:,1));


    % Propagate the signal from the target to each radar
    rxchansig = rxchannel(tgtsig,tgt_pos,radar_pos, ...
        tgt_vel,radar_vel);

    % Calculate the receive angle
    [~,rxang] = rangeangle(tgt_pos,radar_pos,radar_ax);

    % Collect signal at the receive antenna
    rxsig = collector(rxchansig,rxang,radar_ax);

    % Receive signal at the receiver
    X(:,:,idxPulse) = X(:,:,idxPulse) + receiver(rxsig);
end


% Convert time-domain signal in frequency domain
X_freq = fft(X,[],1);
X_freq_ref = fft(Xref,[],1);

% Interference mitigation in slow-time
Xmit_freq = zeros(numSample,numEleRx,numPulse);
for idxSubcarrier = 1:numSample
    % Reference signal over slow-time
    xref_slow = reshape(X_freq_ref(idxSubcarrier,1,:),[numPulse,1]);

    % Projection matrix
    projectMatrix = xref_slow/(xref_slow'*xref_slow)*xref_slow';

    for idxRx = 1:numEleRx
        % Signal in slow-time
        x_slow = reshape(X_freq(idxSubcarrier,idxRx,:),[numPulse,1]);

        % Cancel interference 
        Xmit_freq(idxSubcarrier,idxRx,:) = x_slow - projectMatrix*x_slow;
    end
end

% Convert signal back to time-domain
Xmit = ifft(Xmit_freq);

% Plot fast-time signal power
pulseIdxPlot = 1;
helperCompareFastTimePower(X,Xmit,pulseIdxPlot)

% TDOA estimator
numSig = 1;
tdoaestimator = phased.TDOAEstimator(NumEstimates=numSig,...
      SampleRate=fs,TDOAResponseOutputPort=true);

% Estimate bistatic range
for idxPulse = numPulse:-1:1
    % Bistatic data where last dimension has the reference channel and a
    % survelliance channel
    Xtdoa = zeros(numSample,numEleRx,2); 
    for rxEleIdx = 1:numEleRx
        % Obtain reference channel signal
        Xtdoa(:,rxEleIdx,1) = Xref(:,1,idxPulse);

        % Obtain survelliance channel signal
        Xtdoa(:,rxEleIdx,2) = Xmit(:,rxEleIdx,idxPulse);
    end

    % Estimate TDOA, get TDOA response and TDOA grid
    [tdoaest,tdoaresp,tdoagrid] = tdoaestimator(Xtdoa);
    tdoaResp(:,:,idxPulse) = tdoaresp;
end

% Convert TDOA to bistatic range
rngest = tdoaest*c;
rnggrid = tdoagrid*c;

% Estimated range indices
rngIndices = zeros(1,numSig);
for estIdx = 1:numSig
    [~,rngIdx] = min(abs(rngest(estIdx)-rnggrid));
    rngIndices(estIdx) = rngIdx;
end

% Plot bistatic range spectrum
helperPlotBistaticRangeSpectrum(tdoaResp,rnggrid,rngIndices,numSig,pulseIdxPlot)

