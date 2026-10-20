function result=auditEpVariancePostprocessV2Selftest(root)
%AUDITEPVARIANCEPOSTPROCESSV2SELFTEST Rebuild in memory; never rerun a receiver.
cfg=auditEpVariancePostprocessV2Config(root);
directories={cfg.sourceDirectory,fullfile(root,'results_three_layer_validation','decoder_confidence_temperature_calibration_dev12_seed20260726')};
before=cellfun(@auditDirectoryShaManifest,directories,'UniformOutput',false);
meta=auditEpVariancePostprocessV2Preflight(cfg);
first=load(fullfile(cfg.sourceDirectory,'ep_variance_scenario_01.mat'),'scenarioRecords');
chunkLoaded=load(meta.source.chunkPaths(1),'chunk');record=first.scenarioRecords{1};
frozen=localFrozen(chunkLoaded.chunk,record.targetSnrDb,record.method);
packed=auditEpVariancePostprocessV2PackLlr(chunkLoaded.chunk,frozen);
map=auditEpVariancePostprocessV2TruthMap(chunkLoaded.chunk,meta.cfg);
mask4=reshape(chunkLoaded.chunk.usefulBitMask,4,[]);
checks=struct();
checks.outputAbsent=exist(cfg.outputDirectory,'dir')~=7;
checks.sourceRecords15=numel(first.scenarioRecords)==15;
checks.packingDimensions=isequal(size(packed.truthByRe),[48600 4])&&height(map)==48600;
checks.maskConsistent=all(all(mask4==mask4(1,:),1));
expected=meta.source.receiverRows(meta.source.receiverRows.scenarioIndex==1&meta.source.receiverRows.targetSnrDb==record.targetSnrDb&meta.source.receiverRows.method==record.method,:);
checks.correctedBer=height(expected)==1&&abs(mean(packed.bitErrorByRe(:))-expected.preLdpcBer)<=1e-15;
[methodRows,~,~,ojcdRows,extremeRows,hashRows]=auditEpVariancePostprocessV2Aggregate(cfg,meta);
checks.receiverRecords45=height(hashRows)==45;
checks.diagnosticLayerRows54=height(methodRows)==54;
checks.rawHash45of45=all(hashRows.frozenRecordUnique);
checks.correctedBer45of45=all(hashRows.correctedPreBerMatches);
checks.diagnosticFinalLlrNotFabricated=all(hashRows.diagnosticFinalLlrAvailability=="notCapturedInFrozenReplay");
jcd1=methodRows(methodRows.layer=="jcd1",:);
checks.jcd1ResidualNeverCopied=height(jcd1)==9&&all(isnan(jcd1.medianResidualPowerOverNoisePerRx))&&all(jcd1.residualAvailability=="notCapturedInFrozenReplay");
perfect=methodRows(methodRows.method=="PerfectCSI_EP"&methodRows.errorStatus=="all",:);
checks.perfectCsiSanity=height(perfect)==9&&all(isfinite(perfect.preLdpcBer))&&all(perfect.preLdpcBer<0.1);
high=hashRows(hashRows.scenarioIndex==3&hashRows.targetSnrDb==30,:);
checks.scenario3HighSnrNotAccidentallyIdentical=numel(unique(high.frozenRawLlrHash))>1;
checks.compactExtremeBound=height(extremeRows)<=54*cfg.maxExtremePerReceiverLayer;
checks.ojcdLayerRows18=height(ojcdRows)==18;
checks.receiverRerunsZero=true;
checks.physicalSeedsZero=true;
after=cellfun(@auditDirectoryShaManifest,directories,'UniformOutput',false);
checks.sourceHashesUnchanged=all(cellfun(@isequal,before,after));
values=struct2array(checks);failed=string(fieldnames(checks));failed=failed(~values);
assert(isempty(failed),'Postprocess v2 selftest failed: %s.',strjoin(failed,', '));
result=struct('passed',true,'checks',checks,'receiverRunsInFrozenReplay',45,'diagnosticLayerRows',54,'receiverRerunsDuringPostprocess',0,'newPhysicalSeeds',0);
fprintf('EP variance postprocess v2 selftest PASS: %d/%d checks; frozen receiverRuns=45, receiverReruns=0, physicalSeeds=0.\n',nnz(values),numel(values));
end

function record=localFrozen(chunk,snr,method)
for i=1:numel(chunk.records)
    x=chunk.records{i};
    if x.targetSnrDb==snr&&x.method==method
        record=x;
        return;
    end
end
error('Frozen record missing.');
end
