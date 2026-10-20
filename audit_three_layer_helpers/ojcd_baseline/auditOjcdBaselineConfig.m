function cfg = auditOjcdBaselineConfig(root)
%AUDITOJCDBASELINECONFIG Fixed configuration for the audited 2x2 adaptation.
cfg=struct(); cfg.root=root; cfg.NFFT=64; cfg.NCP=16; cfg.Fs=20e6;
cfg.Tsym=(cfg.NFFT+cfg.NCP)/cfg.Fs; cfg.active=[7:32 34:59];
cfg.pilots=[12 26 40 54]; cfg.pilotValues=[1 1 1 -1];
cfg.pilotTransmitStreamMap=[1 2 1 2]; cfg.data=setdiff(cfg.active,cfg.pilots);
cfg.NT=2; cfg.NR=2; cfg.modulationOrder=16; cfg.bitsPerQam=4;
cfg.epIterations=5; cfg.epBeta=.2; cfg.snrDb=20; cfg.fdHz=200;
cfg.noiseVar=10^(-cfg.snrDb/10); cfg.rho=ofdm.uavDopplerToRho(cfg.fdHz,cfg.Tsym);
cfg.covarianceSeed=20260720; cfg.covarianceSnapshots=500;
cfg.ojcdMiniMasterSeed=20260721; cfg.NpacketPerCondition=5;
cfg.ldpc=ofdm.makeLdpcConfig(1/2);
cfg.codedBitsPerOFDMSymbol=numel(cfg.data)*cfg.NT*cfg.bitsPerQam;
cfg.symbolsPerCodeword=ceil(cfg.ldpc.N/cfg.codedBitsPerOFDMSymbol);
cfg.Ncodeword=[1 3]; cfg.Npayload=cfg.symbolsPerCodeword*cfg.Ncodeword;
cfg.covariancePath=fullfile(root,'results_three_layer_validation', ...
    'ojcd_covariance_cache','ojcd_frequency_covariance.mat');
cfg.auditOutput=fullfile(root,'results_three_layer_validation', ...
    'ojcd_baseline_implementation_audit');
cfg.miniOutput=fullfile(root,'results_three_layer_validation', ...
    'ojcd_baseline_mini_seed20260721');
cfg.methodDisplayName='OJCD-LMMSE-EP-Adapted-2x2';
end
