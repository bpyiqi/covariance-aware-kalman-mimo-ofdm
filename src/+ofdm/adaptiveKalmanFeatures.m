function [H_out, stats] = adaptiveKalmanFeatures(H_obs, rho, noise_var, ...
    process_scale, obs_scale, opts)
%ADAPTIVEKALMANFEATURES Online rho/Q adaptive Kalman CSI tracker.

if nargin < 6 || isempty(opts)
    opts = struct();
end

forget = get_opt(opts, 'forget', 0.97);
rho_forget = get_opt(opts, 'rho_forget', 0.995);
q_min = get_opt(opts, 'q_min', 1e-9);
q_max = get_opt(opts, 'q_max', 1e-3);
warmup = get_opt(opts, 'warmup', 30);
rho_min = get_opt(opts, 'rho_min', 0.90);
rho_max = get_opt(opts, 'rho_max', 0.9999999);

sz = size(H_obs);
N_FFT = sz(1);
N_sym = sz(2);
num_ch = sz(3);

Z = reshape(permute(single(H_obs), [1 3 2]), N_FFT*num_ch, N_sym);
Z = double(Z);

state_var = max(mean(Z.^2, 2), 1e-5);
Q = process_scale * max(1 - rho^2, 1e-8) .* state_var;
R = obs_scale * max(noise_var / 2, 1e-8) * ones(size(state_var));
rho_hat = rho * ones(size(state_var));

x = Z(:, 1);
p = state_var + R;

num_xy = rho_hat .* state_var;
den_xx = state_var;
X = zeros(size(Z));
X(:, 1) = x;

gain_trace = zeros(1, N_sym);
q_trace = zeros(1, N_sym);
rho_trace = zeros(1, N_sym);
innov_trace = zeros(1, N_sym);

gain_trace(1) = mean(p ./ max(p + R, eps));
q_trace(1) = mean(Q);
rho_trace(1) = mean(rho_hat);
innov_trace(1) = 0;

for t = 2:N_sym
    xp = rho_hat .* x;
    pp = rho_hat.^2 .* p + Q;
    innov = Z(:, t) - xp;
    S = pp + R;
    k = pp ./ max(S, eps);
    x_new = xp + k .* innov;
    p = (1 - k) .* pp;

    if t > warmup
        d = (1 - forget) / (1 - forget^t);
        Q = min(q_max, max(q_min, (1 - d) .* Q + d .* (k .* innov).^2));

        num_xy = rho_forget .* num_xy + x_new .* x;
        den_xx = rho_forget .* den_xx + x.^2;
        rho_hat = min(rho_max, max(rho_min, num_xy ./ max(den_xx, eps)));
    end

    x = x_new;
    X(:, t) = x;
    gain_trace(t) = mean(k);
    q_trace(t) = mean(Q);
    rho_trace(t) = mean(rho_hat);
    innov_trace(t) = mean(innov.^2);
end

H_out = permute(reshape(single(X), N_FFT, num_ch, N_sym), [1 3 2]);

if nargout > 1
    stats.gain = gain_trace;
    stats.q_trace = q_trace;
    stats.rho_trace = rho_trace;
    stats.innov = innov_trace;
    stats.forget = forget;
    stats.rho_forget = rho_forget;
    stats.method = "adaptive_rho_q";
else
    stats = [];
end
end

function value = get_opt(opts, name, default_value)
if isfield(opts, name) && ~isempty(opts.(name))
    value = opts.(name);
else
    value = default_value;
end
end
