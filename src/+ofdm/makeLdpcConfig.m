function cfg = makeLdpcConfig(rate)
%MAKELDPCCONFIG DVB-S2 LDPC encoder/decoder configuration bundle.

H = dvbs2ldpc(rate);
cfg.H = H;
cfg.enc = ldpcEncoderConfig(H);
cfg.dec = ldpcDecoderConfig(H);
cfg.K = cfg.enc.NumInformationBits;
cfg.N = cfg.enc.BlockLength;
cfg.rate = rate;
end

