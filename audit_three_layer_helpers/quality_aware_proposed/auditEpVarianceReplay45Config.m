function cfg=auditEpVarianceReplay45Config(root)
%AUDITEPVARIANCEREPLAY45CONFIG Frozen-dev12 scenario replay configuration.
cfg=auditDecoderConfidenceCalibrationConfig(root);cfg.experimentName="decoder_confidence_ep_variance_replay45_v1";
cfg.sourceDirectory=fullfile(root,'results_three_layer_validation','decoder_confidence_temperature_calibration_dev12_seed20260726');
cfg.scenarioIndices=[1 2 3];cfg.SNRdBGrid=[18 24 30];cfg.methods=["BaseKalmanCausal_EP","FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP","OJCD_LMMSE_EP_Adapted","PerfectCSI_EP"];
cfg.outputDirectory=fullfile(root,'results_three_layer_validation',char(cfg.experimentName));
end
