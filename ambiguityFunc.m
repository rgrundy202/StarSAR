delete downlink_wav.mat;
over = 4;
[pss, sss, head, len] = starlink_signal_gen("faust.txt", over);
load('downlink_wav.mat');

len = len/3;
data1 = data(len:2*len-1);
t = linspace(0, 1/750, len);
figure;
plot(t, abs(data1))
xlabel("Time (s)")
ylabel("Intensity (a.u.)")

fs = 240e6*over;
x = data1;
N_fft = 2^(nextpow2(length(x)));  % zero-pad for smoother plot
X = fftshift(fft(x, N_fft));
f = linspace(-fs/2, fs/2, N_fft) / 1e6;

figure;
plot(f, 20*log10(abs(X) / max(abs(X))));
xlabel('Frequency (MHz)');
ylabel('Normalized Power (dB)');
title('Spectrum');
ylim([-80 5]);
grid on;
xline(-120, 'r--', '-120 MHz');
xline(120, 'r--', '+120 MHz');

figure;
caf_in = [pss, sss.'];
corr = xcorr(data1);
t = linspace(-1/(750), 1/(750), length(corr));
t = t*3e8;


%corr = mag2db(abs(corr));
corr = abs(corr);
corr = corr/max(corr);
corr = mag2db(abs(corr));
plot(t, corr)
xlim([-3000, 3000])
xlabel("Distance");
ylabel("Intensity (dB)");


figure;
caf_in = [pss, sss.'];
[caf, delay, doppler] = ambgfun(sss, fs, 750*303);
surf(delay, doppler, caf);


