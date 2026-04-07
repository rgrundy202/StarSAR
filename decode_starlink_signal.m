function data = decode_starlink_signal(in_filename)

    input_file = fopen(in_filename, 'r');
    raw = fread(input_file, [2, Inf], 'double');
    fclose(input_file);

    if size(raw, 2) == 0
        error('No data read from file: %s', in_filename);
    end

    data = raw(1,:) + 1j * raw(2,:);
end