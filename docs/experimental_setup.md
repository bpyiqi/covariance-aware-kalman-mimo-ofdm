# Experimental setup

The C1 evidence package uses a 2×2 MIMO-OFDM receiver with a 64-point FFT, 16-sample cyclic prefix, 20 MHz sampling rate, 16-QAM, four pilot subcarriers, and DVB-S2 half-rate LDPC coding through MATLAB Communications Toolbox.

The formal validation contains 50 paired physical packets for each payload condition, `payloadSymbols = 169` and `payloadSymbols = 507`, at SNR = 20 dB and maximum Doppler frequency = 200 Hz. The method list is recorded in the frozen manifest and includes Base, Fixed, covariance-aware Proposed, OJCD, Oracle, and Perfect CSI controls.

The robustness A/B experiment contains 20 paired physical packets per condition for payload 169. The SNR view uses 15, 20, and 25 dB at 200 Hz; the Doppler view uses 100, 200, and 300 Hz at 20 dB. The shared center condition is not counted as a second set of physical packets.

The independent ablation experiment contains 20 paired physical packets at SNR = 20 dB, maximum Doppler = 200 Hz, and payload 169. It compares Base, Fixed, Gram-only, Residual-only, and Full Proposed using the same paired packet construction. The stored runner is not executed during release assembly.

