# Source Directory

Shared MATLAB helpers live under the `+ofdm` package. Add this directory to
the MATLAB path before using package helpers from relocated scripts:

```matlab
addpath('src')
```

Root-level scripts that run from the repository root can call:

```matlab
addpath(fullfile(pwd, 'src'))
```

Core package helpers for the UAV CSI-aging mainline:

- `+ofdm/kalmanFeatures.m`: fixed causal Kalman filter plus optional RTS
  smoother for offline reference.
- `+ofdm/adaptiveKalmanFeatures.m`: bounded online rho/Q adaptive causal
  Kalman filter.
- `+ofdm/emKalmanFeatures.m`: packet-to-packet EM Kalman adaptation.
- `+ofdm/makeReliableDataAidedObservations.m`: reliability-gated data-aided
  pseudo-pilot observations.
- `+ofdm/uavDopplerToRho.m`: converts UAV Doppler settings to per-symbol
  Gauss-Markov correlation.
