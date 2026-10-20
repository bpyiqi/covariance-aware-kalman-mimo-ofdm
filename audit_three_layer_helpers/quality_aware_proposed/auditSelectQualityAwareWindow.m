function selection = auditSelectQualityAwareWindow(candidates,cfg)
%AUDITSELECTQUALITYAWAREWINDOW Select minimum posterior-trace candidate.
assert(isstruct(candidates));valid=find([candidates.candidateFeasible]);
selection=struct('accepted',false,'selectedIndex',NaN,'selectedRadius',NaN, ...
    'selectedScore',Inf,'validCandidateCount',numel(valid),'candidate',[], ...
    'scores',reshape([candidates.qualityScore],1,[]), ...
    'rejectReasons',string({candidates.rejectReason}));
if isempty(valid),return;end
scores=[candidates(valid).qualityScore];best=min(scores);tied=valid(abs(scores-best)<=cfg.tieTolerance);
[~,position]=min([candidates(tied).radius]);index=tied(position);
selection.accepted=true;selection.selectedIndex=index;selection.selectedRadius=candidates(index).radius;
selection.selectedScore=candidates(index).qualityScore;selection.candidate=candidates(index);
end
