clear;
close all;
addpath(fullfile(fileparts(mfilename('fullpath')), 'util'));
T_f = 1/750;
T_sym = T_f/303;

[pss, sss, head] = starlink_signal_gen('faust.txt', 'output.data',3);
f_s = length(pss)/T_sym;
data = decode_starlink_signal('output.data');
fprintf("Decoder done. Data length: %d\n", length(data));

first_frame = data(1:length(data)/3);



figure(1)
time = linspace(0,3*T_f, length(data));
plot(time, abs(data))
title("Time Series Plot of the Entire Three Frame Transmission")
xlabel("Time (s)")
ylabel("Normalized Intensity (a.u.)")


figure(2);
cor = xcorr(pss);
cor = cor/max(cor);
time = linspace(-T_sym,T_sym, length(cor));
semilogy(time, abs(cor))
title("Autocorrelation of PSS")
xlabel("Delay time (s)")
ylabel("Normalized Intensity (a.u.)")
drawnow;

figure(3)
fftd = fft(first_frame);
fftd = fftshift(fftd);
freqs = linspace(-f_s/2, f_s/2, length(fftd));
plot(freqs, abs(fftd));
title("Frequency Spectrum for One Frame")
xlabel("Frequency (Hz)")
ylabel("")


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
ylabel("Normalized Intensity (s)")

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

% figure(9)
% [afmag,delay,doppler] = ambgfun(sss, f_s, 750*303);
% afmag = db(afmag);
% afmag= max(afmag, -60);  % clamp to 60dB dynamic range
% contour(delay, doppler, afmag)
% colorbar
% 
% title("Radar Ambiguity for SSS Sequence");
% xlabel("Delay Time (s)");
% ylabel("Doppler Shift (Hz)");
% 
% figure(10)
% delay = downsample(delay, 2);
% doppler = downsample(doppler, 2);
% afmag = downsample(downsample(afmag, 2).',2).';
% 
% h = surf(delay,doppler,afmag);
% set(h,'LineStyle','none')
% colorbar
% 
% title("Radar Ambiguity for SSS Sequence");
% xlabel("Delay Time (s)");
% ylabel("Doppler Shift (Hz)");
% 
% figure(11)
% [response, lags] = xcorr(data, sss);
% time = linspace(-(T_f+T_sym)/2, (T_f+T_sym)/2, length(response));
% response = response/max(abs(response));
% response = mag2db(abs(response));
% response = max(response, -60);  % clamp to 60dB dynamic range
% plot(lags/f_s, response)
% xlim([-T_sym, (T_f+T_sym)/2]);
% title("Matched Filter Response for SSS Sequence and Three Frame Signal")
% xlabel("Time (s)")
% ylabel("Response Intensity (a.u.)")
% 





