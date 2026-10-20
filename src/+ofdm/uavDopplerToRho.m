function rho = uavDopplerToRho(doppler_hz, symbol_time_s)
%UAVDOPPLERTORHO Map Doppler frequency to Gauss-Markov rho per OFDM symbol.
%
% The mapping uses the Jakes autocorrelation approximation
%   rho = |J0(2*pi*fd*Ts)|
% where fd is the maximum Doppler shift and Ts is the OFDM symbol period.

if nargin < 2
    error('uavDopplerToRho requires doppler_hz and symbol_time_s.');
end
if ~isscalar(doppler_hz) || ~isscalar(symbol_time_s)
    error('doppler_hz and symbol_time_s must be scalars.');
end
if doppler_hz < 0 || symbol_time_s <= 0
    error('doppler_hz must be nonnegative and symbol_time_s must be positive.');
end

rho = abs(besselj(0, 2*pi*doppler_hz*symbol_time_s));
rho = min(max(rho, 0), 0.9999999);
end
