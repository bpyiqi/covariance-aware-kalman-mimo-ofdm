function results = auditCovarianceAwareFinalSelftest(root)
%AUDITCOVARIANCEAWAREFINALSELFTEST No random validation packets.
cfg=auditCovarianceAwareFinalValidation50Config(root);results.methodCount=numel(cfg.methods)==6;results.expectedRows=2*cfg.packetCountPerCondition*numel(cfg.methods)==600;results.seedIndependence=cfg.validationSeed~=20260719&&cfg.validationSeed~=20260720;results.fixedRadius=cfg.fixedRadius==3;
schema=auditCovarianceAwareFinalValidation50Schema();results.schema=numel(fieldnames(schema.files))==13&&schema.version=="2.0";
dry=auditCovarianceAwareFinalValidation50(root,'dryRun',true);results.dryRun=dry.randomPhysicalPacketCount==0&&dry.methodCount==6&&dry.expectedPacketRows==600&&dry.schemaFileCount==13&&exist(dry.outputDirectory,'dir')~=7;
b=auditPairedBootstrapCi([1;2;3],cfg.bootstrapSeed,32);b2=auditPairedBootstrapCi([1;2;3],cfg.bootstrapSeed,32);results.bootstrapDeterministic=isequaln(b,b2)&&b.ciLower95<=b.pointEstimate&&b.pointEstimate<=b.ciUpper95;
results.aliasVariant=localAlias(cfg);assert(all(structfun(@logical,results)),'Covariance-aware final self-test failed.');fprintf('Covariance-aware final self-test PASS: %d/%d; random packets=0.\n',numel(fieldnames(results)),numel(fieldnames(results)));
end

function pass=localAlias(cfg)
% Use a deterministic feasible r=3 observation, not a truth-bearing packet.
pilot=complex(zeros(cfg.NFFT,1,2,2,'single'));for k=1:cfg.NFFT,pilot(k,1,:,:)=single(eye(2));end
bits=zeros(2*numel(cfg.data),4);for q=1:size(bits,1),bits(q,:)=bitget(mod(q-1,16),4:-1:1);end;x=reshape(ofdm.qam16ModBits(bits),2,[]);
received=complex(zeros(numel(cfg.data),1,2,'single'));for d=1:numel(cfg.data),received(d,1,:)=single(x(:,d));end
online=struct('pilotObservation',pilot,'receivedData',received,'validDataMask',true(numel(cfg.data),1),'noiseVar',cfg.noiseVar,'rho',cfg.rho);
first=auditMechanismRunSingleEstimator(cfg,online,"FixedRadius3LsCovOnlyCausal_EP");second=auditMechanismRunSingleEstimator(cfg,online,"CovarianceAwareLocalDAKalmanCausal_EP");
pass=first.audit.daUpdateCount>0&&isequaln(first.Hhat,second.Hhat)&&isequaln(first.finalState,second.finalState)&&isequaln(first.finalCovariance,second.finalCovariance)&&isequaln(first.audit,second.audit);
end
