%% Correct passive SAR range compression
% Load datacubes — each row is one pulse (slow time)
tgt_true = [0, 200, 0];
m_ref = matfile('ref_datacube.mat');
m_sig = matfile('sig_datacube.mat');
m_traj = matfile('traj_data.mat');
tx_trajectory = m_traj.data';

[num_pulses, num_samples] = size(m_ref, 'data');
sub_cpi_len = num_samples;   % one pulse per range profile for now

range_time_matrix = zeros(num_pulses, 2*num_samples - 1);
fs = num_samples * prf;
frame_len  = round(fs * 1/750);   % 4/3 ms frame duration from paper

fprintf('fs in simulation: %.4f MHz\n', fs/1e6);
fprintf('Actual samples per PRI: %d\n', num_samples);
fprintf('Implied fs from samples: %.4f MHz\n', num_samples * prf / 1e6);
fprintf('r_b range across aperture:\n');
r_b_history = zeros(1, num_pulses-1);

for i = 2:num_pulses
    txPos_i = tx_trajectory(:,i);
    R_tx_tgt = norm(tgt_true - txPos_i);
    R_rx_tgt = norm(tgt_true - rxPos);
    R_tx_rx  = norm(rxPos - txPos_i);
    r_b_history(i-1) = R_tx_tgt + R_rx_tgt - R_tx_rx;
end

fprintf('r_b start:  %.4f m\n', r_b_history(1));
fprintf('r_b end:    %.4f m\n', r_b_history(end));
fprintf('r_b change: %.4f m\n', r_b_history(end) - r_b_history(1));
fprintf('Phase change: %.2f rad\n', 2*pi*(r_b_history(end)-r_b_history(1))/lambda);

for i = 2:num_pulses  % start at 2 to skip FreeSpace transient
    x_r = m_ref.data(i, :);
    x_s = m_sig.data(i, :);
    
    % Simple cross-correlation range compression — no sub-framing needed
    x_s_clean = eca(x_s, x_r, 20);  % 20 taps, tune this
    
    % Range compression on cleaned signal
    range_time_matrix(i-1, :) = xcorr(x_s_clean, x_r);
end
x_vec = -250:1:250;   % east-west, metres, 1m spacing
y_vec = 0:1:400;      % north-south, metres, 1m spacing
[X, Y] = meshgrid(x_vec, y_vec);
Z = zeros(size(X));   % flat earth assumption


%% Precompute pixel positions (do this once outside the loop)
rxPos = [0; 0; 0];
tgt_x = X(:)';   % 1 x num_pixels
tgt_y = Y(:)';
tgt_z = Z(:)';

sar_image = zeros(numel(X), 1, 'like', 1+1j);
fprintf('Data length: %d samples\n', length(data));
fprintf('Required:    %d samples\n', samples_per_pulse * pulse_num);
fprintf('Sufficient:  %d\n', length(data) >= samples_per_pulse * pulse_num);

%% Back Projection
for i = 2:num_pulses
    txPos_i = tx_trajectory(:, i);  % [x;y;z]
    range_profile = range_time_matrix(i-1, :);
    
    % Vectorised bistatic range for ALL pixels simultaneously
    R_tx_tgt = sqrt((tgt_x - txPos_i(1)).^2 + ...
                    (tgt_y - txPos_i(2)).^2 + ...
                    (tgt_z - txPos_i(3)).^2);  % 1 x num_pixels
                    
    R_rx_tgt = sqrt(tgt_x.^2 + tgt_y.^2 + tgt_z.^2);  % static RX at origin
    
    R_tx_rx  = norm(rxPos - txPos_i);  % scalar
    
    r_b = R_tx_tgt + R_rx_tgt - R_tx_rx;  % 1 x num_pixels
    
    % Convert to sample indices
    sample_idx = r_b * fs/c + num_samples;
    
    % Mask invalid indices
    valid = sample_idx >= 1 & sample_idx <= length(range_profile);
    
    % Interpolate range profile at all valid pixel indices at once
    vals = zeros(1, numel(X));
    vals(valid) = interp1(1:length(range_profile), ...
                          range_profile, ...
                          sample_idx(valid));
    
    % Back projection phase and coherent accumulation
    phi = 2*pi * r_b / lambda;
    sar_image = sar_image + (vals .* exp(1j * phi)).';
end

%% Reshape back to image grid
sar_image = reshape(sar_image, size(X));

%% Plot SAR Image
figure();
imagesc(x_vec, y_vec, mag2db(abs(sar_image)));
xlabel('East-West (m)');
ylabel('North-South (m)');
title('Passive SAR Image');
colorbar;
clim([max(mag2db(abs(sar_image(:)))) - 40, ...
      max(mag2db(abs(sar_image(:))))]);
axis xy;
fprintf('SAR image stats:\n');
fprintf('  Max value:  %.2f dB\n', max(mag2db(abs(sar_image(:)))));
fprintf('  Mean value: %.2f dB\n', mean(mag2db(abs(sar_image(:)))));
fprintf('  Min value:  %.2f dB\n', min(mag2db(abs(sar_image(:)))));
fprintf('  Non-zero pixels: %d / %d\n', ...
    sum(sar_image(:) ~= 0), numel(sar_image));
fprintf('  TX displacement over aperture: %.1f m\n', ...
    norm(tx_trajectory(:,end) - tx_trajectory(:,1)));

%% Phase history at true target location
tgt_true = [0; 200; 0];
phase_history = zeros(1, num_pulses-1);
amp_history   = zeros(1, num_pulses-1);

for i = 2:num_pulses
    txPos_i = tx_trajectory(:,i);
    
    R_tx_tgt = norm(tgt_true - txPos_i);
    R_rx_tgt = norm(tgt_true - rxPos);
    R_tx_rx  = norm(rxPos - txPos_i);
    r_b      = R_tx_tgt + R_rx_tgt - R_tx_rx;
    
    sample_idx = r_b * fs/c + num_samples;
    val = interp1(1:size(range_time_matrix,2), ...
                  range_time_matrix(i-1,:), sample_idx);
    
    phi = 2*pi * r_b / lambda;
    amp_history(i-1)   = abs(val);
    phase_history(i-1) = angle(val * exp(1j*phi));
end

figure();
subplot(3,1,1)
plot(amp_history)
title('Amplitude at target pixel across pulses')
xlabel('Pulse'); ylabel('Amplitude'); grid on;

subplot(3,1,2)
plot(unwrap(phase_history))
title('Unwrapped phase history at target pixel')
xlabel('Pulse'); ylabel('Phase (rad)'); grid on;

subplot(3,1,3)
plot(diff(unwrap(phase_history)))
title('Phase difference (should be smooth)')
xlabel('Pulse'); ylabel('Delta Phase (rad)'); grid on;

figure();
plot(r_b_history - r_b_history(1));
xlabel('Pulse'); ylabel('Δr_b (m)');
title('Bistatic range variation across aperture');
grid on;

