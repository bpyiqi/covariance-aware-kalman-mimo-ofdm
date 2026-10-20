function crc_bits = crc32Bits(data_bits)
%CRC32BITS Compute CRC-32 bits using the project video-link convention.

persistent crc_gen
if isempty(crc_gen)
    crc_gen = comm.CRCGenerator('Polynomial', ...
        'z^32 + z^26 + z^23 + z^22 + z^16 + z^12 + z^11 + z^10 + z^8 + z^7 + z^5 + z^4 + z^2 + z + 1', ...
        'InitialConditions', 1, 'DirectMethod', true, 'FinalXOR', 1);
end
codeword = crc_gen(logical(data_bits(:)));
crc_bits = logical(codeword(numel(data_bits)+1:end));
end

