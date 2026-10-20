function result=auditCovarianceAwareSnrLocalization10(root,varargin)
%AUDITCOVARIANCEAWARESNRLOCALIZATION10 Dry-run, formal run, or resume entry.
parser=inputParser;parser.addParameter('dryRun',true,@(x)islogical(x)&&isscalar(x));
parser.addParameter('resume',false,@(x)islogical(x)&&isscalar(x));parser.parse(varargin{:});options=parser.Results;
cfg=auditCovarianceAwareSnrLocalization10Config(root);formal=cfg.outputDirectory;
if ~options.dryRun
    if ~options.resume,assert(exist(formal,'dir')~=7,'Refusing to overwrite existing formal output directory: %s',formal);end
    fprintf('SNR localization formal execution requested: masterSeed=%d, expectedRows=%d, resume=%d.\n', ...
        cfg.masterSeed,numel(cfg.SNRdBGrid)*cfg.packetCountPerSnr*numel(cfg.methods),options.resume);
    result=auditCovarianceAwareSnrLocalization10RunCore(cfg,formal,resume=options.resume,testMode=false);
    return;
end
schema=auditCovarianceAwareSnrLocalization10Schema();formalExisted=exist(formal,'dir')==7;
temporary=[tempname '_snr_localization10_dryrun'];mkdir(temporary);cleanup=onCleanup(@()rmdir(temporary,'s'));
localWriteEmptySchemas(temporary,schema);localWriteManifest(temporary,cfg,schema);
assert(exist(formal,'dir')==formalExisted,'Dry-run changed the formal output directory.');
seeds=arrayfun(@(x)auditCovarianceAwareSnrConditionSeed(cfg.masterSeed,x),cfg.SNRdBGrid);
assert(numel(unique(seeds))==numel(seeds),'SNR condition seeds are not unique.');
expected=numel(cfg.SNRdBGrid)*cfg.packetCountPerSnr*numel(cfg.methods);
result=struct('dryRun',true,'randomPhysicalPacketCount',0,'expectedPacketRows',expected, ...
    'methodCount',numel(cfg.methods),'snrPointCount',numel(cfg.SNRdBGrid),'formalOutputDirectory',formal, ...
    'masterSeedConsumed',false,'temporaryCleanedAfterReturn',true);
fprintf('SNR localization10 dry-run PASS: SNR points=%d, methods=%d, expectedPacketRows=%d, randomPhysicalPacketCount=0, masterSeedConsumed=false.\n', ...
    numel(cfg.SNRdBGrid),numel(cfg.methods),expected);
end

function localWriteEmptySchemas(out,schema)
mapping={"packetLevel",schema.files.packetLevel;"summary",schema.files.summary;"brackets",schema.files.brackets;"pairing",schema.files.pairing};
for i=1:size(mapping,1),names=schema.(mapping{i,1});writetable(array2table(zeros(0,numel(names)),'VariableNames',cellstr(names)),fullfile(out,mapping{i,2}));end
fclose(fopen(fullfile(out,schema.files.report),'w'));fclose(fopen(fullfile(out,schema.files.runtime),'w'));fclose(fopen(fullfile(out,schema.files.config),'w'));
end

function localWriteManifest(out,cfg,schema)
f=fopen(fullfile(out,schema.files.manifest),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fprintf(f,'experimentName=%s\nschemaVersion=%s\nmasterSeed=%d\nbootstrapSeed=%d\nsmokeSeed=%d\nSNRdBGrid=%s\npayloadSymbols=%d\nnCodeword=%d\npacketCountPerSnr=%d\nmethods=%s\nseedFormula=masterSeed+10000*round(10*SNRdB)+packetIndex\n', ...
    cfg.experimentName,schema.version,cfg.masterSeed,cfg.bootstrapSeed,cfg.smokeSeed,mat2str(cfg.SNRdBGrid), ...
    cfg.Npayload,cfg.Ncodeword,cfg.packetCountPerSnr,strjoin(cfg.methods,','));
end

