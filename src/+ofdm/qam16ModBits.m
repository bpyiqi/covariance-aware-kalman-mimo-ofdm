function symbols = qam16ModBits(bits)
%QAM16MODBITS 16QAM bit-input modulation with unit average power.

symbols = qammod(bits, 16, 'InputType', 'bit', 'UnitAveragePower', true);
end

