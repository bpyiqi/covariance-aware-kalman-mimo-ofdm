function result=auditDecoderConfidenceCalibrationDev12(root,varargin)
%AUDITDECODERCONFIDENCECALIBRATIONDEV12 Dry-run, formal run, or resume.
parser=inputParser;parser.addParameter('dryRun',true,@(x)islogical(x)&&isscalar(x));parser.addParameter('resume',false,@(x)islogical(x)&&isscalar(x));parser.parse(varargin{:});o=parser.Results;
cfg=auditDecoderConfidenceCalibrationConfig(root);formal=cfg.outputDirectory;
if ~o.dryRun
    if ~o.resume,assert(exist(formal,'dir')~=7,'Refusing to overwrite formal calibration output: %s',formal);end
    result=auditDecoderConfidenceCalibrationRunCore(cfg,formal,resume=o.resume,testMode=false);return;
end
existed=exist(formal,'dir')==7;expected=cfg.scenarioCount*numel(cfg.SNRdBGrid)*numel(cfg.methods);
assert(isequal(cfg.calibrationScenarios,1:8)&&isequal(cfg.holdoutScenarios,9:12));
assert((exist(formal,'dir')==7)==existed);
result=struct('dryRun',true,'expectedReceiverRows',expected,'randomScenarioCount',0,'masterSeedConsumed',false,'formalOutputDirectory',formal);
fprintf('decoder-confidence dev12 dry-run PASS: expectedReceiverRows=%d, randomScenarioCount=0, masterSeedConsumed=false.\n',expected);
end

