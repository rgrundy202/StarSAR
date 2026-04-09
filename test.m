clear all;
T_f = 1/750;
starlink_signal_gen('faust.txt', 'output.data')
data = decode_starlink_signal('output.data');

intensity = data;
t = 3*T_f;


frame = 1;

%matched = xcorr(intensity);
matched = xcorr(intensity,data((length(data)/302)*(frame-1)+1:2*(length(data)/302)*(frame)));
% data((length(data)/302)*(frame-1)+1:(length(data)/302)*(frame))


len = length(matched);
time = linspace(-t/2, t/2, len);
figure(1)
plot(time, abs(matched))

figure(2)
fftd = fft(data);
fftd = fftshift(fftd);
len = length(fftd);
freqs = linspace(-1/t, 1/t, len);
plot(freqs, fftd)


[afmag,delay,doppler] = ambgfun(data((length(data)/302)*(frame-1)+1:(length(data)/302)*(frame)),  750/302*length(data), 750);
%contour(delay,doppler,afmag)
figure(3)
size(doppler)
size(delay)
size(afmag)
delay = downsample(delay, 3);
doppler = downsample(doppler, 3);
afmag = downsample(downsample(afmag, 3).',3).';

size(doppler)
size(delay)
size(afmag)

h = surf(delay,doppler,afmag);
set(h,'LineStyle','none')
colorbar



