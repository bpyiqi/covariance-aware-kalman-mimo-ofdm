function metric = ucRobustCandidateMetric(y,Hhat,Ph,Rn,x,logPrior)
if nargin<6, logPrior=0; end
Nr=size(Hhat,1); A=kron(x.',eye(Nr)); Rcandidate=Rn+A*Ph*A'; Rcandidate=(Rcandidate+Rcandidate')/2;
[L,p]=chol(Rcandidate,'lower'); if p~=0, error('Candidate covariance is not positive definite.'); end
err=y-Hhat*x; metric=-real(err'*(L'\(L\err)))-2*sum(log(real(diag(L))))+logPrior;
end
