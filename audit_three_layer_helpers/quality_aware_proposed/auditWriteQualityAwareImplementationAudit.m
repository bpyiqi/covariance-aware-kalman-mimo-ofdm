function auditWriteQualityAwareImplementationAudit(cfg,tests,tables,protected)
%AUDITWRITEQUALITYAWAREIMPLEMENTATIONAUDIT Write deterministic evidence only.
out=cfg.auditOutput;if ~exist(out,'dir'),mkdir(out);end
writetable(tables.candidate,fullfile(out,'quality_aware_candidate_formula_audit.csv'));
writetable(tables.mapping,fullfile(out,'quality_aware_covariance_mapping_audit.csv'));
writetable(tables.selection,fullfile(out,'quality_aware_selection_audit.csv'));
writetable(tables.isolation,fullfile(out,'quality_aware_causal_isolation_audit.csv'));
writetable(protected,fullfile(out,'quality_aware_protected_hashes.csv'));
names=fieldnames(tests);values=cellfun(@(name)tests.(name),names);
f=fopen(fullfile(out,'quality_aware_proposed_selftest_report.txt'),'w','n','UTF-8');assert(f>=0);cleanup=onCleanup(@()fclose(f));
fprintf(f,'Quality-aware local DA Kalman deterministic self-test\n');
for i=1:numel(names),fprintf(f,'%s=%d\n',names{i},values(i));end
fprintf(f,'passed=%d/%d\nallTestsPassed=%d\n',nnz(values),numel(values),all(values));
fprintf(f,['R_LS=mapReal(sigma2Hat*kron(transpose(G\\I),I_Nr)); sigma2Hat=max(noiseVar,||Y-HlsX||_F^2/dof).\n' ...
    'decisionInflation=min(100,1/max(0.01,mean(prod_b(1-1/(1+exp(min(abs(LLR),50))))))).\n' ...
    'NIS=real(nu''*((PPilot+Rdecision)\\nu)); alphaNis=max(1,NIS/8); hardThreshold=26.1245.\n' ...
    'qualityScore=trace(JosephPosterior)/max(trace(PPilot),eps); ties select smaller radius.\n' ...
    'No random packet mini, diagnostic20, 50-packet, or 500-packet experiment was run.\n']);
end
