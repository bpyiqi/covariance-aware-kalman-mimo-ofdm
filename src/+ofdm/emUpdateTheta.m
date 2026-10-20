function theta = emUpdateTheta(Z, fwd, smo, theta_prev, opts)
%EMUPDATETHETA EM M-step update for scalar rho, per-feature Q, and scalar R.

if nargin < 5 || isempty(opts)
    opts = struct();
end

rho_min = get_opt(opts, 'rho_min', 0.999);
rho_max = get_opt(opts, 'rho_max', 0.9999999);
q_min = get_opt(opts, 'q_min', 1e-10);
q_max = get_opt(opts, 'q_max', 1e-2);
r_min = get_opt(opts, 'r_min', 1e-6);
r_max = get_opt(opts, 'r_max', 1e-1);
em_lr = get_opt(opts, 'em_lr', 0.15);
warmup_r = get_opt(opts, 'warmup_r', 3);
pkt_idx = get_opt(opts, 'pkt_idx', 999);

[~, T] = size(Z);
mu = smo.x_smo;
P = smo.p_smo;
Pcc = smo.p_cross;

num_rho_f = sum(Pcc + mu(:,2:T) .* mu(:,1:T-1), 2);
den_rho_f = sum(P(:,1:T-1) + mu(:,1:T-1).^2, 2);
rho_per_f = num_rho_f ./ max(den_rho_f, eps);
rho_new = median(rho_per_f);
rho_new = min(rho_max, max(rho_min, rho_new));

Q_new = mean(P(:,2:T) + mu(:,2:T).^2 ...
    - rho_new .* (Pcc + mu(:,2:T) .* mu(:,1:T-1)), 2);
Q_new = min(q_max, max(q_min, Q_new));

resid2 = (Z - mu).^2 + P;
R_new = mean(resid2(:));
R_new = min(r_max, max(r_min, R_new));

rho_out = (1 - em_lr) * theta_prev.rho + em_lr * rho_new;
Q_out = (1 - em_lr) * theta_prev.Q + em_lr * Q_new;

if pkt_idx <= warmup_r
    R_out = theta_prev.R;
else
    R_out = (1 - em_lr) * theta_prev.R + em_lr * R_new;
    R_out = min(r_max, max(r_min, R_out));
end

theta.rho = min(rho_max, max(rho_min, rho_out));
theta.Q = min(q_max, max(q_min, Q_out));
theta.R = min(r_max, max(r_min, R_out));
end

function value = get_opt(opts, name, default_value)
if isfield(opts, name) && ~isempty(opts.(name))
    value = opts.(name);
else
    value = default_value;
end
end
