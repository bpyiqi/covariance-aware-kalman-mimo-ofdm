function bytes = bitsToBytes(bits)
%BITSTOBYTES Pack logical bits into uint8 bytes, left-MSB order.

bits = logical(bits(:));
pad = mod(8 - mod(numel(bits), 8), 8);
bits = [bits; false(pad, 1)];
bytes = uint8(bi2de(reshape(bits, 8, []).', 'left-msb'));
end

