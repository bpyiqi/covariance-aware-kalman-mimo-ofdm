function H_out = kalmanFeatures(H_obs, rho, noise_var, process_scale, obs_scale, do_smooth)
%KALMANFEATURES Causal scalar Kalman tracker over CSI feature streams.

sz = size(H_obs);
N_FFT = sz(1);
N_sym = sz(2);
num_ch = sz(3);
Z = reshape(permute(single(H_obs), [1 3 2]), N_FFT*num_ch, N_sym);
state_var = max(mean(double(Z).^2, 2), 1e-5);
q = process_scale * max(1 - rho^2, 1e-8) .* state_var;
r = obs_scale * max(noise_var / 2, 1e-8);
x_f = zeros(size(Z), 'double');
p_f = zeros(size(Z), 'double');
x_p = zeros(size(Z), 'double');
p_p = zeros(size(Z), 'double');
x = double(Z(:,1));
p = state_var + r;
x_f(:,1) = x;
p_f(:,1) = p;
x_p(:,1) = x;
p_p(:,1) = p;
for t = 2:N_sym
    xp = rho * x;
    pp = rho^2 .* p + q;
    k = pp ./ (pp + r);
    x = xp + k .* (double(Z(:,t)) - xp);
    p = (1 - k) .* pp;
    x_p(:,t) = xp;
    p_p(:,t) = pp;
    x_f(:,t) = x;
    p_f(:,t) = p;
end
if do_smooth
    x_s = x_f;
    for t = N_sym-1:-1:1
        g = p_f(:,t) .* rho ./ max(p_p(:,t+1), eps);
        x_s(:,t) = x_f(:,t) + g .* (x_s(:,t+1) - x_p(:,t+1));
    end
    X = x_s;
else
    X = x_f;
end
H_out = permute(reshape(single(X), N_FFT, num_ch, N_sym), [1 3 2]);
end

