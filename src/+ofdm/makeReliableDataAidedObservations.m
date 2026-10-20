function [H_aug, stats] = makeReliableDataAidedObservations(H_obs, H_seed, y_data, data_sc, noise_var, opts)
%MAKERELIABLEDATAAIDEDOBSERVATIONS Augment pilot observations with reliable data decisions.

if nargin < 6 || isempty(opts)
    opts = struct();
end

window_radius = get_opt(opts, 'window_radius', 2);
llr_threshold = get_opt(opts, 'llr_threshold', 2.5);
min_reliable = get_opt(opts, 'min_reliable', 2);
blend_alpha = get_opt(opts, 'blend_alpha', 0.75);
gram_rcond_min = get_opt(opts, 'gram_rcond_min', 1e-3);
llr_noise_scale = get_opt(opts, 'llr_noise_scale', 1);
llr_noise_floor = get_opt(opts, 'llr_noise_floor', 1e-6);
llr_clip = get_opt(opts, 'llr_clip', 40);

N_data = numel(data_sc);
N_sym = size(H_obs, 2);

H_aug = H_obs;
x_dec = complex(zeros(N_data, N_sym, 2, 'single'));
reliability = zeros(N_data, N_sym, 'single');
reliable_mask = false(N_data, N_sym);
update_count = 0;

for t = 1:N_sym
    for id = 1:N_data
        k = data_sc(id);
        y = squeeze(y_data(id, t, :));
        Hk = squeeze(H_seed(k, t, :, :));
        x_hat = ofdm.mmseEqualize2x2(y, Hk, noise_var);
        % Use a finite and calibrated LLR for reliability gating.
        % The original exact LLR can overflow to Inf/NaN, which makes the gate useless.
        eff_noise_var = max(noise_var * llr_noise_scale, llr_noise_floor);
        
        llr = qamdemod(x_hat, 16, 'UnitAveragePower', true, ...
            'OutputType', 'approxllr', 'NoiseVariance', eff_noise_var);
        
        llr = double(llr);
        
        % Handle numerical overflow explicitly.
        pos_inf = isinf(llr) & llr > 0;
        neg_inf = isinf(llr) & llr < 0;
        llr(pos_inf) = llr_clip;
        llr(neg_inf) = -llr_clip;
        llr(isnan(llr)) = 0;
        
        % Clip extreme LLR values so that reliability statistics remain meaningful.
        llr = max(min(llr, llr_clip), -llr_clip);
        
        llr = reshape(llr, 4, []);
        stream_score = mean(abs(llr), 1);
        reliability(id, t) = min(stream_score);
        reliable_mask(id, t) = all(stream_score >= llr_threshold);

        dec_int = qamdemod(x_hat, 16, 'UnitAveragePower', true);
        x_dec(id, t, :) = reshape(single(qammod(dec_int, 16, 'UnitAveragePower', true)), 1, 1, []);
    end
end

for t = 1:N_sym
    for id = 1:N_data
        idx = max(1, id - window_radius):min(N_data, id + window_radius);
        idx = idx(reliable_mask(idx, t));
        if numel(idx) < min_reliable
            continue;
        end

        X = reshape(x_dec(idx, t, :), numel(idx), 2).';
        gram = X * X';
        if rcond(gram) < gram_rcond_min
            continue;
        end

        if llr_threshold <= 0
            weight = blend_alpha;
        else
            weight = blend_alpha * min(1, mean(double(reliability(idx, t))) / (2 * llr_threshold));
        end
        k = data_sc(id);
        for rx = 1:2
            yv = squeeze(y_data(idx, t, rx)).';
            h_row = (yv * X') / gram;
            base = squeeze(H_obs(k, t, rx, :)).';
            H_aug(k, t, rx, 1) = single((1 - weight) * base(1) + weight * h_row(1));
            H_aug(k, t, rx, 2) = single((1 - weight) * base(2) + weight * h_row(2));
        end
        update_count = update_count + 1;
    end
end

stats.reliable_fraction = mean(reliable_mask(:));
stats.updated_fraction = update_count / max(N_data * N_sym, 1);
finite_rel = reliability(isfinite(reliability));
if isempty(finite_rel)
    stats.mean_reliability = NaN;
else
    stats.mean_reliability = mean(finite_rel(:));
end

if isfield(opts, 'label') && ~isempty(opts.label)
    label = opts.label;
else
    label = 'DataAidedKalman';
end

if strcmp(getenv('RDK_PRINT_STATS'), '1')
    fprintf('    [%s] llr_th=%.3g reliable_fraction=%.3f updated_fraction=%.3f mean_reliability=%.3f\n', ...
        label, llr_threshold, stats.reliable_fraction, stats.updated_fraction, stats.mean_reliability);
end

end

function value = get_opt(opts, name, default_value)
if isfield(opts, name) && ~isempty(opts.(name))
    value = opts.(name);
else
    value = default_value;
end
end
