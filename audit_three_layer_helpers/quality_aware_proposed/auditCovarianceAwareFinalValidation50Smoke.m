function result=auditCovarianceAwareFinalValidation50Smoke(root)
%AUDITCOVARIANCEAWAREFINALVALIDATION50SMOKE One deterministic paired packet.
cfg=auditCovarianceAwareFinalValidation50Config(root);cfg.validationSeed=20260722;cfg.packetCountPerCondition=1;cfg.Ncodeword=1;cfg.Npayload=cfg.symbolsPerCodeword;
temporary=[tempname '_covariance_aware_validation50_smoke'];mkdir(temporary);cleanup=onCleanup(@()rmdir(temporary,'s'));
result=auditCovarianceAwareFinalValidation50RunCore(cfg,temporary,testMode=true);
assert(height(result.packetTable)==6,'One-packet smoke must produce six method rows.');
assert(all(result.packetTable.sharedHashH==result.packetTable.sharedHashH(1)),'Smoke pairing hash mismatch.');
schema=auditCovarianceAwareFinalValidation50Schema();names=struct2cell(schema.files);assert(all(isfile(fullfile(temporary,string(names)))),'Artifact smoke is missing output files.');s=load(fullfile(temporary,schema.files.checkpoint),'status');assert(string(s.status)=="complete");
paired=readtable(fullfile(temporary,schema.files.pairedStatistics),'TextType','string');bootstrap=readtable(fullfile(temporary,schema.files.bootstrapCi),'TextType','string');assert(~isempty(paired)&&~isempty(bootstrap)&&all(paired.payloadSymbols==cfg.Npayload));tiny=auditPairedBootstrapCi([1;-1;2;-2],2026072201,100);tiny2=auditPairedBootstrapCi([1;-1;2;-2],2026072201,100);assert(isequaln(tiny,tiny2));fprintf('validation50 paired/bootstrap tiny test PASS: pairedRows=%d bootstrapRows=%d.\n',height(paired),height(bootstrap));
fprintf('validation50 deterministic one-packet smoke PASS: rows=6, random seed=%d.\n',cfg.validationSeed);
end
