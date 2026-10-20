function result=auditDecoderConfidenceCalibrationRunCore(cfg,out,options)
%AUDITDECODERCONFIDENCECALIBRATIONRUNCORE Scenario-atomic receiver/chunk executor.
arguments,cfg struct,out (1,:) char,options.resume (1,1) logical=false,options.stopAfterScenarios (1,1) double=inf,options.testMode (1,1) logical=false,end
schema=auditDecoderConfidenceCalibrationSchema();checkpoint=fullfile(out,schema.files.checkpoint);
[T,completed,chunkPaths,chunkHashes]=localStart(out,checkpoint,cfg,schema,options.resume);done=numel(completed);
chunkDir=fullfile(out,'raw_llr_chunks');if exist(chunkDir,'dir')~=7,mkdir(chunkDir);end
for scenarioIndex=1:cfg.scenarioCount
    if ismember(scenarioIndex,completed),continue;end
    [scenarioRows,chunk]=auditDecoderConfidenceRunScenario(cfg,scenarioIndex);
    path=fullfile(chunkDir,sprintf('scenario_%02d.mat',scenarioIndex));tmp=[path '.tmp'];
    save(tmp,'chunk','-v7.3');[ok,msg]=movefile(tmp,path,'f');assert(ok,'Chunk atomic write failed: %s',msg);
    loaded=load(path,'chunk');assert(loaded.chunk.scenarioIndex==scenarioIndex&&numel(loaded.chunk.records)==numel(cfg.SNRdBGrid)*numel(cfg.methods));
    hash=localSha(path);T=[T;scenarioRows];completed=[completed;scenarioIndex];chunkPaths=[chunkPaths;string(path)];chunkHashes=[chunkHashes;string(hash)];done=done+1; %#ok<AGROW>
    localSave(checkpoint,cfg,schema,T,completed,chunkPaths,chunkHashes,"running",scenarioIndex);
    fprintf('decoder-confidence checkpoint: scenario=%d rows=%d chunkHash=%s\n',scenarioIndex,height(T),hash);
    if done>=options.stopAfterScenarios,result=struct('status',"interrupted_for_test",'receiverRows',T,'completedScenarios',completed,'outputDirectory',out);return;end
end
if options.testMode,artifacts=struct();else,artifacts=auditDecoderConfidenceCalibrationFinalize(cfg,out,T,chunkPaths,chunkHashes);end
localSave(checkpoint,cfg,schema,T,completed,chunkPaths,chunkHashes,"complete",completed(end));
if ~options.testMode,f=fopen(fullfile(out,schema.files.complete),'w');assert(f>=0);fprintf(f,'complete\n');fclose(f);end
result=struct('status',"complete",'receiverRows',T,'completedScenarios',completed,'artifacts',artifacts,'outputDirectory',out);
end
function [T,completed,paths,hashes]=localStart(out,path,cfg,schema,resume)
nonempty=false;if exist(out,'dir')==7,e=dir(out);nonempty=any(~ismember({e.name},{'.','..'}));end
if nonempty
    assert(resume,'Refusing to overwrite nonempty output: %s',out);assert(isfile(path));s=load(path);localCheck(s,cfg,schema);
    T=s.receiverRows;completed=s.completedScenarios;paths=s.chunkPaths;hashes=s.chunkHashes;
else
    assert(~resume,'Resume requested without checkpoint.');if exist(out,'dir')~=7,mkdir(out);end
    T=cell2table(cell(0,numel(schema.receiverRows)),'VariableNames',cellstr(schema.receiverRows));completed=zeros(0,1);paths=strings(0,1);hashes=strings(0,1);
end
end
function localCheck(s,cfg,schema)
assert(s.masterSeed==cfg.masterSeed&&s.bootstrapSeed==cfg.bootstrapSeed&&isequal(s.methods,cfg.methods)&&isequal(s.SNRdBGrid,cfg.SNRdBGrid)&& ...
s.scenarioCount==cfg.scenarioCount&&isequal(s.calibrationScenarios,cfg.calibrationScenarios)&&isequal(s.holdoutScenarios,cfg.holdoutScenarios)&&string(s.schemaVersion)==schema.version);
assert(string(s.status)~="complete");for i=1:numel(s.chunkPaths),assert(isfile(s.chunkPaths(i))&&localSha(s.chunkPaths(i))==s.chunkHashes(i));end
end
function localSave(path,cfg,schema,receiverRows,completedScenarios,chunkPaths,chunkHashes,status,lastScenario)
tmp=[char(path) '.tmp'];masterSeed=cfg.masterSeed;bootstrapSeed=cfg.bootstrapSeed;methods=cfg.methods;SNRdBGrid=cfg.SNRdBGrid;scenarioCount=cfg.scenarioCount;
calibrationScenarios=cfg.calibrationScenarios;holdoutScenarios=cfg.holdoutScenarios;schemaVersion=schema.version;scenarioSeeds=arrayfun(@(i)auditPairedSnrScenarioSeed(cfg.masterSeed,i),(1:cfg.scenarioCount).');
save(tmp,'cfg','masterSeed','bootstrapSeed','methods','SNRdBGrid','scenarioCount','calibrationScenarios','holdoutScenarios','schemaVersion','receiverRows','completedScenarios','chunkPaths','chunkHashes','scenarioSeeds','status','lastScenario','-v7.3');
[ok,msg]=movefile(tmp,path,'f');assert(ok,'Checkpoint atomic write failed: %s',msg);
end
function h=localSha(path),f=fopen(path,'rb');assert(f>=0);c=onCleanup(@()fclose(f));bytes=fread(f,inf,'*uint8');md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);h=string(lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[])));end

