function out = auditTraditionalLmmseEp(pilotCfr, covariance, noiseVar)
%AUDITTRADITIONALLMMSEEP Paper JCD-1 frequency LMMSE, equations (5)-(7).
% PILOTCFR is already an LS CFR observation; it must not be divided by the
% pilot symbol a second time. Dimensions: pilotCfr{rx,tx}=P_tx-by-1.

arguments
    pilotCfr cell
    covariance struct
    noiseVar (1,1) double {mustBeNonnegative}
end

nr = size(pilotCfr,1); nt = size(pilotCfr,2);
D = size(covariance.Rhdhd{1,1},1);
Hdata = complex(zeros(D,nr,nt));
weights = cell(1,nt);
minimumRcond = inf;
for tx = 1:nt
    Rdp = covariance.Rhdhp{tx,tx};
    Rpp = covariance.Rhphp{tx,tx};
    P = size(Rpp,1);
    assert(size(Rdp,2)==P, 'Rdp/Rpp dimensions are inconsistent.');
    system = (Rpp+Rpp')/2 + noiseVar*eye(P);
    minimumRcond = min(minimumRcond,rcond(system));
    % Equation (7), right division avoids explicit inv.
    weights{tx} = Rdp / system;
    for rx = 1:nr
        assert(isequal(size(pilotCfr{rx,tx}),[P 1]), 'Pilot CFR size mismatch.');
        Hdata(:,rx,tx) = weights{tx}*pilotCfr{rx,tx};
    end
end
values = [Hdata(:);cell2mat(cellfun(@(x)x(:),weights,'UniformOutput',false).')];
out = struct('Hdata',Hdata,'weights',{weights},'minimumSystemRcond',minimumRcond, ...
    'hasNaN',any(isnan(values)),'hasInf',any(isinf(values)));
end
