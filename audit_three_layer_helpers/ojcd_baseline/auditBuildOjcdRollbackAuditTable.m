function tableOut = auditBuildOjcdRollbackAuditTable(detail, payloadSymbols, packetIndex, epIterations)
%AUDITBUILDOJCDROLLBACKAUDITTABLE Expand one packet's OJCD rollback audit.
required={'candidateJcd1','rollbackJcd1','candidateJcd2','rollbackJcd2', ...
    'candidateMatrixJcd1','rollbackMatrixJcd1','candidateMatrixJcd2','rollbackMatrixJcd2'};
assert(isstruct(detail)&&isscalar(detail),'OJCD rollback detail must be a scalar structure.');
missing=setdiff(required,fieldnames(detail));
assert(isempty(missing),'OJCD rollback detail is missing fields: %s',strjoin(missing,','));
assert(isscalar(payloadSymbols)&&isscalar(packetIndex)&&isscalar(epIterations)&&epIterations>=1, ...
    'Rollback audit indices and EP iteration count must be valid scalars.');

matrixNames=required(5:8);
for index=1:numel(matrixNames)
    value=detail.(matrixNames{index});
    assert(isnumeric(value)&&isequal(size(value),[epIterations 2]), ...
        'OJCD rollback field %s must be a %d-by-2 numeric matrix.',matrixNames{index},epIterations);
    assert(all(isfinite(value(:)))&&all(value(:)>=0), ...
        'OJCD rollback field %s contains an invalid count.',matrixNames{index});
end

assert(detail.candidateJcd1==sum(detail.candidateMatrixJcd1,'all')&& ...
    detail.rollbackJcd1==sum(detail.rollbackMatrixJcd1,'all')&& ...
    detail.candidateJcd2==sum(detail.candidateMatrixJcd2,'all')&& ...
    detail.rollbackJcd2==sum(detail.rollbackMatrixJcd2,'all'), ...
    'OJCD rollback scalar totals do not match iteration/stream matrices.');

variableNames={'payloadSymbols','packetIndex','aggregationLevel','jcdLayer', ...
    'epIteration','streamIndex','precisionCandidateCount', ...
    'negativePrecisionRollbackCount','rollbackRate'};
rows=cell(2*epIterations*2+3,1);rowIndex=0;
for layer=1:2
    if layer==1
        candidate=detail.candidateMatrixJcd1;
        rollbackValues=detail.rollbackMatrixJcd1;
        layerName="JCD1";
    else
        candidate=detail.candidateMatrixJcd2;
        rollbackValues=detail.rollbackMatrixJcd2;
        layerName="JCD2";
    end
    for iteration=1:epIterations
        for stream=1:2
            rowIndex=rowIndex+1;
            rows{rowIndex}=table(payloadSymbols,packetIndex,"iteration_stream",layerName, ...
                iteration,stream,candidate(iteration,stream),rollbackValues(iteration,stream), ...
                localRate(rollbackValues(iteration,stream),candidate(iteration,stream)), ...
                'VariableNames',variableNames);
        end
    end
    rowIndex=rowIndex+1;
    candidateTotal=sum(candidate,'all');rollbackTotal=sum(rollbackValues,'all');
    rows{rowIndex}=table(payloadSymbols,packetIndex,"layer_total",layerName,0,0, ...
        candidateTotal,rollbackTotal,localRate(rollbackTotal,candidateTotal), ...
        'VariableNames',variableNames);
end
totalCandidate=detail.candidateJcd1+detail.candidateJcd2;
totalRollback=detail.rollbackJcd1+detail.rollbackJcd2;
rowIndex=rowIndex+1;
rows{rowIndex}=table(payloadSymbols,packetIndex,"packet_total","ALL",0,0, ...
    totalCandidate,totalRollback,localRate(totalRollback,totalCandidate), ...
    'VariableNames',variableNames);
tableOut=vertcat(rows{1:rowIndex});
assert(height(tableOut)==4*epIterations+3,'Unexpected OJCD rollback audit row count.');
end

function value = localRate(rollbackCount, candidateCount)
value=auditComputeEpRollbackRate(rollbackCount,candidateCount);
end
