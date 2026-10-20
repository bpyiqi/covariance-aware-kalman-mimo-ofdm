function cfg = auditCovarianceAwareFinalValidation50Config(root)
%AUDITCOVARIANCEAWAREFINALVALIDATION50CONFIG Frozen independent validation plan.
cfg=auditQualityAwareDefaultConfig(root);cfg.root=root;cfg.validationSeed=20260721;cfg.bootstrapSeed=2026072101;cfg.packetCountPerCondition=50;cfg.fixedRadius=3;
cfg.experimentName="covariance_aware_final_validation50";cfg.schemaVersion="2.0";cfg.bootstrapCount=10000;cfg.developmentSeed=20260720;
cfg.methods=["BaseKalmanCausal_EP","FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP","OJCD_LMMSE_EP_Adapted","OracleDataAidedCausal_EP","PerfectCSI_EP"];
cfg.outputDirectory=fullfile(root,'results_three_layer_validation','covariance_aware_final_validation50_seed20260721');
end
