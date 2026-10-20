function results=auditCovarianceAwareFinalResumeSelftest(root)
%AUDITCOVARIANCEAWAREFINALRESUMESELFTEST Deterministic checkpoint tests.
cfg=auditCovarianceAwareFinalValidation50Config(root);cfg.validationSeed=20260723;cfg.bootstrapSeed=2026072301;cfg.bootstrapCount=100;cfg.packetCountPerCondition=2;cfg.Ncodeword=1;cfg.Npayload=cfg.symbolsPerCodeword;
resumeDir=[tempname '_validation50_resume'];directDir=[tempname '_validation50_direct'];refusalDir=[tempname '_validation50_refusal'];cleanup=onCleanup(@()localCleanup({resumeDir,directDir,refusalDir}));
first=auditCovarianceAwareFinalValidation50RunCore(cfg,resumeDir,stopAfterPackets=1,testMode=true);schema=auditCovarianceAwareFinalValidation50Schema();results.interrupted=first.status=="interrupted_for_test"&&exist(fullfile(resumeDir,schema.files.checkpoint),'file')==2&&exist(fullfile(resumeDir,schema.files.complete),'file')~=2;
resumed=auditCovarianceAwareFinalValidation50RunCore(cfg,resumeDir,resume=true,testMode=true);direct=auditCovarianceAwareFinalValidation50RunCore(cfg,directDir,testMode=true);deterministic=setdiff(string(resumed.packetTable.Properties.VariableNames),"processingTimeSec");results.noDuplicateRows=height(unique(resumed.packetTable(:,{'payloadSymbols','packetIndex','method'}),'rows'))==height(resumed.packetTable);results.resumeEqualsDirect=isequaln(resumed.packetTable(:,cellstr(deterministic)),direct.packetTable(:,cellstr(deterministic)));results.complete=exist(fullfile(resumeDir,schema.files.complete),'file')==2;
mkdir(refusalDir);sentinel=fullfile(refusalDir,'sentinel.txt');f=fopen(sentinel,'w');fprintf(f,'keep');fclose(f);failed=false;
try
    auditCovarianceAwareFinalValidation50RunCore(cfg,refusalDir,testMode=true);
catch
    failed=true;
end
results.overwriteRefused=failed&&strcmp(strtrim(fileread(sentinel)),'keep');
assert(all(structfun(@logical,results)),'Validation50 resume self-test failed.');fprintf('validation50 checkpoint/resume self-test PASS: %d/%d; seed=%d.\n',numel(fieldnames(results)),numel(fieldnames(results)),cfg.validationSeed);
end
function localCleanup(paths),for i=1:numel(paths),if exist(paths{i},'dir'),rmdir(paths{i},'s');end,end,end
