function results=auditCovarianceAwareSnrLocalization10ResumeSelftest(root)
%AUDITCOVARIANCEAWARESNRLOCALIZATION10RESUMESELFTEST Tiny checkpoint/resume and overwrite tests.
cfg=auditCovarianceAwareSnrLocalization10Config(root);cfg.masterSeed=2026072403;cfg.bootstrapSeed=2026072404;
cfg.SNRdBGrid=20;cfg.packetCountPerSnr=1;cfg.skipFiguresInTest=true;
resumeDir=[tempname '_snr_resume'];directDir=[tempname '_snr_direct'];refusalDir=[tempname '_snr_refusal'];
cleanup=onCleanup(@()localCleanup({resumeDir,directDir,refusalDir}));
first=auditCovarianceAwareSnrLocalization10RunCore(cfg,resumeDir,stopAfterPackets=1,testMode=true);
schema=auditCovarianceAwareSnrLocalization10Schema();
results.interrupted=first.status=="interrupted_for_test"&&isfile(fullfile(resumeDir,schema.files.checkpoint))&&~isfile(fullfile(resumeDir,schema.files.complete));
resumed=auditCovarianceAwareSnrLocalization10RunCore(cfg,resumeDir,resume=true,testMode=true);
direct=auditCovarianceAwareSnrLocalization10RunCore(cfg,directDir,testMode=true);
deterministic=setdiff(string(resumed.packetTable.Properties.VariableNames),"processingTimeSec");
results.resumeEqualsDirect=isequaln(resumed.packetTable(:,cellstr(deterministic)),direct.packetTable(:,cellstr(deterministic)));
results.noDuplicateRows=height(unique(resumed.packetTable(:,{'SNRdB','packetIndex','method'}),'rows'))==height(resumed.packetTable);
results.complete=isfile(fullfile(resumeDir,schema.files.complete));
mkdir(refusalDir);sentinel=fullfile(refusalDir,'sentinel.txt');f=fopen(sentinel,'w');fprintf(f,'keep');fclose(f);refused=false;
try
    auditCovarianceAwareSnrLocalization10RunCore(cfg,refusalDir,testMode=true);
catch
    refused=true;
end
results.overwriteRefused=refused&&strcmp(strtrim(fileread(sentinel)),'keep');
assert(all(structfun(@logical,results)),'SNR localization resume self-test failed.');
fprintf('SNR localization10 checkpoint/resume self-test PASS: 5/5; testSeed=%d; formal masterSeed not consumed.\n',cfg.masterSeed);
end
function localCleanup(paths),for i=1:numel(paths),if exist(paths{i},'dir'),rmdir(paths{i},'s');end,end,end
