function R = ucChannelCovarianceContraction(Ph,S,Nr,Nt)
if ~isequal(size(Ph),[Nr*Nt Nr*Nt]) || ~isequal(size(S),[Nt Nt])
    error('Inconsistent channel covariance or symbol moment dimensions.');
end
R=zeros(Nr,Nr,'like',Ph);
for ii=1:Nt
    ri=(ii-1)*Nr+(1:Nr);
    for jj=1:Nt
        rj=(jj-1)*Nr+(1:Nr);
        R=R+S(ii,jj)*Ph(ri,rj);
    end
end
R=(R+R')/2;
end
