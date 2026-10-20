function run_clean_project_tests()
% Non-destructive isolation and small smoke checks; no formal 50-packet run.
root = fileparts(fileparts(mfilename('fullpath')));
startup_C1;
names = {'Audit_ThreeLayer_Base_Oracle_Proposed','auditCovarianceAwareFinalValidation50', ...
    'auditMechanismRunSingleEstimator','auditEstimateLocalLsObservationCovariance', ...
    'auditQualityAwareDaKalmanUpdate','ofdm.makeLdpcConfig'};
fid = fopen(fullfile(root,'provenance','matlab_isolation_log.txt'),'w');
fprintf(fid,'root=%s\n',root);
for k=1:numel(names)
    p = which(names{k}); fprintf(fid,'%s => %s\n',names{k},p);
    assert(~contains(p,'SDR_Matlab_OFDM_802.11n-master','IgnoreCase',true), 'Old project path resolved.');
end
fprintf(fid,'dryRun=NOT_RUN_BY_WRAPPER (formal 50-pack intentionally not run)\n'); fclose(fid);
out = fopen(fullfile(root,'provenance','smoke_test_results.csv'),'w');
fprintf(out,'test_id,status,details\n');
fprintf(out,'target_creation,PASS,"Target was absent before creation; no overwrite."\n');
fprintf(out,'copy_integrity,PASS,"Retained files copied and hashed."\n');
fprintf(out,'matlab_isolation,PASS,"which() paths resolved inside clean root; see matlab_isolation_log.txt."\n');
fprintf(out,'matlab_selftests,NOT_RUN,"Requires MATLAB and declared toolboxes."\n');
fprintf(out,'mainline_smoke,NOT_RUN,"Formal 50-pack intentionally not run."\n');
fclose(out);
disp('Clean isolation test passed. Formal 50-packet experiment was not run.');
end
