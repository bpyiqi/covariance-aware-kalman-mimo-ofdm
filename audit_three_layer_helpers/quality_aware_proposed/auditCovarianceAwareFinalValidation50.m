function result = auditCovarianceAwareFinalValidation50(root,varargin)
%AUDITCOVARIANCEAWAREFINALVALIDATION50 Frozen independent validation entry.
parser=inputParser;parser.addParameter('dryRun',true,@(x)islogical(x)&&isscalar(x));parser.addParameter('resume',false,@(x)islogical(x)&&isscalar(x));parser.parse(varargin{:});options=parser.Results;
cfg=auditCovarianceAwareFinalValidation50Config(root);formal=cfg.outputDirectory;
if ~options.dryRun
    if ~options.resume,assert(~exist(formal,'dir'),'Refusing to overwrite existing formal output directory: %s',formal);end
    fprintf('validation seed=%d; bootstrap seed=%d; payloadSymbols=[%s]; packetCountPerCondition=%d\n',cfg.validationSeed,cfg.bootstrapSeed,num2str(cfg.Npayload),cfg.packetCountPerCondition);
    fprintf('methods=%s\nexpectedPacketRows=%d\nformalOutputDirectory=%s\nparameters are frozen and this is not a tuning run\n',strjoin(cfg.methods,', '),2*cfg.packetCountPerCondition*numel(cfg.methods),formal);
    result=auditCovarianceAwareFinalValidation50RunCore(cfg,formal,resume=options.resume,testMode=false);return;
end
schema=auditCovarianceAwareFinalValidation50Schema();formalExisted=exist(formal,'dir')==7;
temporary=[tempname '_covariance_aware_validation50_dryrun'];mkdir(temporary);cleanup=onCleanup(@()rmdir(temporary,'s'));
localManifest(fullfile(temporary,schema.files.manifest));
localWriteEmptySchemas(temporary,schema);
names=struct2cell(schema.files);assert(all(isfile(fullfile(temporary,string(names(1:10))))),'Dry-run did not create every required schema file.');
assert((exist(formal,'dir')==7)==formalExisted,'Dry-run changed the formal output directory.');
result=struct('dryRun',true,'randomPhysicalPacketCount',0,'methodCount',numel(cfg.methods), ...
    'expectedPacketRows',2*cfg.packetCountPerCondition*numel(cfg.methods),'outputDirectory',temporary, ...
    'formalOutputDirectory',formal,'temporaryCleanedAfterReturn',true,'schemaFileCount',numel(fieldnames(schema.files)));
fprintf('validation50 dry-run PASS: methods=%d, expectedPacketRows=%d, randomPhysicalPacketCount=0.\n',result.methodCount,result.expectedPacketRows);
end

function localManifest(path)
file=fopen(path,'w','n','UTF-8');cleanup=onCleanup(@()fclose(file));
fprintf(file,['method=CovarianceAwareLocalDAKalmanCausal_EP\n' ...
    'description=Covariance-aware local-LS data-aided causal Kalman channel tracking\n' ...
    'aliasOf=FixedRadius3LsCovOnlyCausal_EP\nfixedRadius=3\ncandidateSet=[1 2 3]\n' ...
    'developmentDirectory=quality_aware_proposed_diagnostic20_seed20260720\ndevelopmentSeed=20260720\nvalidationSeed=20260721\n' ...
    'llrThreshold=2.5\nminEffectiveSamples=2\ngramRcondThreshold=1e-3\nRDA=RLS\n' ...
    'stateOrder=Re(H11),Re(H21),Re(H12),Re(H22),Im(H11),Im(H21),Im(H12),Im(H22)\n' ...
    'complexCovarianceVectorOrder=H11,H21,H12,H22\ncomplexCovarianceTranspose=nonconjugate\n' ...
    'realCovarianceMapping=0.5*[Re(C),-Im(C);Im(C),Re(C)]\neigenFloor=frozen_absolute_relative_floor\n' ...
    'NIS=false\nalpha_nis=false\nalpha_dec=false\ndynamicRadius=false\nJoseph=true\n' ...
    'paddingExcluded=true\ncausalFrozenPilotSeed=true\nnoSameSymbolFeedback=true\nmaxDaUpdatesPerTarget=1\n' ...
    'infeasibleCandidateFallback=exact_pilot_posterior\n']);
end

function localWriteEmptySchemas(directory,schema)
mapping={"packetLevel",schema.files.packetLevel;"summary",schema.files.summary;"pairedStatistics",schema.files.pairedStatistics; ...
    "bootstrapCi",schema.files.bootstrapCi;"pairingHashes",schema.files.pairingHashes;"detectionAlignment",schema.files.detectionAlignment; ...
    "rdaAudit",schema.files.rdaAudit;"runtimeAudit",schema.files.runtimeAudit};
for i=1:size(mapping,1)
    names=schema.(mapping{i,1});
    writetable(array2table(zeros(0,numel(names)),'VariableNames',cellstr(names)),fullfile(directory,mapping{i,2}));
end
fclose(fopen(fullfile(directory,schema.files.report),'w'));
end
