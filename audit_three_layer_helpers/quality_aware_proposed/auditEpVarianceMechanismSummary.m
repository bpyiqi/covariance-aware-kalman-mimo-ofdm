function result=auditEpVarianceMechanismSummary(root,options)
%AUDITEPVARIANCEMECHANISMSUMMARY Read-only mechanism summary of frozen V2.
arguments
    root (1,:) char
    options.run (1,1) logical=false
end
cfg=auditEpVarianceMechanismSummaryConfig(root);input=auditEpVarianceMechanismSummaryPreflight(cfg);
if ~options.run
    assert(exist(cfg.outputDirectory,'dir')~=7,'Dry-run must not create a formal output directory.');
    fprintf('EP variance mechanism summary dry-run PASS: receiverRuns=0; physicalSeeds=0; V2 45/45 BER mapping present.\n');
    result=struct('dryRun',true,'receiverRuns',0,'physicalSeeds',0);return;
end
before={auditDirectoryShaManifest(cfg.v1Directory),auditDirectoryShaManifest(cfg.v2Directory)};
auditRefuseNonemptyOutput(cfg.outputDirectory);if exist(cfg.outputDirectory,'dir')~=7,mkdir(cfg.outputDirectory);end
out=auditEpVarianceMechanismSummaryBuild(cfg,input);
writetable(out.method,fullfile(cfg.outputDirectory,'ep_variance_mechanism_method_snr.csv'));
writetable(out.paired,fullfile(cfg.outputDirectory,'ep_variance_mechanism_cov_vs_base_paired.csv'));
writetable(out.tail,fullfile(cfg.outputDirectory,'ep_variance_mechanism_error_tail.csv'));
writetable(out.floor,fullfile(cfg.outputDirectory,'ep_variance_mechanism_floor_rollback.csv'));
writetable(out.ojcd,fullfile(cfg.outputDirectory,'ep_variance_mechanism_ojcd_layers.csv'));
localDecision(fullfile(cfg.outputDirectory,'ep_variance_mechanism_decision.txt'),out);
after={auditDirectoryShaManifest(cfg.v1Directory),auditDirectoryShaManifest(cfg.v2Directory)};assert(isequal(before,after),'Frozen V1/V2 source manifest changed during summary.');
localManifest(fullfile(cfg.outputDirectory,'ep_variance_mechanism_manifest.txt'),cfg,before);
save(fullfile(cfg.outputDirectory,'ep_variance_mechanism_results.mat'),'cfg','out','before','-v7.3');fclose(fopen(fullfile(cfg.outputDirectory,'COMPLETE'),'w'));
result=struct('dryRun',false,'receiverRuns',0,'physicalSeeds',0,'outputDirectory',string(cfg.outputDirectory));
end

function localDecision(path,out)
f=fopen(path,'w','n','UTF-8');assert(f>=0);clean=onCleanup(@()fclose(f));d=out.decision;
fprintf(f,'Read-only mechanism summary. frozen replay receiverRuns=45; postprocess receiverRuns=0; physicalSeeds=0.\n');
fprintf(f,'Cov residual lower than Base: %d/9.\nCov medianZe lower than Base: %d/9.\nCov BER lower than Base: %d/9.\nCov wrong40 lower than Base: %d/9.\n',d.covResidualLower,d.covZeLower,d.covBerLower,d.covWrong40Lower);
fprintf(f,'PerfectCSI residual/noise per-RX scenario-summary range: [%.9g, %.9g].\n',d.perfectResidualMin,d.perfectResidualMax);
fprintf(f,'OJCD JCD2 high-confidence-wrong40 total: %.0f.\n',d.ojcdWrong40);
fprintf(f,'Posterior floor hits are reported as hits per stream-RE only; they are a high-SNR numerical observation, not a sufficient condition for high-confidence errors.\n');
fprintf(f,'JCD1 residual, BER, and bit-error fields remain NaN/notCapturedInFrozenReplay. No beta, clipping, formal EP, or algorithm-change approval is issued by this read-only summary.\n');
end

function localManifest(path,cfg,sourceManifests)
f=fopen(path,'w','n','UTF-8');assert(f>=0);clean=onCleanup(@()fclose(f));
fprintf(f,'experiment=%s\nreceiverRuns=0\nphysicalSeeds=0\nv1Directory=%s\nv2Directory=%s\n',cfg.experimentName,cfg.v1Directory,cfg.v2Directory);
for q=1:numel(sourceManifests)
    fprintf(f,'sourceManifest%dFiles=%d\n',q,height(sourceManifests{q}));
end
end
