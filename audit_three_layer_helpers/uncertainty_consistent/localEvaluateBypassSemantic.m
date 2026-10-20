function T=localEvaluateBypassSemantic(method,run)
names=["snapshotTiming";"softMomentSemantics";"indexAlignment";"paddingExcluded"];
snapshot=false; moments=false; alignment=false; padding=false;
if isstruct(run)&&isfield(run,'estCapture')&&isstruct(run.estCapture)
    c=run.estCapture; [D,N]=localGridSize(c);
    snapshot=localSnapshot(c,D,N);
    alignment=localAlignment(c,D,N,method);
    padding=localPadding(c,D,N,method,localAudit(run));
end
if isstruct(run)&&isfield(run,'receiver')&&isstruct(run.receiver)&&isfield(run.receiver,'bypassCapture')&&isfield(run,'validDataMask')
    moments=localMoments(run.receiver.bypassCapture,run.validDataMask);
end
T=localMakeGateTable(method,names,[snapshot;moments;alignment;padding]);
end

function [D,N]=localGridSize(c)
D=0;N=0;
if isfield(c,'captureSymbolIndex')&&ismatrix(c.captureSymbolIndex),[D,N]=size(c.captureSymbolIndex);end
end

function ok=localSnapshot(c,D,N)
ok=D>0&&N>0&&isfield(c,'HhatPilotFrozen')&&iscell(c.HhatPilotFrozen)&&isequal(size(c.HhatPilotFrozen),[D N])&&isfield(c,'PrealPilotFrozen')&&iscell(c.PrealPilotFrozen)&&isequal(size(c.PrealPilotFrozen),[D N])&&isfield(c,'captureSubcarrierIndex')&&isequal(size(c.captureSubcarrierIndex),[D N]);
if ~ok,return;end
for n=1:N
    for d=1:D
        h=c.HhatPilotFrozen{d,n}; p=c.PrealPilotFrozen{d,n};
        ok=ok&&~isempty(h)&&~isempty(p)&&all(isfinite(real(h(:))))&&all(isfinite(imag(h(:))))&&isequal(size(p,1),size(p,2))&&all(isfinite(p(:)))&&c.captureSymbolIndex(d,n)==n;
    end
end
end

function ok=localMoments(p,valid)
required={'softMean','softVariance','posteriorMean','posteriorVariance'};
ok=all(isfield(p,required));if ~ok,return;end
ok=isequaln(p.softMean,p.posteriorMean)&&isequaln(p.softVariance,p.posteriorVariance)&&isequal(size(p.softMean),size(p.softVariance));if ~ok,return;end
streams=size(p.softVariance,1);mask=repmat(reshape(logical(valid),1,size(valid,1),size(valid,2)),streams,1,1);values=p.softVariance(mask);ok=all(isfinite(values))&&all(values>=-1e-13);
end

function ok=localAlignment(c,D,N,method)
if startsWith(string(method),"Base"),ok=D>0&&N>0;return;end
fields={'stream','subcarrier','symbol','paddingMask','validDataMask','reliabilityMask','candidateMask','selectedCandidateMask'};ok=D>0&&N>0;
for i=1:numel(fields),ok=ok&&isfield(c,fields{i})&&iscell(c.(fields{i}))&&isequal(size(c.(fields{i})),[D N]);end
if ~ok,return;end
for n=1:N
    for d=1:D
        if isempty(c.validDataMask{d,n}),continue;end
        ok=ok&&isequal(c.stream{d,n},1:2)&&isequal(c.subcarrier{d,n},c.captureSubcarrierIndex(d,n))&&isequal(c.symbol{d,n},n)&&numel(c.paddingMask{d,n})==D&&numel(c.validDataMask{d,n})==D&&numel(c.reliabilityMask{d,n})==D&&isscalar(c.candidateMask{d,n})&&isscalar(c.selectedCandidateMask{d,n});
    end
end
end

function ok=localPadding(c,D,N,method,audit)
if startsWith(string(method),"Base"),ok=isfield(audit,'daUpdateCount')&&audit.daUpdateCount==0;return;end
ok=localAlignment(c,D,N,method);if ~ok,return;end
for n=1:N
    for d=1:D
        if isempty(c.selectedCandidateMask{d,n}),continue;end
        selected=logical(c.selectedCandidateMask{d,n});candidate=logical(c.candidateMask{d,n});pad=logical(c.paddingMask{d,n});valid=logical(c.validDataMask{d,n});reliable=logical(c.reliabilityMask{d,n});
        ok=ok&&(~selected||candidate)&&(~selected||~pad(d))&&(~selected||valid(d))&&(~selected||reliable(d));
    end
end
end

function a=localAudit(run)
if isfield(run,'audit')&&isstruct(run.audit),a=run.audit;else,a=struct();end
end
