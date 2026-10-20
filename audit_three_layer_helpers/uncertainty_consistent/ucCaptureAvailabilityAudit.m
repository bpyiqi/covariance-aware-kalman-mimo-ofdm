function availability = ucCaptureAvailabilityAudit(root)
% Read-only source/MAT inspection; writes only the explicitly allowed audit files.
out=fullfile(root,'results_three_layer_validation','uncertainty_propagation_capture_audit_v1');
if exist(out,'dir'), error('ucCaptureAvailabilityAudit:OutputExists','Refusing to overwrite %s.',out); end
src=dir(fullfile(root,'**','*.m')); src=src(~contains(string({src.folder}),'uncertainty_consistent')); sourceText=strings(numel(src),1);
for ii=1:numel(src), sourceText(ii)=string(fileread(fullfile(src(ii).folder,src(ii).name))); end
matFiles=dir(fullfile(root,'results_three_layer_validation','**','*.mat')); matNames=strings(0,1);
for ii=1:numel(matFiles), w=whos('-file',fullfile(matFiles(ii).folder,matFiles(ii).name)); matNames=[matNames; string({w.name})']; end %#ok<AGROW>
fields=["HhatPilotFrozen","PrealPilotFrozen","posteriorMean","posteriorVariance","q","softMean","softVariance","stream","subcarrier","symbol","paddingMask","reliabilityMask","Rn","noiseVar","Hhat","lambda","gamma","bitLlr"]';
n=numel(fields); sourceFunction=strings(n,1); sourceVariable=fields; runtime=false(n,1); frozen=false(n,1); notes=strings(n,1);
for ii=1:n
    needle=lower(fields(ii)); hit=find(contains(lower(sourceText),needle),1);
    if ~isempty(hit), runtime(ii)=true; sourceFunction(ii)=string(src(hit).name); end
    frozen(ii)=any(strcmpi(matNames,fields(ii)));
    if frozen(ii), notes(ii)="savedInFrozenReplay"; elseif runtime(ii), notes(ii)="runtimeAvailable; not verified in frozen replay"; else, notes(ii)="notAvailable"; end
end
availability=table(fields,sourceFunction,sourceVariable,runtime,frozen,~frozen,notes, ...
 'VariableNames',{'field','sourceFunction','sourceVariable','capturedInCurrentRuntime','capturedInFrozenReplay45','requiresNewReceiverCapture','notes'});
mkdir(out); writetable(availability,fullfile(out,'uncertainty_capture_availability.csv'));
report=ucUncertaintyPropagationSelftest(root); writetable(report,fullfile(out,'uncertainty_core_selftest.txt'),'Delimiter','tab');
fid=fopen(fullfile(out,'uncertainty_capture_audit.txt'),'w'); fprintf(fid,'uncertainty propagation capture availability audit v1\nreceiverRuns=0\nphysicalSeeds=0\n'); fprintf(fid,'MAT files inspected: %d\n',numel(matFiles)); fprintf(fid,'Current runtime availability is source-only evidence; frozen status is MAT-variable evidence.\n'); fclose(fid);
protected={'Compare_LongPayload_VideoLink_Kalman.m','2047D3BC2F551B79975B1B0DA545F5D237AE888E466751DED1A688E333F386BC';'Exp_ProblemExistence_CSI_Aging.m','E79FFDB32C006D15CCAF9783459EF626B8FD6F3B7FB6635AD0FC3ECE271EB4D9';'Audit_ProblemExistence_CSI_Aging.m','C47BE923F41FC66F902D98B09A8DF6958E5C7FE13F26FF4BE68E6098A65AECE6'};
fid=fopen(fullfile(out,'uncertainty_core_manifest.txt'),'w'); for ii=1:size(protected,1), h=sha256File(fullfile(root,protected{ii,1})); fprintf(fid,'%s %s expected=%s\n',protected{ii,1},h,protected{ii,2}); assert(strcmp(h,protected{ii,2})); end; fclose(fid);
fclose(fopen(fullfile(out,'COMPLETE'),'w')); fprintf('Capture audit written to %s\nreceiverRuns=0\nphysicalSeeds=0\n',out);
end

function hex = sha256File(path)
escaped=strrep(path,'''','''''');
[status,hex]=system(sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',escaped));
if status~=0, error('Unable to compute SHA-256 for %s.',path); end
hex=upper(strtrim(hex));
end
