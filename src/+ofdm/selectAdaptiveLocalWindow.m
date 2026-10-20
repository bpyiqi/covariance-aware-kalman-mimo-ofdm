function [idx, info] = selectAdaptiveLocalWindow(center_id, data_sc, x_dec_t, radii, gram_rcond_min, opts)
%SELECTADAPTIVELOCALWINDOW Select the smallest feasible local MIMO LS window.
%
% Inputs:
%   center_id       Index of the target data subcarrier within data_sc.
%   data_sc         Active data-subcarrier map. Only entries in this vector
%                   are eligible, so pilot/null/DC carriers are excluded by
%                   construction.
%   x_dec_t         N_data-by-N_t decided-symbol matrix at one OFDM symbol.
%   radii           Candidate half-window radii, tested in ascending order.
%   gram_rcond_min  Minimum acceptable rcond(X*X').
%   opts            Optional struct. require_full_rank defaults to true.
%
% Outputs:
%   idx             Selected row indices into data_sc/x_dec_t. Empty means
%                   fallback to the base observation.
%   info            Selection diagnostics: selected_radius, rcond, rank,
%                   sample_count, rejected, and reject_reason.
%
% Mathematical meaning:
%   For each radius r, this function forms X in C^(N_t-by-L) from decided
%   symbols on valid data carriers around center_id, then accepts the first
%   radius with L >= N_t, full numerical rank, and rcond(X*X') above the
%   configured threshold. True CSI is not used.

if nargin < 6 || isempty(opts)
    opts = struct();
end

require_full_rank = get_opt(opts, 'require_full_rank', true);
rank_tol = get_opt(opts, 'rank_tol', []);

radii = unique(radii(:).');
radii = radii(isfinite(radii) & radii >= 0);
radii = sort(radii);

N_data = numel(data_sc);
N_t = size(x_dec_t, 2);

idx = [];
info = struct();
info.selected_radius = NaN;
info.rcond = NaN;
info.rank = 0;
info.sample_count = 0;
info.rejected = true;
info.reject_reason = "no_feasible_window";

for r = radii
    cand = max(1, center_id - r):min(N_data, center_id + r);
    X = reshape(x_dec_t(cand, :), numel(cand), N_t).';
    finite_mask = all(isfinite(real(X)) & isfinite(imag(X)), 1);
    cand = cand(finite_mask);
    X = X(:, finite_mask);
    L = size(X, 2);

    if L < N_t
        info.reject_reason = "too_few_samples";
        continue;
    end

    gram = X * X';
    gram_rc = rcond(double(gram));
    if isempty(rank_tol)
        s = svd(double(X), 'econ');
        if isempty(s)
            rank_x = 0;
        else
            rank_x = sum(s > max(size(X)) * eps(max(s)));
        end
    else
        s = svd(double(X), 'econ');
        rank_x = sum(s > rank_tol);
    end

    info.rcond = gram_rc;
    info.rank = rank_x;
    info.sample_count = L;

    if require_full_rank && rank_x < N_t
        info.reject_reason = "rank_deficient";
        continue;
    end

    if ~isfinite(gram_rc) || gram_rc < gram_rcond_min
        info.reject_reason = "ill_conditioned_gram";
        continue;
    end

    idx = cand;
    info.selected_radius = r;
    info.rejected = false;
    info.reject_reason = "";
    return;
end
end

function value = get_opt(opts, name, default_value)
if isfield(opts, name) && ~isempty(opts.(name))
    value = opts.(name);
else
    value = default_value;
end
end
