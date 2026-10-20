function results = auditQualityAwareMiniEntrySelftest(root)
%AUDITQUALITYAWAREMINIENTRYSELFTEST Dry-run routing/schema/collision gates.
temporaryOutput=[tempname '_quality_aware_mini_dryrun'];cleanup=onCleanup(@()localCleanup(temporaryOutput));
dry=auditQualityAwareProposedMini(root,'dryRun',true,'outputDirectory',temporaryOutput);
schema=auditQualityAwareMiniSchema();dispatcher=fileread(fullfile(root,'Audit_ThreeLayer_Base_Oracle_Proposed.m'));
miniSource=fileread(fullfile(fileparts(mfilename('fullpath')),'auditQualityAwareProposedMini.m'));
results.routingPass=contains(dispatcher,'case "quality_aware_proposed_mini"')&&contains(dispatcher,'auditQualityAwareProposedMini(root)');
results.dryRunPass=dry.dryRun&&dry.randomPhysicalPacketCount==0&&exist(fullfile(temporaryOutput,'quality_aware_mini_dry_run_report.txt'),'file')==2;
results.methodListPass=numel(dry.methods)==9&&isequal(dry.methods,dry.cfg.miniMethods);
results.schemaPass=all(cellfun(@(name)isequal(dry.tables.(name).Properties.VariableNames,schema.(name)),fieldnames(schema)));
requiredHashes={'informationBitsHash','transmitBitsHash','codedBitsHash','qamSymbolsHash','paddingMaskHash','channelHash','noiseHash','receivedSignalHash','pilotObservationHash'};
results.hashSchemaPass=isempty(setdiff(requiredHashes,schema.hash));
results.lockRemoved=~contains(miniSource,'random Mini is intentionally locked')&&~contains(miniSource,'No random packet was started');
results.normalCallNotDryRun=contains(miniSource,"addParameter('dryRun',false")&&~contains(miniSource,"options.dryRun=true");
ownerIds=cellfun(@(state)state.stateOwnerId,dry.stateContainers);results.independentStateContainers=numel(unique(ownerIds))==9;
results.parameterFreeze=dry.cfg.miniMasterSeed==20260719&&dry.cfg.SNRdB==20&&dry.cfg.fdHz==200&&dry.cfg.NFFT==64&&dry.cfg.modulationOrder==16&&isequal(dry.cfg.Ncodeword,[1 3])&&isequal(dry.cfg.Npayload,[169 507])&&isequal(dry.cfg.radii,[1 2 3])&&dry.cfg.llrThreshold==2.5&&dry.cfg.gramRcondThreshold==1e-3&&dry.cfg.chiSquareHardThresholdDof8P999==26.1245;
collisionDirectory=[temporaryOutput '_collision'];mkdir(collisionDirectory);collisionCleanup=onCleanup(@()localCleanup(collisionDirectory));file=fopen(fullfile(collisionDirectory,'quality_aware_mini_packet_level.csv'),'w');assert(file>=0);fclose(file);
try
    auditQualityAwareMiniPreflight(root,dry.cfg,collisionDirectory);results.collisionProtection=false;
catch exception
    results.collisionProtection=contains(exception.message,'Refusing to overwrite');
end
values=cellfun(@(name)results.(name),fieldnames(results));assert(all(values),'Quality-aware Mini entry dry-run self-test failed.');
fprintf('Quality-aware Mini entry dry-run self-test PASS: %d/%d; random packets=0.\n',nnz(values),numel(values));
end

function localCleanup(path)
if exist(path,'dir'),rmdir(path,'s');end
end
