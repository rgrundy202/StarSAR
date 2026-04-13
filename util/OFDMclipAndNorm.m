function out = OFDMclipAndNorm(ofdm_output)
    % Helper method to solve PAPR issue from OFDM and keep average power
    % comparable between symbols. Clipping may cause distortion but data
    % recovery in this simulation is unimportant and this method produces
    % power levels consistent with Humphrey et al. and Gomez-del-Hoyo et
    % al.

    % Clip
    threshold = sqrt(2) * rms(ofdm_output);
    peaks = abs(ofdm_output) > threshold;
    ofdm_output(peaks) = threshold * exp(1j * angle(ofdm_output(peaks)));

    % Renormalize RMS after clipping
    out = ofdm_output / max(ofdm_output);
end