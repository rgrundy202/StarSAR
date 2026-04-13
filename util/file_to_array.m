function hexArray = file_to_array(filename)
    % Read hex file and convert to numeric array
    % Supports space-separated, newline-separated, or continuous hex strings
    
    %Read the file as text
    fid = fopen(filename, 'r');
    if fid == -1
        error('Could not open file: %s', filename);
    end
    raw = fread(fid, '*char')';
    fclose(fid);
    if regexp(filename, "\.hex$", 'once')
        %Strip whitespace and newlines, split into hex byte tokens
        raw = strrep(raw, sprintf('\n'), ' ');
        raw = strrep(raw, sprintf('\r'), ' ');
        tokens = strsplit(strtrim(raw));
        tokens = tokens(~cellfun('isempty', tokens));  % remove empty entries
        
        %Handle both "AB CD EF" and continuous "ABCDEF" formats
        if isscalar(tokens)
            % Continuous string - split into 2-char chunks
            s = tokens{1};
            if mod(length(s), 2) ~= 0
            error('Hex string has odd length - cannot split into bytes');
            end
            tokens = arrayfun(@(i) s(i:i+1), 1:length(s), 'UniformOutput', false);
        end
        hexArray = cellstr(blanks(length(tokens)*2));
        for i = 1:length(tokens)
            hexArray{2*i-1} = tokens{i}(1);
            hexArray{2*i} = tokens{i}(2);
        end

    else
        %Convert each byte to a 2-char hex string
        hexArray = arrayfun(@(b) dec2hex(b), raw, 'UniformOutput', false);
    end
end



