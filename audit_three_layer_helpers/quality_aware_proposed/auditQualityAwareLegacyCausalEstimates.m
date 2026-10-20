function result = auditQualityAwareLegacyCausalEstimates(cfg,packet,fixedRadii)
%AUDITQUALITYAWARELEGACYCAUSALESTIMATES Frozen legacy Base/Min/R2/Oracle.
if nargin<3,fixedRadii=2;end
[Hbase,Hold,baseAudit]=auditOjcdMiniCausalEstimates(cfg,packet);
Hfixed1=[];Hfixed2=[];Hfixed3=[];fixedAudit1=[];fixedAudit2=[];fixedAudit3=[];
if ismember(1,fixedRadii),[Hfixed1,fixedAudit1]=localBranch(false,1);end
if ismember(2,fixedRadii),[Hfixed2,fixedAudit2]=localBranch(false,2);end
if ismember(3,fixedRadii),[Hfixed3,fixedAudit3]=localBranch(false,3);end
[Horacle,oracleAudit]=localBranch(true,[]);fixedAudit=fixedAudit2;
result=struct('Hbase',Hbase,'Hold',Hold,'HfixedRadius1',Hfixed1, ...
    'HfixedRadius2',Hfixed2,'HfixedRadius3',Hfixed3,'Horacle',Horacle, ...
    'baseAudit',baseAudit,'fixedAudit1',fixedAudit1,'fixedAudit',fixedAudit, ...
    'fixedAudit2',fixedAudit2,'fixedAudit3',fixedAudit3,'oracleAudit',oracleAudit);

    function [Hout,audit]=localBranch(useOracle,fixedRadius)
        K=cfg.NFFT;N=packet.Npayload;F=8;features=reshape(permute(single(ofdm.complexToFeatures(packet.obs)),[1 3 2]),K*F,N);
        variance=max(mean(double(features).^2,2),1e-5);Q=max(1-cfg.rho^2,1e-8).*variance;R=max(cfg.noiseVar/2,1e-8);
        state=double(features(:,1));P=variance+R;Hout=complex(zeros(K,N,2,2,'single'));Hout(:,1,:,:)=packet.obs(:,1,:,:);accepted=0;rejected=0;
        timer=tic;
        for n=1:N
            if n>1,predicted=cfg.rho*state;predictedP=cfg.rho^2*P+Q;gain=predictedP./(predictedP+R);state=predicted+gain.*(double(features(:,n))-predicted);P=(1-gain).*predictedP;Hout(:,n,:,:)=ofdm.featuresToComplex(permute(reshape(single(state),K,F),[1 3 2]));end
            Hseed=squeeze(Hout(:,n,:,:));Y=squeeze(packet.y(:,n,:)).';D=numel(cfg.data);X=complex(zeros(2,D));reliability=inf(1,D);
            if useOracle,X=squeeze(packet.qam(:,:,n));else,for d=1:D,xeq=ofdm.mmseEqualize2x2(double(Y(:,d)),double(squeeze(Hseed(cfg.data(d),:,:))),cfg.noiseVar);bits=ofdm.qam16DemodBits(xeq);X(:,d)=ofdm.qam16ModBits(double(bits));reliability(d)=min(abs(ofdm.qam16DemodLlr(xeq,cfg.noiseVar)));end,end
            for d=1:D
                if ~packet.validReMask(d,n),continue;end
                if isempty(fixedRadius),observation=auditBuildLocalMimoPseudoObservation(X,Y,d,packet.validReMask(:,n),reliability,cfg.radii,cfg.llrThreshold,[]);else,observation=auditBuildFixedRadiusLegacyObservation(X,Y,d,packet.validReMask(:,n),reliability,fixedRadius,cfg);end
                if ~observation.accepted,rejected=rejected+1;continue;end
                indices=cfg.data(d)+(0:F-1)*K;gain=P(indices)./(P(indices)+R);state(indices)=state(indices)+gain.*(observation.feature-state(indices));P(indices)=(1-gain).*P(indices);Hout(cfg.data(d),n,:,:)=auditFeatureVectorToChannelMatrix(state(indices));accepted=accepted+1;
            end
        end
        audit=struct('accepted',accepted,'rejected',rejected,'configuredRadius',fixedRadius, ...
            'candidateFeasibleCount',accepted,'candidateRejectedCount',rejected, ...
            'daUpdateCoverageRate',accepted/max(accepted+rejected,1),'runtimeSeconds',toc(timer), ...
            'futureSymbolReadCount',0,'testTruthOnlineUseCount',0,'solverFailureCount',0);
    end
end
