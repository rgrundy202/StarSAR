% Written with help from Claude and Copilot
classdef StarLinkWaveform < phased.internal.AbstractPulseWaveform
    properties
        IQData
    end
    methods (Access = protected)
    function tf = isCoefficientFixedSize(~)
        % Indicate whether coefficients have fixed column size (logical)
        % Return true if coefficients are fixed-size; adjust if needed.
        tf = true;
    end

    function ncol = getCoefficientColumnSize(obj)
        % Return number of columns for coefficient matrix
        % Default: single-column coefficients
        if isprop(obj,'Coefficients') && ~isempty(obj.Coefficients)
            coeff = obj.Coefficients;
            if ismatrix(coeff)
                ncol = size(coeff,2);
            else
                ncol = 1;
            end
        else
            ncol = 1;
        end
    end

    function coeff = getCoefficients(obj)
        % Return the waveform coefficients (complex pulse shape or samples)
        % If you store waveform samples in Data, return those; otherwise return stored Coefficients.
        if isprop(obj,'Coefficients') && ~isempty(obj.Coefficients)
            coeff = obj.Coefficients;
            return;
        end
        if isprop(obj,'Data') && ~isempty(obj.Data)
            coeff = obj.Data(:); % column vector samples
            return;
        end
        coeff = []; % fallback
    end

    function pw = getPulseWidth(obj)
        % Return pulse width (seconds). If you have PulseWidth property, use it.
        if isprop(obj,'PulseWidth') && ~isempty(obj.PulseWidth)
            pw = obj.PulseWidth;
            return;
        end
        % Estimate from PRF if available: pulse width <= 1/PRF (conservative)
        if isprop(obj,'PRF') && ~isempty(obj.PRF) && obj.PRF > 0
            pw = 1/obj.PRF;
            % If Data and SampleRate exist, refine estimate from nonzero-energy region
            if isprop(obj,'Data') && isprop(obj,'SampleRate') && ~isempty(obj.Data) && ~isempty(obj.SampleRate)
                x = abs(obj.Data(:));
                thr = 0.01*max(x);
                idx = find(x > thr);
                if ~isempty(idx)
                    pw = numel(idx)/obj.SampleRate;
                end
            end
            return;
        end
        pw = 0;
    end

    function w = getMatchingWaveform(obj)
        % Return a waveform object or empty that matches this waveform for matched filtering.
        % Default: return empty (no helper waveform). Override if you can return a System object.
        w = [];
    end

    function name = getWaveformName(~)
        % Return a human-readable name for the waveform
        name = 'StarLinkWaveform';
    end

    function y = stepImpl(obj)
            y = obj.IQData;
        end
    
    end

   
    methods (Access = public)
         function obj = StarLinkWaveform(iq, fs, prf)
            obj.IQData     = iq(:);
            obj.SampleRate = fs;
            obj.PRF        = prf;
         end

         function  pw = PulseWidth(obj)
             pw = 1/obj.PRF;
         end
        
        function bw = bandwidth(obj)
        % Return approximate bandwidth (Hz).
        % If you have an explicit property (e.g., SweepBandwidth), use it instead.
        if isprop(obj,'SweepBandwidth') && ~isempty(obj.SweepBandwidth)
            bw = obj.SweepBandwidth;
            return;
        end
        % Estimate from data: approximate Nyquist-limited content
        if isprop(obj,'SampleRate') && ~isempty(obj.SampleRate) && ~isempty(obj.Data)
            % crude estimate: occupied bandwidth of the waveform
            N = numel(obj.Data);
            bw = obj.SampleRate/2;             % fallback to Nyquist
            try
                % use power spectrum to estimate -3 dB bandwidth
                X = abs(fftshift(fft(double(obj.Data(:)), max(1024,2^nextpow2(N)))));
                f = linspace(-obj.SampleRate/2, obj.SampleRate/2, numel(X));
                Xnorm = X/max(X);
                idx = find(Xnorm >= 0.5);
                if ~isempty(idx)
                    bw = f(idx(end)) - f(idx(1));
                    bw = abs(bw);
                end
            catch
                bw = obj.SampleRate/2;
            end
        else
            bw = 0;
        end
    end
    end
    
end