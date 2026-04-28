% Enhance Cancellation Algorithm by Carrier (ECA-C)
function Xmit = eca_c(X, Xref)
    X_freq = fft(X,[],1);
    X_freq_ref = fft(Xref,[],1);

    % Interference mitigation in slow-time
    Xmit_freq = zeros(numSample,numEleRx,numPulse);
    for idxSubcarrier = 1:numSample
        % Reference signal over slow-time
        xref_slow = reshape(X_freq_ref(idxSubcarrier,1,:),[numPulse,1]);

        % Projection matrix
        projectMatrix = xref_slow/(xref_slow'*xref_slow)*xref_slow';

        for idxRx = 1:numEleRx
            % Signal in slow-time
            x_slow = reshape(X_freq(idxSubcarrier,idxRx,:),[numPulse,1]);

            % Cancel interference 
            Xmit_freq(idxSubcarrier,idxRx,:) = x_slow - projectMatrix*x_slow;
        end
    end

    % Convert signal back to time-domain
    Xmit = ifft(Xmit_freq);
end