function [Hda,Cda,diagOut] = ucDecisionAwareLocalLsCovariance(Y,Mu,Vcell,Hbar,Ph,Rn,~)
[Nr,M]=size(Y); Nt=size(Mu,1);
if size(Mu,2)~=M || ~isequal(size(Hbar),[Nr Nt]) || numel(Vcell)~=M
    error('Inconsistent local-LS dimensions.');
end
G=Mu*Mu'; Gsolve=G\eye(Nt); Hda=Y*Mu'*Gsolve;
Cda=zeros(Nr*Nt,Nr*Nt,'like',Y);
for mm=1:M
    Vm=Vcell{mm};
    if ~isequal(size(Vm),[Nt Nt]), error('Each Vcell entry must be Nt-by-Nt.'); end
    Rnm=Rn; if ndims(Rn)==3, Rnm=Rn(:,:,mm); end
    Reta=Rnm+Hbar*Vm*Hbar'+ucChannelCovarianceContraction(Ph,Vm,Nr,Nt);
    Reta=ucProjectHermitianPsd(Reta);
    am=Gsolve*Mu(:,mm); Bm=kron(conj(am),eye(Nr));
    Cda=Cda+Bm*Reta*Bm';
end
[Cda,pdiag]=ucProjectHermitianPsd(Cda);
diagOut=struct('G',G,'minEigenvalue',pdiag.minEigenvalueBefore,'receiverRuns',0,'physicalSeeds',0);
end
