function result=auditEpVariancePostprocessV2(root,options)
%AUDITEPVARIANCEPOSTPROCESSV2 Dry-run or read-only source replay postprocess.
arguments,root (1,:) char,options.run (1,1) logical=false,end
cfg=auditEpVariancePostprocessV2Config(root);meta=auditEpVariancePostprocessV2Preflight(cfg);
if ~options.run
    assert(exist(cfg.outputDirectory,'dir')~=7,'Dry-run must not create postprocess output.');
    result=struct('dryRun',true,'receiverRunsInFrozenReplay',45,'diagnosticLayerRows',54,'receiverRerunsDuringPostprocess',0,'newPhysicalSeeds',0);
    fprintf('EP variance postprocess v2 dry-run PASS: frozen receiverRuns=45, diagnosticLayerRows=54, receiverReruns=0, physicalSeeds=0.\n');return;
end
auditRefuseNonemptyOutput(cfg.outputDirectory);if exist(cfg.outputDirectory,'dir')~=7,mkdir(cfg.outputDirectory);end
[methodRows,statusRows,floorRows,ojcdRows,extremeRows,hashRows]=auditEpVariancePostprocessV2Aggregate(cfg,meta);assert(height(hashRows)==45&&height(methodRows)==54);
writetable(hashRows,fullfile(cfg.outputDirectory,'ep_variance_postprocess_v2_hash_audit.csv'));writetable(methodRows,fullfile(cfg.outputDirectory,'ep_variance_postprocess_v2_method_snr.csv'));writetable(statusRows,fullfile(cfg.outputDirectory,'ep_variance_postprocess_v2_error_status.csv'));writetable(floorRows,fullfile(cfg.outputDirectory,'ep_variance_postprocess_v2_floor_rollback.csv'));writetable(ojcdRows,fullfile(cfg.outputDirectory,'ep_variance_postprocess_v2_ojcd_layers.csv'));writetable(extremeRows,fullfile(cfg.outputDirectory,'ep_variance_postprocess_v2_extreme_events_compact.csv'));assert(height(extremeRows)<=27000);
auditEpVariancePostprocessV2WriteReport(fullfile(cfg.outputDirectory,'ep_variance_postprocess_v2_report.txt'),hashRows,methodRows,ojcdRows,extremeRows);localManifest(cfg,meta);save(fullfile(cfg.outputDirectory,'ep_variance_postprocess_v2_results.mat'),'cfg','meta','hashRows','methodRows','statusRows','floorRows','ojcdRows','extremeRows','-v7.3');fclose(fopen(fullfile(cfg.outputDirectory,'COMPLETE'),'w'));
result=struct('dryRun',false,'receiverRunsInFrozenReplay',45,'diagnosticLayerRows',54,'receiverRerunsDuringPostprocess',0,'newPhysicalSeeds',0,'outputDirectory',string(cfg.outputDirectory));
end
function localManifest(cfg,meta)
f=fopen(fullfile(cfg.outputDirectory,'ep_variance_postprocess_v2_manifest.txt'),'w','n','UTF-8');assert(f>=0);cleanup=onCleanup(@()fclose(f));
fprintf(f,'experiment=%s\nsourceDirectory=%s\nreceiverRerunsDuringPostprocess=0\nnewPhysicalSeeds=0\n',cfg.experimentName,cfg.sourceDirectory);for i=1:numel(meta.source.chunkPaths),fprintf(f,'dev12chunk=%s SHA256=%s\n',meta.source.chunkPaths(i),meta.source.chunkHashes(i));end
end
