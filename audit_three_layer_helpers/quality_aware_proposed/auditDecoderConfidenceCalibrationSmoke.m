function result=auditDecoderConfidenceCalibrationSmoke(root)
%AUDITDECODERCONFIDENCECALIBRATIONSMOKE Ten-row raw-LLR artifact smoke.
cfg=auditDecoderConfidenceCalibrationConfig(root);cfg.masterSeed=cfg.smokeSeed;
cfg.SNRdBGrid=[20 26];cfg.scenarioCount=1;cfg.calibrationScenarios=1;cfg.holdoutScenarios=[];
out=fullfile(tempdir,sprintf('decoder_confidence_smoke_%d',feature('getpid')));
cleanup=onCleanup(@()localRemove(out));
[rows,chunk]=auditDecoderConfidenceRunScenario(cfg,1);
assert(height(rows)==10&&numel(chunk.records)==10);
assert(all(rows.rawUsefulLlrCount==3*cfg.ldpc.N)&&~any(rows.hasNaN|rows.hasInf));
for i=1:numel(chunk.records)
    raw=double(chunk.records{i}.rawUsefulLlr);truth=double(chunk.codedBits);
    margin=(1-2*truth).*raw;loss=mean(auditStableSoftplus(-margin));
    assert(isfinite(loss)&&isequal(raw<0,0.25*raw<0));
end
if exist(out,'dir')~=7,mkdir(out);end
path=fullfile(out,'scenario_01.mat');save(path,'chunk','-v7.3');loaded=load(path,'chunk');
assert(numel(loaded.chunk.records)==10&&isequal(loaded.chunk.codedBits,chunk.codedBits));
raw=double(chunk.records{1}.rawUsefulLlr(1:cfg.ldpc.N));
decodedRaw=ldpcDecode(raw,cfg.ldpc.dec,50,'DecisionType','hard');
decodedUnit=ldpcDecode(1*raw,cfg.ldpc.dec,50,'DecisionType','hard');
assert(isequal(decodedRaw,decodedUnit));
result=struct('passed',true,'receiverRows',height(rows),'randomScenarioCount',1, ...
    'seed',cfg.smokeSeed,'temporaryArtifactsCleanedOnReturn',true);
fprintf('decoder-confidence artifact smoke PASS: rows=10 seed=%d raw LLR/loss/hard-bit/decoder/chunk checks passed.\n',cfg.smokeSeed);
end
function localRemove(path)
if exist(path,'dir')==7,rmdir(path,'s');end
end
