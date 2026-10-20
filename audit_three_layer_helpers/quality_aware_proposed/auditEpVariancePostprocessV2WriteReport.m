function auditEpVariancePostprocessV2WriteReport(path,hashRows,methodRows,ojcdRows,extremeRows)
%AUDITEPVARIANCEPOSTPROCESSV2WRITEREPORT State evidence and unavailable fields explicitly.
f=fopen(path,'w','n','UTF-8');assert(f>=0);cleanup=onCleanup(@()fclose(f));
fprintf(f,'Read-only replay45 postprocess v2. receiverRunsInFrozenReplay=45; diagnosticLayerRows=54; receiverRerunsDuringPostprocess=0; newPhysicalSeeds=0.\n');
fprintf(f,'Frozen raw LLR matched records=%d/%d; corrected pre-LDPC BER matches=%d/%d. Saved final diagnostic bitLlr is not present in scenarioRecords, so diagnosticFinalLlrAvailability=notCapturedInFrozenReplay; this report does not fabricate a diagnostic-LLR equality assertion.\n',height(hashRows),height(hashRows),sum(hashRows.correctedPreBerMatches),height(hashRows));
fprintf(f,'JCD1 residual availability=notCapturedInFrozenReplay. JCD2 residual is retained; JCD2 values are never copied into JCD1.\n');
fprintf(f,'Method-layer rows=%d; OJCD layer rows=%d; compact extreme rows=%d.\n',height(methodRows),height(ojcdRows),height(extremeRows));
end
