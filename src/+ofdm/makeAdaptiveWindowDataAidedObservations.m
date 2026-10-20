function [H_aug, stats] = makeAdaptiveWindowDataAidedObservations(H_obs, H_seed, y_data, data_sc, noise_var, opts)
%MAKEADAPTIVEWINDOWDATAAIDEDOBSERVATIONS Adaptive local data-aided CSI observations.
%
% Inputs:
%   H_obs      Base pilot-residual observation, N_FFT-by-N_sym-by-2-by-2.
%   H_seed     First-stage Kalman CSI used only for MMSE data decisions.
%   y_data     Received data grid, N_data-by-N_sym-by-2.
%   data_sc    Data-subcarrier map. Local windows are formed in this index
%              space, so pilot, null, guard, and DC carriers are excluded.
%   noise_var  Equalizer noise variance.
%   opts       Configuration struct. Common fields:
%              radii, gram_rcond_min, require_full_rank, blend_alpha,
%              llr_threshold, use_llr_gate, fallback.
%
% Outputs:
%   H_aug      Observation grid after admitting valid local LS pseudo
%              observations. Rejected carriers keep H_obs.
%   stats      Radius/rejection/Gram statistics for experiment reporting.
%
% Mathematical meaning:
%   Data decisions from H_seed form X_r in C^(2-by-L_r). The smallest radius
%   with L_r >= 2, full numerical rank, and rcond(X_r X_r') above the
%   configured threshold is used to build H_ls = (Y X_r')/(X_r X_r').
%   If no radius is feasible, the function explicitly falls back to H_obs.
%   True CSI is never used for window selection or LS construction.

if nargin < 6 || isempty(opts)
    opts = struct();
end

radii = get_opt(opts, 'radii', [1 2 3]);
gram_rcond_min = get_opt(opts, 'gram_rcond_min', 1e-3);
require_full_rank = get_opt(opts, 'require_full_rank', true);
blend_alpha = get_opt(opts, 'blend_alpha', 1.0);
use_llr_gate = logical(get_opt(opts, 'use_llr_gate', false));
llr_threshold = get_opt(opts, 'llr_threshold', 2.5);
llr_noise_scale = get_opt(opts, 'llr_noise_scale', 1);
llr_noise_floor = get_opt(opts, 'llr_noise_floor', 1e-6);
llr_clip = get_opt(opts, 'llr_clip', 40);
rank_tol = get_opt(opts, 'rank_tol', []);
label = get_opt(opts, 'label', 'AdaptiveWindowDataKalman');

radii = unique(sort(radii(:).'));
if isempty(radii)
    error('makeAdaptiveWindowDataAidedObservations:EmptyRadii', ...
        'Adaptive window radii must contain at least one radius.');
end

N_data = numel(data_sc);
N_sym = size(H_obs, 2);
N_rx = size(H_obs, 3);
N_tx = size(H_obs, 4);
if N_tx ~= 2 || N_rx ~= 2
    error('makeAdaptiveWindowDataAidedObservations:UnsupportedMimo', ...
        'This implementation expects a 2x2 MIMO channel.');
end

H_aug = H_obs;
x_dec = complex(zeros(N_data, N_sym, N_tx, 'single'));
reliability = zeros(N_data, N_sym, 'single');
candidate_mask = true(N_data, N_sym);

for t = 1:N_sym
    for id = 1:N_data
        k = data_sc(id);
        y = squeeze(y_data(id, t, :));
        Hk = squeeze(H_seed(k, t, :, :));
        x_hat = ofdm.mmseEqualize2x2(y, Hk, noise_var);

        dec_int = qamdemod(x_hat, 16, 'UnitAveragePower', true);
        x_dec(id, t, :) = reshape(single(qammod(dec_int, 16, ...
            'UnitAveragePower', true)), 1, 1, []);

        if use_llr_gate
            eff_noise_var = max(noise_var * llr_noise_scale, llr_noise_floor);
            llr = qamdemod(x_hat, 16, 'UnitAveragePower', true, ...
                'OutputType', 'approxllr', 'NoiseVariance', eff_noise_var);
            llr = double(llr);
            llr(isinf(llr) & llr > 0) = llr_clip;
            llr(isinf(llr) & llr < 0) = -llr_clip;
            llr(isnan(llr)) = 0;
            llr = max(min(llr, llr_clip), -llr_clip);
            llr = reshape(llr, 4, []);
            stream_score = mean(abs(llr), 1);
            reliability(id, t) = min(stream_score);
            candidate_mask(id, t) = all(stream_score >= llr_threshold);
        end
    end
end

radius_counts = zeros(1, numel(radii));
selected_radii = zeros(N_data * N_sym, 1);
selected_rcond = zeros(N_data * N_sym, 1);
selected_count = 0;
reject_count = 0;
rank_reject_count = 0;
gram_reject_count = 0;
sample_reject_count = 0;

select_opts = struct();
select_opts.require_full_rank = require_full_rank;
select_opts.rank_tol = rank_tol;

for t = 1:N_sym
    x_dec_t = squeeze(x_dec(:, t, :));
    for id = 1:N_data
        if ~candidate_mask(id, t)
            reject_count = reject_count + 1;
            continue;
        end

        [idx, info] = ofdm.selectAdaptiveLocalWindow(id, data_sc, x_dec_t, ...
            radii, gram_rcond_min, select_opts);
        if isempty(idx)
            reject_count = reject_count + 1;
            switch string(info.reject_reason)
                case "too_few_samples"
                    sample_reject_count = sample_reject_count + 1;
                case "rank_deficient"
                    rank_reject_count = rank_reject_count + 1;
                case "ill_conditioned_gram"
                    gram_reject_count = gram_reject_count + 1;
            end
            continue;
        end

        X = reshape(x_dec(idx, t, :), numel(idx), N_tx).';
        gram = X * X';
        k = data_sc(id);
        for rx = 1:N_rx
            yv = squeeze(y_data(idx, t, rx)).';
            h_row = (yv * X') / gram;
            base = squeeze(H_obs(k, t, rx, :)).';
            H_aug(k, t, rx, 1) = single((1 - blend_alpha) * base(1) + blend_alpha * h_row(1));
            H_aug(k, t, rx, 2) = single((1 - blend_alpha) * base(2) + blend_alpha * h_row(2));
        end

        selected_count = selected_count + 1;
        selected_radii(selected_count) = info.selected_radius;
        selected_rcond(selected_count) = info.rcond;
        rid = find(radii == info.selected_radius, 1);
        radius_counts(rid) = radius_counts(rid) + 1;
    end
end

total_targets = max(N_data * N_sym, 1);
selected_radii = selected_radii(1:selected_count);
selected_rcond = selected_rcond(1:selected_count);

stats = struct();
stats.label = label;
stats.radii = radii;
stats.radius_counts = radius_counts;
stats.radius_ratios = radius_counts ./ max(selected_count, 1);
for i = 1:numel(radii)
    fname_count = sprintf('count_r%d', radii(i));
    fname_ratio = sprintf('ratio_r%d', radii(i));
    stats.(fname_count) = radius_counts(i);
    stats.(fname_ratio) = radius_counts(i) / max(selected_count, 1);
end
stats.selected_fraction = selected_count / total_targets;
stats.reject_ratio = reject_count / total_targets;
stats.mean_selected_radius = mean_or_nan(selected_radii);
stats.mean_rcond = mean_or_nan(selected_rcond);
stats.median_rcond = median_or_nan(selected_rcond);
stats.min_rcond = min_or_nan(selected_rcond);
stats.rcond_p10 = percentile_or_nan(selected_rcond, 10);
stats.rcond_p90 = percentile_or_nan(selected_rcond, 90);
stats.rank_reject_count = rank_reject_count;
stats.gram_reject_count = gram_reject_count;
stats.sample_reject_count = sample_reject_count;
stats.llr_gate_enabled = use_llr_gate;

if strcmp(getenv('ADAPTIVE_WINDOW_PRINT_STATS'), '1')
    fprintf('    [%s] selected=%.3f reject=%.3f mean_r=%.3g mean_rcond=%.3g counts=%s\n', ...
        label, stats.selected_fraction, stats.reject_ratio, ...
        stats.mean_selected_radius, stats.mean_rcond, mat2str(radius_counts));
end
end

function value = get_opt(opts, name, default_value)
if isfield(opts, name) && ~isempty(opts.(name))
    value = opts.(name);
else
    value = default_value;
end
end

function y = mean_or_nan(x)
if isempty(x)
    y = NaN;
else
    y = mean(double(x(:)));
end
end

function y = median_or_nan(x)
if isempty(x)
    y = NaN;
else
    y = median(double(x(:)));
end
end

function y = min_or_nan(x)
if isempty(x)
    y = NaN;
else
    y = min(double(x(:)));
end
end

function y = percentile_or_nan(x, p)
if isempty(x)
    y = NaN;
    return;
end
x = sort(double(x(:)));
pos = 1 + (numel(x) - 1) * p / 100;
lo = floor(pos);
hi = ceil(pos);
if lo == hi
    y = x(lo);
else
    y = x(lo) + (pos - lo) * (x(hi) - x(lo));
end
end
