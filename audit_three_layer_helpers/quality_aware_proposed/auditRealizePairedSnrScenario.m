function packet=auditRealizePairedSnrScenario(cfg,scenario,targetSnrDb)
%AUDITREALIZEPAIREDSNRSCENARIO Apply only an SNR-dependent noise scale.
assert(cfg.Npayload==scenario.Npayload&&cfg.Ncodeword==scenario.nCodeword,'Scenario/config payload mismatch.');
noiseVar=10^(-targetSnrDb/10);scale=sqrt(noiseVar);noise=scale*scenario.Wunit;
y=scenario.cleanReceivedGrid+noise;obs=scenario.pilotObservationClean+scale*scenario.pilotObservationNoiseUnit;
pilotCfr=cell(size(scenario.pilotCfrClean));
for i=1:numel(pilotCfr),pilotCfr{i}=scenario.pilotCfrClean{i}+scale*scenario.pilotCfrNoiseUnit{i};end
realizedNoisePower=mean(abs(double(noise(:))).^2);cleanSignalPower=mean(abs(double(scenario.cleanReceivedGrid(:))).^2);
realizedSnrDb=10*log10(1/max(realizedNoisePower,eps));
packet=struct('Npayload',scenario.Npayload,'nCodeword',scenario.nCodeword,'codedBits',scenario.codedBits, ...
    'usefulBitMask',scenario.usefulBitMask,'qamSymbols',scenario.qam,'qam',scenario.qam, ...
    'validReMask',scenario.validReMask,'H',scenario.H,'pilotObservation',obs,'obs',obs, ...
    'pilotCfr',{pilotCfr},'receivedData',y,'y',y,'noise',noise,'cleanReceivedGrid',scenario.cleanReceivedGrid, ...
    'targetSnrDb',targetSnrDb,'noiseVar',noiseVar,'cleanSignalPower',cleanSignalPower, ...
    'realizedNoisePower',realizedNoisePower,'realizedSnrDb',realizedSnrDb,'sharedHashY',localHash(y));
end
function value=localHash(data)
v=double(data(:));w=mod((1:numel(v))',104729)+1;
value=sum(real(v).*w)+sqrt(2)*sum(imag(v).*w)+sum(abs(v).^2)/max(numel(v),1);
end
