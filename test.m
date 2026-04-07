T_f = 1/750;
starlink_signal_gen('faust.txt', 'output.data')
data = decode_starlink_signal('output.data');

intensity = abs(data);
t = 3*T_f;




matched = xcorr(intensity);


len = length(matched);
time = linspace(-t, t, len);
figure(1)
plot(time, matched)

figure(2)
fftd = fft(data);
fftd = fftshift(fftd);
len = length(fftd)
freqs = linspace(-1/t, 1/t, len);
plot(freqs, abs(fftd))



