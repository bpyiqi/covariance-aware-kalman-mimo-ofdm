function [H_out, fwd, theta_out] = emKalmanFeatures(H_obs, theta, opts)
%EMKALMANFEATURES Packet-to-packet EM Kalman CSI tracker.

if nargin < 3 || isempty(opts)
    opts = struct();
end

sz = size(H_obs);
N_FFT = sz(1);
N_sym = sz(2);
num_ch = sz(3);

Z = reshape(permute(single(H_obs), [1 3 2]), N_FFT*num_ch, N_sym);
Z = double(Z);
F = size(Z, 1);

rho = theta.rho;

if isscalar(theta.Q)
    Q = theta.Q * ones(F, 1);
else
    Q = theta.Q(:);
    if numel(Q) ~= F
        Q = mean(Q) * ones(F, 1);
    end
end

if isscalar(theta.R)
    R = theta.R;
else
    R = mean(theta.R(:));
end

fwd = ofdm.kalmanForwardFull(Z, rho, Q, R);
smo = ofdm.rtsSmooth(fwd, rho, Q);

em_opts = struct();
em_opts.rho_min = get_opt(opts, 'rho_min', 0.90);
em_opts.rho_max = get_opt(opts, 'rho_max', 0.9999999);
em_opts.q_min = get_opt(opts, 'q_min', 1e-10);
em_opts.q_max = get_opt(opts, 'q_max', 1e-2);
em_opts.r_min = get_opt(opts, 'r_min', 1e-6);
em_opts.r_max = get_opt(opts, 'r_max', 1e-1);
em_opts.em_lr = get_opt(opts, 'em_lr', 0.3);
em_opts.warmup_r = get_opt(opts, 'warmup_r', 3);
em_opts.pkt_idx = get_opt(opts, 'pkt_idx', 999);

theta_out = ofdm.emUpdateTheta(Z, fwd, smo, theta, em_opts);
if get_opt(opts, 'verbose', false)
    fprintf('pkt R=%.3e rho=%.8f\n', theta_out.R, theta_out.rho);
end

H_out = permute(reshape(single(fwd.x_filt), N_FFT, num_ch, N_sym), [1 3 2]);
end

function value = get_opt(opts, name, default_value)
if isfield(opts, name) && ~isempty(opts.(name))
    value = opts.(name);
else
    value = default_value;
end
end
