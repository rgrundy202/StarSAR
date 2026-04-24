

kB          = 1.38e-23;
Tn          = 290;
f_c         = 10.7e9;
c           = 3*10^8;
lambda      = c/f_c;

bw          = 240e6;

f_s         = 2*bw;

NF_lin      = 10^(1.4/10);

L_lin       = 10^(6.0/10);

Arx         = 1;

R_orbit     = 500e3;

R_target    = 200;

rcs_m2      = 0:2:100;

EIRP        = 50;

pri         = 1/750;

prf         = 750;

speed       = 7.62e3;



% Total noise power over full bandwidth
Pn_total    = kB * Tn * bw * NF_lin * L_lin;

Grx_dB  = 17;                        % your gain in dB
Grx_lin = db2pow(Grx_dB);

% Sig reference
sig_ref = db2pow(EIRP) * (lambda^2/(4*pi)) / (4*pi*R_orbit^2) * Grx_lin;

snr_ref = 10*log10(sig_ref/Pn_total);

sig_target = sig_ref * rcs_m2./( 4 * pi * R_target.^2);

snr_target =  10*log10(sig_target/Pn_total);


N_sync      = round(f_s / (prf * 302));
MF_gain_dB  = 10*log10(N_sync);
fprintf('Range processing gain: %.1f dB\n', MF_gain_dB);

beam_angle = (2.5/360)*2*pi;
beamwid = 2*tan(beam_angle) * R_orbit;

% Synthetic aperture length
beamdwell   = beamwid / (speed);   % time target is in beam (s)
N_az         = round(prf * beamdwell);       % number of pulses in aperture
az_gain_dB   = 10*log10(N_az);
fprintf('Azimuth processing gain: %.1f dB\n', az_gain_dB);

total_gain_dB = MF_gain_dB + az_gain_dB;
fprintf('Total SAR processing gain: %.1f dB\n', total_gain_dB);

figure(1)
plot(rcs_m2, snr_target);



figure(2)
SNR_postprocs = snr_target + total_gain_dB;
semilogx(rcs_m2, SNR_postprocs);

%calculate required rcs at 1.2 km





