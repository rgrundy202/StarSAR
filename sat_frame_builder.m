% sat_frame_builder.m
% Loads the fake satellite header text, converts it to a binary frame,
% and pads/truncates to exactly 3 frames.

clc; clear; close all;

TARGET_BITS  = 4 * 3 * 1024;     
TARGET_BYTES = TARGET_BITS / 8;  

%% 1. Read the header text file
fid = fopen('sat_header_data.txt', 'r');
raw = fread(fid, '*uint8');       % read as byte array
fclose(fid);


if numel(raw) >= TARGET_BYTES
    % Truncate: keep first 4095 bytes, write 0x00 sentinel at byte 4096
    frame = raw(1:TARGET_BYTES);
    frame(TARGET_BYTES) = 0x00;   % mark end of useful content
    fprintf('Truncated to %d bytes.\n', TARGET_BYTES);
else
    % Pad with 0xFF (standard idle/fill pattern in CCSDS)
    padLen = TARGET_BYTES - numel(raw);
    frame  = [raw; repmat(uint8(0xFF), padLen, 1)];
    fprintf('Padded %d bytes with 0xFF fill.\n', padLen);
end

%% 3. Verify size
assert(numel(frame) == TARGET_BYTES, 'Frame size mismatch!');


%% 4. Convert to bit stream (MSB first per CCSDS convention)
bitStream = de2bi(frame, 8, 'left-msb');   % [4096 x 8]
bitStream = bitStream';                     % [8 x 4096]
bitStream = bitStream(:)';                  % [1 x 32768] row vector

assert(numel(bitStream) == TARGET_BITS, 'Bit count mismatch!');
fprintf('Bit stream    : %d bits\n', numel(bitStream));

%% 5. Convert to Base-4 (for QAM mapping, 2 bits per symbol)
numSymbols = TARGET_BITS / 2;              
base4 = zeros(1, numSymbols);
for i = 1:numSymbols
    base4(i) = bitStream(2*i-1)*2 + bitStream(2*i);  % 2-bit to base-4
end


%% 9. Write final binary frame to file
fid = fopen('header.txt', 'wb');
fwrite(fid, frame, 'uint8');
fclose(fid);

