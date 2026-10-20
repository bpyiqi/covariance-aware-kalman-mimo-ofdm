function cfg=auditEpVarianceMechanismSummaryConfig(root)
%AUDITEPVARIANCEMECHANISMSUMMARYCONFIG Immutable input/output locations.
cfg.root=root;
cfg.experimentName="decoder_confidence_ep_variance_mechanism_summary_v1";
cfg.v2Directory=fullfile(root,'results_three_layer_validation','decoder_confidence_ep_variance_replay45_postprocess_v2');
cfg.v1Directory=fullfile(root,'results_three_layer_validation','decoder_confidence_ep_variance_replay45_v1');
cfg.outputDirectory=fullfile(root,'results_three_layer_validation',char(cfg.experimentName));
cfg.finalMethods=["BaseKalmanCausal_EP","FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP","OJCD_LMMSE_EP_Adapted","PerfectCSI_EP"];
end
