function cfg=auditRawClipConfig(root)
%AUDITRAWCLIPCONFIG Preregistered raw-LLR clipping development configuration.
cfg=struct();cfg.root=root;cfg.experimentName="decoder_confidence_raw_clipping_dev12_v1";
cfg.sourceDirectory=fullfile(root,'results_three_layer_validation', ...
    'decoder_confidence_temperature_calibration_dev12_seed20260726');
cfg.outputDirectory=fullfile(root,'results_three_layer_validation',char(cfg.experimentName));
cfg.clipGrid=[5 7.5 10 15 20 30 40 60 80 120 Inf];
cfg.calibrationScenarios=1:8;cfg.holdoutScenarios=9:12;
cfg.bootstrapSeed=2026072701;cfg.bootstrapCount=2000;cfg.methodNllTolerance=0.01;
cfg.methods=["BaseKalmanCausal_EP","FixedRadius3Causal_EP", ...
    "CovarianceAwareLocalDAKalmanCausal_EP","OJCD_LMMSE_EP_Adapted","PerfectCSI_EP"];
cfg.decoderIterations=50;cfg.enableTanhDiagnostic=true;
end
