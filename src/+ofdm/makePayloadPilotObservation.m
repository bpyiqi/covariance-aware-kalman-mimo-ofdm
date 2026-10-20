function pilot_obs = makePayloadPilotObservation(Ht, pilot_idx, pilot_val, pilot_tx, noise_var)
%MAKEPAYLOADPILOTOBSERVATION Noisy per-pilot LS observations for 2x2 MIMO.

pilot_obs = struct();
pilot_obs.idx = pilot_idx;
pilot_obs.tx = pilot_tx;
pilot_obs.h_rx = zeros(2, numel(pilot_idx), 'single');
for i = 1:numel(pilot_idx)
    k = pilot_idx(i);
    tx = pilot_tx(i);
    p = pilot_val(i);
    noise = sqrt(noise_var/2) * (randn(2,1) + 1j*randn(2,1));
    y = squeeze(Ht(k,:,tx)).' * p + noise;
    pilot_obs.h_rx(:,i) = single(y / p);
end
end

