%% Signal Analyzer

m = matfile('ref_datacube.mat');
m_size = size(m, 'data');
rows = m_size(1);
col = m_size(2);
ref_output_array = zeros(1, col);
numSamples = col;
bw = 240e6;
fs = 2*bw;
c = physconst('LightSpeed');
data = m.data';
m_size = size(m, 'data');
rows = m_size(1);
col = m_size(2);
% imagesc(real(data));title('SAR Raw Data')
% xlabel('Cross-Range Samples')
% ylabel('Range Samples')

m = matfile('sig_datacube.mat');
ref = m.data';

range_compressed = zeros(2*col-1, rows);

for idx = 1:rows
    comp = xcorr(data(:,idx), ref(:, idx));
    %figure();
    %plot(abs(comp));
    range_compressed(:,idx) = comp;
end
figure();
imagesc(mag2db(abs(range_compressed)));title('SAR Raw Data')
xlabel('Cross-Range Samples')
ylabel('Range Samples')


% for idx = 1:rows/10
%     chunk = m.data(10*(idx-1)+1:idx*10, :);   % still complex, no extra steps needed
%     chunk_sum = sum(chunk, 1);
%     ref_output_array = ref_output_array + chunk_sum;
% end
% 
% m = matfile('sig_datacube.mat');
% m_size = size(m, 'data');
% rows = m_size(1);
% col = m_size(2);
% sig_output_array = zeros(1, col);
% 
% for idx = 1:rows/10
%     chunk = m.data(10*(idx-1)+1:idx*10, :);   % still complex, no extra steps needed
%     chunk_sum = sum(chunk, 1);
%     sig_output_array = sig_output_array + chunk_sum;
% end

% %Plot
% sig_final = sig_output_array;
% sig_direct = ref_output_array;
% figure(1); clf;
% t_axis = (0:numSamples-1)/fs * 1e3;
% subplot(4,1,1)
% plot(t_axis, abs(sig_final))
% title('Target Return (after receiver)')
% xlabel('Time (ms)'); ylabel('Amplitude'); grid on;
% 
% subplot(4,1,2)
% plot(t_axis, abs(sig_direct))
% title('Direct Path Reference')
% xlabel('Time (ms)'); ylabel('Amplitude'); grid on;
% 
% subplot(4,1,3)
% corr_ref = xcorr(sig_final, sig_direct);
% 
% range_ax = ((0:length(corr_ref)-1) - floor(length(corr_ref)/2)) * c/fs;
% plot(range_ax, mag2db(abs(corr_ref)));
% title('Cross Correlation (Range Profile)')
% xlabel('Differential Range (m)'); ylabel('Magnitude (dB)'); grid on;
% xlim([-1000 1000])
% [val, idx] = max(abs(corr_ref))
% range_ax(idx)
% 
% subplot(4,1,4)
% [corr_sig, lags] = xcorr(sig_final, SSS_sequence);
% ref_sig = xcorr(sig_direct, SSS_sequence);
% range_ax = lags * c/fs;
% corr_sig = max(mag2db(abs(corr_sig)), -60);
% ref_sig = max(mag2db(abs(ref_sig)), -60);
% plot(range_ax, corr_sig, range_ax, ref_sig);
% title('Cross Correlation (Range Profile)')
% xlabel('Differential Range (m)'); ylabel('Magnitude (dB)'); 
% grid on;
% 
% 
% fft_sig = fft(sig_final);
% 
