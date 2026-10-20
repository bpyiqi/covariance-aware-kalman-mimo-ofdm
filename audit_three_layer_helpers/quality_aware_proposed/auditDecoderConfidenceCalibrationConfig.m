function cfg=auditDecoderConfidenceCalibrationConfig(root)
%AUDITDECODERCONFIDENCECALIBRATIONCONFIG Frozen decoder-confidence development plan.
cfg=auditCovarianceAwareSnrPairedLocalization20Config(root);cfg.experimentName="decoder_confidence_temperature_calibration_dev12";
cfg.schemaVersion="1.0";cfg.masterSeed=20260726;cfg.bootstrapSeed=2026072601;cfg.smokeSeed=2026072602;
cfg.SNRdBGrid=[18 20 22 24 26 28 30];cfg.scenarioCount=12;cfg.calibrationScenarios=1:8;cfg.holdoutScenarios=9:12;
cfg.betaBounds=[.01 2];cfg.bootstrapCount=2000;cfg.clipLevels=[10 20 40 Inf];cfg.methodNllMaxDegradation=.01;
cfg.outputDirectory=fullfile(root,'results_three_layer_validation','decoder_confidence_temperature_calibration_dev12_seed20260726');
end

