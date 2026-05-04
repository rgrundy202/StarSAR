delete downlink_wav.mat;
over = 1;
[pss, sss, head, len] = starlink_signal_gen("faust.txt", over);
load('downlink_wav.mat');
len = length(data)/3;
data1 = data(1:len);
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
corr = xcorr(data1);
t = linspace(-1/750, 1/750, 2*len-1);
t = t*3e8;

%corr = mag2db(abs(corr));
corr = abs(corr);
corr = corr/max(corr);
corr = mag2db(abs(corr));
plot(t, corr)
xlim([-6000, 6000])
xlabel("Distance");
ylabel("Intensity (dB)");

