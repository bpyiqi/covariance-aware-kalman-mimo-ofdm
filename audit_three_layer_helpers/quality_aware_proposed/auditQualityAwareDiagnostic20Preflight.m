function evidence = auditQualityAwareDiagnostic20Preflight(root,cfg,outputDirectory)
%AUDITQUALITYAWAREDIAGNOSTIC20PREFLIGHT Validate without random packets.
baseCfg=auditQualityAwareDefaultConfig(root);temporaryProbe=[tempname '_qa_preflight'];base=auditQualityAwareMiniPreflight(root,baseCfg,temporaryProbe);
assert(cfg.diagnosticMasterSeed==20260720&&cfg.diagnosticPacketCountPerCondition==20&&numel(cfg.diagnosticMethods)==11,'Diagnostic20 frozen configuration drift.');
assert(isequal(cfg.Npayload,[169 507])&&cfg.SNRdB==20&&cfg.fdHz==200,'Diagnostic20 physical configuration drift.');
resultPath=fullfile(outputDirectory,'quality_aware_diagnostic20_packet_level.csv');assert(exist(resultPath,'file')~=2,'Refusing to overwrite completed diagnostic20 output: %s. Choose a new outputDirectory.',resultPath);
evidence=base;evidence.diagnosticConfigurationPass=true;evidence.outputCollisionFree=true;
end
