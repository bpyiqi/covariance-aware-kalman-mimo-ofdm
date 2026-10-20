function cfg=auditCovarianceAwareSnrLocalization10Config(root)
%AUDITCOVARIANCEAWARESNRLOCALIZATION10CONFIG Frozen coarse-SNR localization plan.
cfg=auditQualityAwareDefaultConfig(root);cfg.root=root;cfg.experimentName="covariance_aware_snr_localization10";
cfg.schemaVersion="1.0";cfg.masterSeed=20260724;cfg.bootstrapSeed=2026072401;cfg.smokeSeed=2026072402;
cfg.SNRdBGrid=[16 18 20 22 24 26 28];cfg.fdHz=200;cfg.rho=ofdm.uavDopplerToRho(cfg.fdHz,cfg.Tsym);
cfg.packetCountPerSnr=10;cfg.Ncodeword=3;cfg.Npayload=cfg.symbolsPerCodeword*cfg.Ncodeword;cfg.fixedRadius=3;
cfg.methods=["BaseKalmanCausal_EP","FixedRadius3Causal_EP", ...
    "CovarianceAwareLocalDAKalmanCausal_EP","OJCD_LMMSE_EP_Adapted","PerfectCSI_EP"];
cfg.outputDirectory=fullfile(root,'results_three_layer_validation','covariance_aware_snr_localization10_seed20260724');
cfg.targetCodewordBler=.10;cfg.bootstrapCount=10000;
end

