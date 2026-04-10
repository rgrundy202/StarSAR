clear all;
T_f = 1/750;
starlink_signal_gen('faust.txt', 'output.data')
data = decode_starlink_signal('output.data');
snr = 100;

figure(4)


intensity = data;
t = 3*T_f;
time = linspace(0, t, length(data));
plot(time, data)



frame = 1;

matched = xcorr(intensity);
%matched = xcorr(intensity,data((length(data)/302)*(frame-1)+1:(length(data)/302)*(frame)));
% data((length(data)/302)*(frame-1)+1:(length(data)/302)*(frame))


len = length(matched);
time = linspace(-t/2, t/2, len);
figure(1)
norm_matched = matched/max(matched);
%match=matched(len/2+1:len-20000);
plot(time, abs(norm_matched))

figure(2)
fftd = fft(data);
fftd = fftshift(fftd);
len = length(fftd);
freqs = linspace(-1/t, 1/t, len);
fftd = fftd/max(fftd);
plot(freqs, abs(fftd))


% [afmag,delay,doppler] = ambgfun(data((length(data)/302)*(frame-1)+1:(length(data)/302)*(frame)),  750/302*length(data), 750);
% %contour(delay,doppler,afmag)
% figure(3)
% size(doppler)
% size(delay)
% size(afmag)
% delay = downsample(delay, 3);
% doppler = downsample(doppler, 3);
% afmag = downsample(downsample(afmag, 3).',3).';
% 
% size(doppler)
% size(delay)
% size(afmag)
% 
% h = surf(delay,doppler,afmag);
% set(h,'LineStyle','none')
% colorbar



