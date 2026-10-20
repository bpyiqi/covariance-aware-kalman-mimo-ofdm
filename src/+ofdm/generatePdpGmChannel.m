function H = generatePdpGmChannel(N_FFT, N_sym, rho, Fs, delays, pdp_dB, abrupt)
%GENERATEPDPGMCHANNEL 2x2 frequency-domain Gauss-Markov PDP channel.
%   RHO can be a scalar or a length-N_sym vector. The optional ABRUPT flag
%   injects one mid-frame path jump for stress tests.

if nargin < 7
    abrupt = false;
end

pwr = 10.^(pdp_dB/10);
pwr = pwr / sum(pwr);
num_paths = numel(delays);
sc_indices = (-N_FFT/2:N_FFT/2-1).';
f_sc = sc_indices * Fs / N_FFT;
path_phase = exp(-1j * 2*pi * f_sc * delays);
H = zeros(N_FFT, N_sym, 2, 2, 'single');

if isscalar(rho)
    rho_vec = rho * ones(1, N_sym);
else
    assert(numel(rho) == N_sym, 'rho vector length must equal N_sym.');
    rho_vec = rho(:).';
end

jump_t = round(0.55 * N_sym);
for rx = 1:2
    for tx = 1:2
        alpha = zeros(num_paths, N_sym);
        alpha(:,1) = sqrt(pwr(:)/2) .* ...
            (randn(num_paths,1) + 1j*randn(num_paths,1));
        for t = 2:N_sym
            rho_t = rho_vec(t);
            innov_scale = sqrt(max(1 - rho_t^2, 0));
            if abrupt && t == jump_t
                alpha(:,t-1) = alpha(:,t-1) + ...
                    0.8 * sqrt(pwr(:)/2) .* ...
                    (randn(num_paths,1) + 1j*randn(num_paths,1));
            end
            w = sqrt(pwr(:)/2) .* ...
                (randn(num_paths,1) + 1j*randn(num_paths,1));
            alpha(:,t) = rho_t * alpha(:,t-1) + innov_scale * w;
        end
        H(:,:,rx,tx) = single(path_phase * alpha);
    end
end
end
