function llr = qam16DemodLlr(symbols, noise_var)
%QAM16DEMODLLR 16QAM soft LLR demodulation with finite-value cleanup.

llr = qamdemod(symbols, 16, 'UnitAveragePower', true, ...
    'OutputType', 'llr', 'NoiseVariance', noise_var);
llr(isnan(llr)) = 0;
llr(isinf(llr)) = sign(llr(isinf(llr))) * 99;
end

