function cfg=auditEpVariancePostprocessV2Config(root)
%AUDITEPVARIANCEPOSTPROCESSV2CONFIG Read-only replay45 postprocessing contract.
cfg=struct();cfg.root=root;cfg.experimentName="decoder_confidence_ep_variance_replay45_postprocess_v2";
cfg.sourceDirectory=fullfile(root,'results_three_layer_validation','decoder_confidence_ep_variance_replay45_v1');
cfg.outputDirectory=fullfile(root,'results_three_layer_validation',char(cfg.experimentName));cfg.maxExtremePerReceiverLayer=500;
end
