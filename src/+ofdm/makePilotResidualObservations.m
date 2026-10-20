function H_obs = makePilotResidualObservations(H_true, H_ltf, N_FFT, noise_var, ...
        pilot_idx, pilot_val, pilot_tx)
%MAKEPILOTRESIDUALOBSERVATIONS Full-band CSI observations from payload pilots.

N_sym = size(H_true, 2);
H_obs = zeros(size(H_true), 'single');
for t = 1:N_sym
    pilot_obs = ofdm.makePayloadPilotObservation(squeeze(H_true(:,t,:,:)), ...
        pilot_idx, pilot_val, pilot_tx, noise_var);
    H_obs(:,t,:,:) = ofdm.ltfResidualInterpolate(H_ltf, pilot_obs, N_FFT);
end
end

