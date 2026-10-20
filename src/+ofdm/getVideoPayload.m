function payload_bits = getVideoPayload(video_bits, packet_id, payload_len)
%GETVIDEOPAYLOAD Circular packet slice from a video bitstream.

start_idx = (packet_id - 1) * payload_len + 1;
idx = mod((start_idx:start_idx+payload_len-1) - 1, numel(video_bits)) + 1;
payload_bits = video_bits(idx);
end

