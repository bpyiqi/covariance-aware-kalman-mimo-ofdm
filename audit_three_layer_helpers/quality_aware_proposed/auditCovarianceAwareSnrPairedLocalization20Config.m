function cfg=auditCovarianceAwareSnrPairedLocalization20Config(root)
%AUDITCOVARIANCEAWARESNRPAIREDLOCALIZATION20CONFIG Frozen CRN localization design.
cfg=auditQualityAwareDefaultConfig(root);cfg.root=root;cfg.experimentName="covariance_aware_snr_paired_localization20";
cfg.schemaVersion="1.0";cfg.masterSeed=20260725;cfg.bootstrapSeed=2026072501;cfg.smokeSeed=2026072502;
cfg.SNRdBGrid=[18 20 22 24 26 28 30];cfg.fdHz=200;cfg.rho=ofdm.uavDopplerToRho(cfg.fdHz,cfg.Tsym);
cfg.scenarioCount=20;cfg.Ncodeword=3;cfg.Npayload=cfg.symbolsPerCodeword*cfg.Ncodeword;cfg.fixedRadius=3;
cfg.methods=["BaseKalmanCausal_EP","FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP","OJCD_LMMSE_EP_Adapted","PerfectCSI_EP"];
cfg.outputDirectory=fullfile(root,'results_three_layer_validation','covariance_aware_snr_paired_localization20_seed20260725');
cfg.targetCodewordBler=.10;cfg.realizedSnrToleranceDb=.15;
end

