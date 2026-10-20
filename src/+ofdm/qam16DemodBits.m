function bits = qam16DemodBits(symbols)
%QAM16DEMODBITS 16QAM hard bit demodulation with unit average power.

bits = qamdemod(symbols, 16, 'OutputType', 'bit', 'UnitAveragePower', true);
end

