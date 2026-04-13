%% StarLink Signal Generation Script
% Taken from research done on Humphrey et al. (2023)

function [PSS, sss_ofdm_output, head_ofdm_output] = starlink_signal_gen(filename, out_filename, oversample)
    
%%%%%%%%%%%%%%%%%% Values Taken From Humphrey %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    N = 1024; 
    N_g = 32;
    T_f = 1/750;
    T_fg = (68/15)*10^(-6);
    N_sf = 302;
    N_sfd = 298;
    T = (64/15)*10^(-6);
    T_g = (2/15)*10^(-6);
    T_sym = 4.4E-6;
    F = 234375;
    F_sigma = 250E6;
    F_g = 10E6;
    gutter_len = 4;
    F_s= 240E6;
    
%%%%%%%%%%%%%%%%%%%%%% Environment Variables %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   
    symbol_length = (N+N_g+gutter_len)*oversample;
    max_hex_4qam = 512;
    max_hex_16qam = 1024;
    max_bytes_per_frame = 1024*(4*8+286*2)/8;
    file_prop = dir(filename);
    n_streams = N; % Number of subcarriers
    nullIdx = (N/2-2:N/2+1).' ;% IDs of null carriers
    cplen = N_g;
    nfft = n_streams+gutter_len; % length for fft. 
    num_frames = ceil(file_prop.bytes/max_bytes_per_frame);
    
    data_file = fopen(filename);
    output_file = fopen(out_filename, 'w');
    fprintf("Generating Signal File For %s.\n%d Frames of Data\n", filename, num_frames)




    
%%%%%%%%%%%%%%%%%%%%%%%% Generate Data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
    
    %% PSS (SDPSK) (i = 0)
    
    N_block = 8; % Number of blocks in symbol
    L = 128; % Length of block
    pss_len = 8 * L;
    PSS_seq = zeros(1, pss_len); % Start signal frame array
    
    % Data in each repeated PSS signal
    q_pss = zeros(1,L);

    q_pss_hex = file_to_array("qpss.hex");
    q_pss_hex = strjoin(q_pss_hex, '');  % collapse cell array to string

    if length(q_pss_hex) ~= 32
        error("Bad PSS Length. Expected: 32 \nGot: %d\n", length(q_pss_hex))
    end

    % q_pss_hex = dec2bin(hex2dec(q_pss_hex));
    % for i = 1:L
    %     q_pss(i)= str2double(q_pss_hex(i));
    % end
    q_pss_bin = '';
    for i = 1:length(q_pss_hex)
        q_pss_bin = [q_pss_bin, dec2bin(hex2dec(q_pss_hex(i)), 4)];
    end
    for i = 1:L
        q_pss(i) = str2double(q_pss_bin(i));
    end

    % Symmetric DPSK (first is inverted so shift by pi)
    rot = pi;

    M = 2; % Modulation order for SDPSK

    % Modulate base PSS signal
    inv_pss_sub = dpskmod(q_pss, M, rot);
    PSS_seq(1:L) = inv_pss_sub;

    % Change rotation for last frames
    rot = 0;
    pss_sub = dpskmod(q_pss, M, rot);
    
    for i = 1:N_block-1
        PSS_seq(i*L+1:(1+i)*L) = pss_sub;
        
    end 
    
    % Save cyclic prefix
    cyclic_pre = q_pss(length(q_pss)- N_g+1:length(q_pss));
    % Change rotation back for inversion
    rot = pi;
    mod_prefix = dpskmod(cyclic_pre, M, rot);

    PSS_seq = [mod_prefix, PSS_seq];
    
    
   
    % Stretch out to match other frames
    PSS = resample(PSS_seq, (symbol_length), length(PSS_seq));
    % Normalize
    PSS = PSS/max(abs(PSS));
    figure(1)
    plot(abs(PSS))
    
    
    

    %% SSS (4QAM) (i = 1) 

    % Read data from file
    sss_fid = fopen('qsss.hex', 'r');
    sss_data = textscan(sss_fid, '%c');
    fclose(sss_fid);

    q_sss = zeros(1, N);
    q_sss_hex = sss_data{1};
    L = length(q_sss_hex);

    if L ~= 512
        error("Bad SSS hex length")
    end
    
    % Translate to binary
    q_sss_hex = dec2bin(hex2dec(q_sss_hex));
    
    % Convert to base 4
    for i = 1:2*L
        q_sss(i)= 2*str2double(q_sss_hex(2*i-1)) + str2double(q_sss_hex(2*i));
    end
    
    M = 4;
    
    nSym = 1; % Number of symbols in frame
    n_streams = N; % Number of subcarriers

    % 4QAM modulation
    qamSig = qammod(q_sss, M);

    % Rotate 90 degrees to line up with observations
    qamSig = qamSig * exp(1j * pi/4);
    
    % Duplicate into all channels
    ofdm_input = qamSig .';
    
    % OFDM encode (output is nfft x oversampling)
    ofdm_output = ofdmmod(ofdm_input, nfft, cplen, nullIdx, OversamplingFactor=oversample);
    if length(ofdm_output) ~= symbol_length
        error("Bad SSS Symbol Length")
    end
    
    sss_ofdm_output = OFDMclipAndNorm(ofdm_output);
    

    %% Header (i = 2-5) 4QAM
    % Sequentially parse data from file into array representing frame data
    head_hex = file_to_array("header.txt");

    L = length(head_hex);
    if L ~= 3*max_hex_4qam
        error('Bad Header Length \nHeader Length: %d. \nExpected: %d', L, 3*max_hex_4qam)
    end
    
    head_symbols = L/max_hex_4qam;

    % Translate to binary
    head_bin = dec2bin(hex2dec(head_hex));
    head = zeros(1, 6*max_hex_4qam);

    % Convert to base 4
    for i = 1:2*L
        head(i)= 2*str2double(head_bin(2*i-1)) + str2double(head_bin(2*i));
    end

    % Reshape for OFDM encoding splitting data up by column
    head = reshape(head, [N, head_symbols]);
    M = 4;

    % 4QAM modulation
    qamSig = qammod(head, M);
  
    % Duplicate into all channels
    ofdm_input = qamSig;
    
    % OFDM encode (output is nfft x oversampling)
    ofdm_output = ofdmmod(ofdm_input, nfft, cplen, nullIdx, OversamplingFactor=oversample);
     
    if length(ofdm_output) ~= symbol_length*head_symbols
        error("Bad Header Length")
    end

    head_ofdm_output = OFDMclipAndNorm(ofdm_output);
    

    
    % Frequency Guard (i = 301)
    guard_data = zeros(1, symbol_length);
    
    for frame = 1:num_frames
        frame_start = ftell(output_file);
        %% Synchronization Pt 1.
        % PSS
        fprintf("PSS Sequence Length: %d \n", length(PSS));
        write_iq(output_file, PSS);
        fprintf("PSS non-zero elements: %d\n", nnz(PSS));
        % SSS
        write_iq(output_file, sss_ofdm_output);
        fprintf("SSS Sequence Length: %d\n", length(sss_ofdm_output));
        fprintf("SSS non-zero elements: %d\n", nnz(sss_ofdm_output));
        % Header
        write_iq(output_file, head_ofdm_output);
        fprintf("Header Sequence Length: %d\n", length(head_ofdm_output));

        %% Data Generation and Writing
    
        % 16QAM(i = 6-12)
        M = 16;
        nSym = 6; % Number of symbols in frame
        data = fread(data_file, max_hex_16qam*nSym, "*ubit4");
        data = qammod(data, M);
        if length(data) < max_hex_16qam*nSym
            data = resize(data, max_hex_16qam*nSym, FillValue=15);
        end
        ofdm_input = reshape(data, [N, nSym]);
        ofdm_output = ofdmmod(ofdm_input, nfft, cplen, nullIdx, OversamplingFactor=oversample);
        ofdm_output = OFDMclipAndNorm(ofdm_output);
        write_iq(output_file, ofdm_output);

        % 4QAM (i = 13-298)
        M = 4;
        nSym = 286; % Number of symbols in frame
        data = fread(data_file, N*nSym, "*ubit2");
        % Check is file is complete and then fill
        if length(data) < nSym*n_streams
            fprintf('Incomplete Frame. Only %d read, Filling with 0xFF\n', length(data))
            data = resize(data, nSym*n_streams, FillValue=3);
        end
        data = qammod(data, M);
    
        ofdm_input = reshape(data, [N, nSym]);
        ofdm_output = ofdmmod(ofdm_input, nfft, cplen, nullIdx, OversamplingFactor=oversample);
        ofdm_output = OFDMclipAndNorm(ofdm_output);
        write_iq(output_file, ofdm_output);
        fprintf("Data Sequence Length: %d\n", length(ofdm_output));

        %% Synchronization pt 2
        % CM1SS (i = 299)
        M = 4;
        data = randi([0 M-1], n_streams,1);
        ofdm_input = qammod(data, M);
        ofdm_output = ofdmmod(ofdm_input, nfft, cplen, nullIdx, OversamplingFactor=oversample);
        % Normalized
        ofdm_output = OFDMclipAndNorm(ofdm_output);
    
        write_iq(output_file, ofdm_output);
        fprintf("CM1SS Sequence Length: %d\n", length(ofdm_output));

        % CSS (i = 300)
        M = 4;
        data = randi([0 M-1], n_streams, 1);
        ofdm_input = qammod(data, M);
    
        ofdm_output = ofdmmod(ofdm_input, nfft, cplen, nullIdx, OversamplingFactor=oversample);
        % Normalized
        ofdm_output = OFDMclipAndNorm(ofdm_output);
        write_iq(output_file, ofdm_output);
        fprintf("CSS Sequence Length: %d\n", length(ofdm_output));

        %% Frequency Guard

        write_iq(output_file, guard_data);
        fprintf("Guard Sequence Length: %d\n", length(data));

        bytes_written = ftell(output_file) - frame_start;
        fprintf("Frame %d Complete. %d Bytes Written\n",frame, bytes_written);
    end 
end








