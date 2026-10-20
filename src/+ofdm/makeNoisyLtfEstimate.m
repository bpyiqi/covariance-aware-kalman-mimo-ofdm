function H_ltf = makeNoisyLtfEstimate(H0, active_sc, noise_var)
%MAKENOISYLTFESTIMATE Build noisy HT-LTF initial CSI on active subcarriers.

H_ltf = zeros(size(H0), 'like', H0);
ltf_noise_var = noise_var / 2;
noise = sqrt(ltf_noise_var/2) * ...
    (randn(numel(active_sc),2,2) + 1j*randn(numel(active_sc),2,2));
H_ltf(active_sc,:,:) = H0(active_sc,:,:) + single(noise);
end

