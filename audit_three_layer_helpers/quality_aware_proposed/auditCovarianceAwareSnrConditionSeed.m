function seed=auditCovarianceAwareSnrConditionSeed(masterSeed,snrDb)
%AUDITCOVARIANCEAWARESNRCONDITIONSEED Order-independent SNR seed mapping.
encoded=round(10*snrDb);assert(abs(encoded/10-snrDb)<1e-12,'SNR seed mapping supports 0.1 dB grid points.');
seed=masterSeed+10000*encoded;assert(seed>0&&seed<2^32,'Condition seed is outside the twister range.');
end

