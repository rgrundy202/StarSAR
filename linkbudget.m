kB          = 1.38e-23;
Tn          = 300;
numPulses = 750;
f_c = 10.7e9;
prf = 1/750;
c = 3*10^8;
lambda = f_c/c;
bw          = 250e6;
NF_lin      = 10^(1.4/10);
L_lin       = 10^(6.0/10);
Arx         = 1;
R_orbit     = 1110e3;
rcs_m2      = 10;
PFD_dBWm2Hz = -182.02;
PFD_lin     = 10^(PFD_dBWm2Hz/10);         % W/m²/Hz

% Total noise power over full bandwidth
Pn_total    = kB * Tn * bw * NF_lin * L_lin;

% Reference SNR (direct signal, no integration)
SNR_ref     = (PFD_lin * bw * Arx) / Pn_total;
fprintf('Reference SNR:     %.1f dB\n', 10*log10(SNR_ref));
% Target: ~20 dB

% Echo SNR with coherent integration
T_int       = numPulses / prf;
Rrx         = 200;

SNR_echo    = (PFD_lin * rcs_m2 * Arx * T_int) / ...
              ((4*pi) * Rrx^2 * kB * Tn * NF_lin * L_lin);
fprintf('Echo SNR @200m:    %.1f dB\n', 10*log10(SNR_echo));

% Range sweep
Rrx_vec     = logspace(1, 5, 1000);
SNR_free    = zeros(size(Rrx_vec));
SNR_tworay  = zeros(size(Rrx_vec));

for k = 1:length(Rrx_vec)
    R = Rrx_vec(k);
    SNR_free(k)   = 10*log10(...
        (PFD_lin * rcs_m2 * Arx * T_int) / ...
        ((4*pi) * R^2 * kB * Tn * NF_lin * L_lin));
    
    SNR_tworay(k) = 10*log10(...
        (PFD_lin * rcs_m2 * Arx^2 * (4*pi) * T_int) / ...
        (lambda^2 * R^4 * kB * Tn * NF_lin * L_lin));
end

% Detection ranges
idx_free   = find(SNR_free   > 12, 1, 'last');
idx_tworay = find(SNR_tworay > 12, 1, 'last');
fprintf('Max range (air):   %.1f km\n', Rrx_vec(idx_free)/1e3);
fprintf('Max range (gnd):   %.1f km\n', Rrx_vec(idx_tworay)/1e3);
% Paper: ~10km air, ~4km ground


% Print every term individually
signal_W    = PFD_lin * bw * Arx;
noise_W     = kB * Tn * bw * NF_lin * L_lin;

fprintf('=== Term by Term ===\n');
fprintf('PFD:           %.2f dBW/m²/Hz\n', 10*log10(PFD_lin));
fprintf('BW:            %.1f dB\n',          10*log10(bw));
fprintf('Arx:           %.1f dB\n',          10*log10(Arx));
fprintf('Signal power:  %.1f dBW\n',         10*log10(signal_W));
fprintf('kB:            %.1f dBW/Hz/K\n',    10*log10(kB));
fprintf('Tn:            %.1f dBK\n',          10*log10(Tn));
fprintf('NF:            %.1f dB\n',           10*log10(NF_lin));
fprintf('L:             %.1f dB\n',           10*log10(L_lin));
fprintf('Noise power:   %.1f dBW\n',         10*log10(noise_W));
fprintf('SNR:           %.1f dB\n',          10*log10(signal_W/noise_W));