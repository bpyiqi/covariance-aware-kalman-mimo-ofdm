function result=auditCovarianceAwareSnrPairedLocalization20(root,varargin)
%AUDITCOVARIANCEAWARESNRPAIREDLOCALIZATION20 Dry-run, formal run, or resume.
parser=inputParser;parser.addParameter('dryRun',true,@(x)islogical(x)&&isscalar(x));
parser.addParameter('resume',false,@(x)islogical(x)&&isscalar(x));parser.parse(varargin{:});o=parser.Results;
cfg=auditCovarianceAwareSnrPairedLocalization20Config(root);formal=cfg.outputDirectory;
if ~o.dryRun
    if ~o.resume,assert(exist(formal,'dir')~=7,'Refusing to overwrite formal output: %s',formal);end
    result=auditCovarianceAwareSnrPairedLocalization20RunCore(cfg,formal,resume=o.resume,testMode=false);return;
end
schema=auditCovarianceAwareSnrPairedLocalization20Schema();existed=exist(formal,'dir')==7;
temporary=[tempname '_paired_localization20_dryrun'];mkdir(temporary);cleanup=onCleanup(@()rmdir(temporary,'s'));
mapping={"packetLevel",schema.files.packetLevel;"summary",schema.files.summary;"brackets",schema.files.brackets; ...
"trends",schema.files.trends;"rawWarnings",schema.files.rawWarnings;"crossSnr",schema.files.crossSnr};
for i=1:size(mapping,1),names=schema.(mapping{i,1});writetable(array2table(zeros(0,numel(names)),'VariableNames',cellstr(names)),fullfile(temporary,mapping{i,2}));end
assert((exist(formal,'dir')==7)==existed,'Dry-run changed formal output.');
expected=numel(cfg.SNRdBGrid)*cfg.scenarioCount*numel(cfg.methods);
result=struct('dryRun',true,'expectedRows',expected,'randomScenarioCount',0,'masterSeedConsumed',false, ...
'formalOutputDirectory',formal,'temporaryCleanedAfterReturn',true);
fprintf('paired localization20 dry-run PASS: expectedRows=%d, randomScenarioCount=0, masterSeedConsumed=false.\n',expected);
end

