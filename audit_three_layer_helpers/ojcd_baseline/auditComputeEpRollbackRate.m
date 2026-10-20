function rate = auditComputeEpRollbackRate(rollbackCount, precisionCandidateCount)
%AUDITCOMPUTEEPROLLBACKRATE Finite rollback ratio with zero-candidate rule.
% Zero candidates produce rate zero; the candidate count remains available
% separately so reports can distinguish no observations from no rollbacks.
assert(isequal(size(rollbackCount),size(precisionCandidateCount)),'Rollback and candidate arrays must have equal size.');
rate=zeros(size(rollbackCount));valid=precisionCandidateCount>0;
rate(valid)=rollbackCount(valid)./precisionCandidateCount(valid);
end
