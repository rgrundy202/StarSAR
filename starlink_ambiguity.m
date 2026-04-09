function ambiguity = starlink_ambiguity(filename, Fs, max_delay, max_doppler)
    % Load signal
    input_file = fopen(filename, 'r');
    raw = fread(input_file, [2, Inf], 'double');
    fclose(input_file);
    s = raw(1,:) + 1j * raw(2,:);
    
    % Trim to one frame to keep computation manageable
    frame_len = round(Fs / 750); % samples per frame at given Fs
    s = s(1:frame_len);
    
    % Define delay and Doppler axes
    max_delay_samp = round(max_delay * Fs);
    delays   = -max_delay_samp : max_delay_samp;
    dopplers = linspace(-max_doppler, max_doppler, 512);
    
    ambiguity = zeros(length(dopplers), length(delays));
    
    t = (0:length(s)-1) / Fs;
    
    for d_idx = 1:length(dopplers)
        nu = dopplers(d_idx);
        
        % Apply Doppler shift to signal
        s_shifted = s .* exp(1j * 2 * pi * nu * t);
        
        % Correlate across all delays using xcorr
        [corr, lags] = xcorr(s, s_shifted, max_delay_samp);
        ambiguity(d_idx, :) = abs(corr);
        
        if mod(d_idx, 50) == 0
            fprintf('Doppler bin %d of %d\n', d_idx, length(dopplers));
        end
    end
    
    % Normalize
    ambiguity = ambiguity / max(ambiguity(:));
    
    % Plot
    figure;
    surf(delays/Fs * 1e6, dopplers/1e3, 20*log10(ambiguity));
    colorbar;
    clim([-40 0]);
    xlabel('Delay (\mus)');
    ylabel('Doppler (kHz)');
    title('Starlink Signal Ambiguity Function');
    colormap jet;
end