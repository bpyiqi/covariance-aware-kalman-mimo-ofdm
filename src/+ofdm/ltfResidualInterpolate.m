function H_est = ltfResidualInterpolate(H_ltf, pilot_obs, N_FFT)
%LTFRESIDUALINTERPOLATE Interpolate payload-pilot residual over subcarriers.

H_est = H_ltf;
sc = (1:N_FFT).';
for tx = 1:2
    rows = pilot_obs.idx(pilot_obs.tx == tx);
    cols = find(pilot_obs.tx == tx);
    for rx = 1:2
        base = squeeze(H_ltf(rows,rx,tx));
        obs = double(pilot_obs.h_rx(rx, cols)).';
        residual = obs(:) - double(base(:));
        real_interp = interp1(rows(:), real(residual), sc, 'linear', 'extrap');
        imag_interp = interp1(rows(:), imag(residual), sc, 'linear', 'extrap');
        H_est(:,rx,tx) = H_ltf(:,rx,tx) + single(real_interp + 1j*imag_interp);
    end
end
end

