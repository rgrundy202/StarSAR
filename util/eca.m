function x_s_clean = eca(x_s, x_r, num_taps)
    % Extensive Cancellation Algorithm
    % Builds a filter from the reference signal to cancel 
    % direct path in surveillance channel
    
    % Build the reference matrix (Toeplitz-like, num_taps columns)
    N = length(x_r);
    X_r = zeros(N, num_taps);
    for k = 1:num_taps
        X_r(k:end, k) = x_r(1:N-k+1);
    end
    
    % Least squares filter coefficients
    w = (X_r' * X_r) \ (X_r' * x_s.');
    
    % Subtract filtered reference from surveillance
    x_s_clean = x_s.' - X_r * w;
    x_s_clean = x_s_clean.';
end