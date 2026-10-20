function evidence = auditQualityAwareMiniPreflight(root,cfg,outputDirectory)
%AUDITQUALITYAWAREMINIPREFLIGHT Fail before any random physical packet.
reports={ ...
    fullfile(cfg.auditOutput,'quality_aware_proposed_selftest_report.txt'),'allTestsPassed=1'; ...
    fullfile(root,'results_three_layer_validation','causal_refactor_smoke','causal_two_stage_self_test_report.txt'),'allCausalSelfTestsPassed=1'; ...
    fullfile(root,'results_three_layer_validation','causal_refactor_smoke','integration_selftest','causal_integration_selftest_report.txt'),'causalIntegrationImplementationReady=1'; ...
    fullfile(root,'results_three_layer_validation','causal_refactor_smoke','padding_diagnostics_selftest','causal_padding_diagnostics_selftest_report.txt'),'causalPaddingDiagnosticsReady=1'; ...
    fullfile(root,'results_three_layer_validation','ojcd_baseline_implementation_audit','ojcd_baseline_selftest_report.txt'),'allTestsPassed=1'};
reportPass=true;for i=1:size(reports,1),reportPass=reportPass&&exist(reports{i,1},'file')==2&&contains(fileread(reports{i,1}),reports{i,2});end
assert(reportPass,'Mini preflight failed: one or more deterministic regression reports are missing or failed.');
ojcdText=fileread(reports{5,1});token=regexp(ojcdText,'relative ([0-9.eE+-]+)','tokens','once');assert(~isempty(token));relativeDifference=str2double(token{1});assert(relativeDifference<=1e-8,'MJCD/OJCD equivalence exceeds 1e-8.');
protected=localProtected(root);assert(all(protected.unchanged),'Protected-file SHA-256 mismatch.');
requiredFunctions={'auditQualityAwareMiniPacket','auditQualityAwareLegacyCausalEstimates','auditQualityAwareProposedCausalEstimates','auditQualityAwareMiniDecode','auditOjcdTwoLayerSymbol','auditEpDetectorOjcd'};
resolved=cellfun(@(name)exist(name,'file')==2,requiredFunctions);assert(all(resolved),'One or more Mini method entries cannot be resolved.');
assert(cfg.miniMasterSeed==20260719&&isequal(cfg.Ncodeword,[1 3])&&cfg.miniPacketCountPerCondition==5&&cfg.NFFT==64&&cfg.modulationOrder==16&&cfg.SNRdB==20&&cfg.fdHz==200,'Frozen Mini configuration drift.');
assert(cfg.symbolsPerCodeword==169&&isequal(cfg.Npayload,[169 507]),'Aligned LDPC payload mapping drift.');
assert(exist(cfg.covariancePath,'file')==2,'OJCD covariance cache is missing: %s',cfg.covariancePath);
packetPath=fullfile(outputDirectory,'quality_aware_mini_packet_level.csv');assert(exist(packetPath,'file')~=2,'Refusing to overwrite completed Mini output: %s. Choose a new outputDirectory.',packetPath);
evidence=struct('deterministicReportsPass',reportPass,'mjcdOjcdRelativeDifference',relativeDifference, ...
    'protectedHashesPass',all(protected.unchanged),'methodEntriesResolvable',all(resolved), ...
    'outputCollisionFree',true,'configurationPass',true,'protectedTable',protected);
end

function T=localProtected(root)
paths={fullfile(root,'Compare_LongPayload_VideoLink_Kalman.m');fullfile(root,'Exp_ProblemExistence_CSI_Aging.m');fullfile(root,'Audit_ProblemExistence_CSI_Aging.m')};expected={'2047d3bc2f551b79975b1b0da545f5d237ae888e466751ded1a688e333f386bc';'e79ffdb32c006d15ccaf9783459ef626b8fd6f3b7fb6635ad0fc3ece271eb4d9';'c47be923f41fc66f902d98b09a8df6958e5c7fe13f26ff4be68e6098a65aece6'};actual=cellfun(@localSha,paths,'UniformOutput',false);unchanged=strcmpi(expected,actual);T=table(string(paths),string(expected),string(actual),unchanged,'VariableNames',{'file','expectedSha256','actualSha256','unchanged'});
end
function value=localSha(path),f=fopen(path,'rb');assert(f>=0);cleanup=onCleanup(@()fclose(f));bytes=fread(f,inf,'*uint8');md=java.security.MessageDigest.getInstance('SHA-256');md.update(typecast(bytes,'int8'));value=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));end
