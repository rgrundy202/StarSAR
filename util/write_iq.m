function write_iq(fid, x)
    interleaved = zeros(1, 2*length(x));
    interleaved(1:2:end) = real(x);
    interleaved(2:2:end) = imag(x);
    fwrite(fid, interleaved, 'double');
end