function [err_count, bit_count] = evalUncodedBerSymbol( ...
        H_true_feat, pred_feats, t, data_sc, M, bits_per_symbol, noise_var)
%EVALUNCODEDBERSYMBOL Random 2-stream 16QAM BER for one OFDM symbol.

num_methods = numel(pred_feats);
num_data = numel(data_sc);
bit_count = 2 * num_data * bits_per_symbol;
err_count = zeros(1, num_methods);
tx_bits = randi([0 1], bit_count, 1);
bits_per_stream = num_data * bits_per_symbol;
x = zeros(2, num_data);
for s = 1:2
    rows = (s-1)*bits_per_stream + (1:bits_per_stream);
    x(s,:) = reshape(qammod(tx_bits(rows), M, ...
        'InputType', 'bit', 'UnitAveragePower', true), 1, []);
end
y = zeros(2, num_data);
for n = 1:num_data
    k = data_sc(n);
    H = ofdm.featuresToMatrix(H_true_feat, k, t);
    noise = sqrt(noise_var/2) * (randn(2,1) + 1j*randn(2,1));
    y(:,n) = H * x(:,n) + noise;
end
for m = 1:num_methods
    x_hat = ofdm.mmseEqualizeFeatureGrid(pred_feats{m}, t, data_sc, y, noise_var);
    rx_bits = zeros(bit_count, 1);
    for s = 1:2
        dec = qamdemod(x_hat(s,:).', M, ...
            'OutputType', 'bit', 'UnitAveragePower', true);
        rows = (s-1)*bits_per_stream + (1:bits_per_stream);
        rx_bits(rows) = dec(:);
    end
    err_count(m) = sum(rx_bits ~= tx_bits);
end
end

