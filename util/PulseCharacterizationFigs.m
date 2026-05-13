clear;
close all;
addpath(fullfile(fileparts(mfilename('fullpath')), 'util'));
T_f = 1/750;
T_sym = T_f/303;
starlink_signal_gen("faust.txt", "output.data", 4);
% Step 1 — decode raw bytes to complex IQ
data = decode_starlink_signal('output.data');
sim_rate = length(data)*750/3;
% Step 2 — resample from known generation rate to simulation rate
fs_gen = 240e6;   % whatever starlink_signal_gen uses
fs_sim = 256e6;               % your simulation rate
[P, Q] = rat(fs_sim / sim_rate);
data = resample(data, P, Q);



% Step 4 — verify spectrum looks clean
figure();
plot_fft(data, fs_sim);
title('Resampled Starlink signal at simulation fs');

first_frame = data(1:T_f*fs_sim);



figure(1)
time = linspace(0,3*T_f, length(data));
plot(time, abs(data))
title("Time Series Plot of the Entire Three Frame Transmission")
xlabel("Time (s)")
ylabel("Normalized Intensity (a.u.)")


% figure(2);
% cor = xcorr(pss);
% cor = cor/max(cor);
% time = linspace(-T_sym,T_sym, length(cor));
% semilogy(time, abs(cor))
% title("Autocorrelation of PSS")
% xlabel("Delay time (s)")
% ylabel("Normalized Intensity (a.u.)")
% drawnow;

figure(3)
fftd = fft(first_frame);
fftd = fftshift(fftd);
freqs = linspace(-fs_sim/2, fs_sim/2, length(fftd));
fftd = fftd/max(abs(fftd));
plot(freqs, mag2db(abs(fftd)));
title("Frequency Spectrum for One Frame")
xlabel("Frequency (Hz)")
ylabel("Spectral Intensity (dB)")


figure(4);
cor = xcorr(sss, sss);
cor = cor/max(cor);
time = linspace(-T_sym,T_sym, length(cor));
semilogy(time, abs(cor))
title("Autocorrelation of SSS")
xlabel("Delay time (s)")
ylabel("Normalized Intensity (a.u.)")
drawnow;


figure(5)
fftd = fft(sss);
fftd = fftshift(fftd);
freqs = linspace(-f_s/2, f_s/2, length(fftd));
plot(freqs, abs(fftd));
title("Frequency Spectrum for SSS Sequence")
xlabel("Frequency (Hz)")
ylabel("")

figure(6)
cor = xcorr(first_frame, first_frame);
cor = cor/max(cor);
cor = max(mag2db(abs(cor)), -60);
time = linspace(-T_f,T_f, length(cor));
plot(time, cor);
title("Autocorrelation of One Frame")
xlabel("Delay time (s)")
ylabel("Normalized Intensity (dB)")

figure(7)
% Compute the matched filter output
matchedOutput = xcorr(head, head);
matchedOutput = matchedOutput / max(matchedOutput); % Normalize matched output
time = linspace(-T_sym,T_sym, length(matchedOutput));
semilogy(time, abs(matchedOutput));
title("Autocorrelation of the Three Symbol Header")
xlabel("Delay time (s)")
ylabel("Normalized Intensity (a.u.)")


figure(8)
corr = xcorr(data, first_frame);
time = linspace(-3*T_sym,3*T_sym, length(corr));
corr = corr/max(corr);
semilogy(time, abs(corr))
title("Cross Correlation of Three Frame Transmission with One Frame")
xlabel("Delay Time (s)")
ylabel("Normalized Intensity (a.u.)")



