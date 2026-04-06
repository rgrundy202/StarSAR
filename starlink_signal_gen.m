%% StarLink Signal Generation Script
% Taken from research done on Humphrey et al. (2023)



function X = starlink_signal_gen(filename, out_filename)
    
    

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
    
%%%%%%%%%%%%%%%%%%%%%% Environment Variables %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    oversample = 1;
    symbol_length = (N+N_g+gutter_len)*oversample;
    max_hex_4qam = 512;
    max_hex_16qam = 2048;
    max_bytes_per_frame = 1024*(4*8+286*2)/8;
    file_prop = dir(filename);

    num_frames = ceil(file_prop.bytes/max_bytes_per_frame);
    
    data_file = fopen(filename);
    output_file = fopen(out_filename, 'a');




    
%%%%%%%%%%%%%%%%%% Generate NonFrame Specific Data %%%%%%%%%%%%%%%%%%%%%%%% 
  

    %% PSS (SDPSK) (i = 0)
    
    N_block = 8; % Number of blocks in symbol
    L = 128; % Length of block
    pss_len = 8 * L;
    PSS_seq = zeros(1, pss_len); % Start signal frame array

    
    
    % Data in each repeated PSS signal
    q_pss = zeros(1,L);

    q_pss_hex = file_to_array("qpss.hex");
    if length(q_pss_hex) ~= 32
        error("Bad PSS Length")
    end

    q_pss_hex = dec2bin(hex2dec(q_pss_hex));
    for i = 1:L
        q_pss(i)= str2double(q_pss_hex(i));
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
    % Stretch out to match other frames
    PSS = resample(PSS_seq, (symbol_length-N_g)*oversample, length(PSS_seq));

    cyclic_pre = 
    


    %% SSS (4QAM) (i = 1) 
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
    nullIdx = (N/2-1:N/2+2).'; % IDs of null carriers
    cplen = N_g;
    nfft = (n_streams+length(nullIdx))*oversample; % length for fft. subs x 
    

    % 4QAM modulation
    qamSig = qammod(q_sss, M);
    
    % Duplicate into all channels
    ofdm_input = qamSig .';
    
    % OFDM encode (output is nfft x oversampling)
    ofdm_output = ofdmmod(ofdm_input, nfft, cplen, nullIdx, OversamplingFactor=oversample);
    
    if length(ofdm_output) ~= symbol_length
        error("Bad SSS Symbol Length")
    end

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
    
    nSym = 3; % Number of symbols in frame
    n_streams = N; % Number of subcarriers
    nullIdx = (N/2-1:N/2+2).'; % IDs of null carriers
    cplen = N_g;
    nfft = (n_streams+length(nullIdx)); % length for fft. subs x 
    

    % 4QAM modulation
    qamSig = qammod(head, M);
    
    
    % Duplicate into all channels
    ofdm_input = qamSig;
    
    % OFDM encode (output is nfft x oversampling)
    ofdm_output = ofdmmod(ofdm_input, nfft, cplen, nullIdx, OversamplingFactor=oversample);
    
    if length(ofdm_output) ~= symbol_length*head_symbols
        error("Bad Header Length")
    end

    %% Data
    
    % 16QAM(i = 6-12)


    % 4QAM (i = 13-299)
    
    %% Synchronization
    % CM1SS (i = 300)

    % CSS (i = 301)

    % Frequency Guard
end





