function H = generateItuaGmChannel(N_FFT, N_sym, rho, Fs)
delays = [0, 10, 20, 30, 50, 70] * 1e-9;
pdp_dB = [0, -3.6, -7.2, -10.8, -18.0, -25.2];
H = ofdm.generatePdpGmChannel(N_FFT, N_sym, rho, Fs, delays, pdp_dB, false);
end