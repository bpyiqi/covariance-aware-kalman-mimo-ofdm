function cfg=auditEpReliabilityConfig(root)
%AUDITEPRELIABILITYCONFIG Read-only EP soft-information reliability audit.
cfg=struct();cfg.root=root;cfg.experimentName="decoder_confidence_ep_reliability_audit_v1";
cfg.sourceDirectory=fullfile(root,'results_three_layer_validation','decoder_confidence_temperature_calibration_dev12_seed20260726');
cfg.outputDirectory=fullfile(root,'results_three_layer_validation',char(cfg.experimentName));
cfg.methods=["BaseKalmanCausal_EP","FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP","OJCD_LMMSE_EP_Adapted","PerfectCSI_EP"];
cfg.absLlrEdges=[0 1 2 3 5 10 20 40 80 160 Inf];
cfg.absLlrLabels=["[0,1)","[1,2)","[2,3)","[3,5)","[5,10)","[10,20)","[20,40)","[40,80)","[80,160)","[160,Inf)"];
cfg.calibrationBootstrapSeed=2026072801;cfg.calibrationBootstrapCount=500;
end
