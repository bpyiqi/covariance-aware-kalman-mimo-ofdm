function result = Run_PhysicalCom_Robustness_AB_v1()
%RUN_PHYSICALCOM_ROBUSTNESS_AB_V1 Execute the frozen 360-run experiment.
root = fileparts(mfilename('fullpath'));
prepDir = fullfile(root, 'results_three_layer_validation', ...
    'physicalcom_robustness_ab_v1_prepare');
prepComplete = fullfile(prepDir, 'COMPLETE_PREPARE');
assert(exist(prepComplete, 'file') == 2, ...
    'PreparePrerequisiteMissing', 'COMPLETE_PREPARE is missing.');
prepReport = fileread(fullfile(prepDir, 'robustness_ab_prepare_report.txt'));
requiredPrep = [
    "plannedUniqueReceiverRuns=360"
    "pairingInterfaceAvailable=true"
    "expectedCenterSnrDb=20"
    "expectedCenterDopplerHz=200"
    "payloadSymbols=169"
    "packetCount=20"
];
assert(all(contains(prepReport, requiredPrep)), ...
    'PreparePrerequisiteMismatch', 'A preparation prerequisite is mismatched.');

cfg = physicalComRobustnessABConfig(root);
localAssertFrozenSourceHashes(cfg);
outputDir = fullfile(root, 'results_three_layer_validation', ...
    'physicalcom_robustness_ab_v1');
checkpointPath = fullfile(outputDir, 'robustness_ab_checkpoint.mat');
if exist(outputDir, 'dir') ~= 7
    mkdir(outputDir);
else
    assert(exist(checkpointPath, 'file') == 2, ...
        'ResumeCheckpointMissing', ...
        'Existing experiment directory has no checkpoint.');
end

qualityDir = fullfile(root, 'audit_three_layer_helpers', ...
    'quality_aware_proposed');
helperDir = fullfile(root, 'audit_three_layer_helpers');
ojcdDir = fullfile(helperDir, 'ojcd_baseline');
srcDir = fullfile(root, 'src');
addpath(srcDir, helperDir, qualityDir, ojcdDir);
cleanupPath = onCleanup(@() rmpath(srcDir, helperDir, qualityDir, ojcdDir));

runCfg = auditQualityAwareDefaultConfig(root);
runCfg.Ncodeword = 1;
runCfg.Npayload = cfg.payloadSymbols;
runCfg.SNRdB = cfg.expectedCenterSnrDb;
runCfg.fdHz = cfg.expectedCenterDopplerHz;
runCfg.rho = ofdm.uavDopplerToRho(runCfg.fdHz, runCfg.Tsym);
runCfg.fixedRadius = cfg.fixedRadius;
runCfg.radii = [1 2 3];
runCfg.llrThreshold = cfg.llrThreshold;
runCfg.minEffectiveSamples = cfg.minEffectiveSamples;
runCfg.gramRcondThreshold = cfg.gramRcondThreshold;
runCfg.methods = cfg.historicalMethods;
runCfg.masterSeed = cfg.robustnessMasterSeed;
runCfg.bootstrapSeed = cfg.bootstrapSeed;
runCfg.bootstrapCount = cfg.bootstrapCount;

conditions = localConditions();
expectedKeys = localExpectedKeys(conditions, cfg);
state = localStartOrResume(outputDir, checkpointPath, expectedKeys);
if state.status == "complete"
    if localRequiredArtifactsPresent(outputDir)
        result = localFinishResult(state, outputDir);
        return;
    end
    state.status = "precheck_passed";
end
attemptedRuns = state.attemptedRuns;
completedRuns = state.completedRuns;
packetRows = state.packetRows;
completedKeys = state.completedKeys;

try
    if state.status ~= "precheck_passed"
        [packetRows, completedKeys, attemptedRuns, completedRuns] = ...
            localRunPacketSet(1, conditions, cfg, runCfg, packetRows, ...
            completedKeys, attemptedRuns, completedRuns, checkpointPath, ...
            expectedKeys);
        precheck = localPrecheck(packetRows, conditions, cfg);
        localWriteText(fullfile(outputDir, 'robustness_ab_precheck.txt'), ...
            localPrecheckText(precheck));
        if ~precheck.passed
            localWriteText(fullfile(outputDir, 'PRECHECK_FAILED'), ...
                localPrecheckText(precheck));
            localCheckpointSave(checkpointPath, packetRows, completedKeys, ...
                attemptedRuns, completedRuns, "precheck_failed", expectedKeys);
            result = struct('status', "PRECHECK_FAILED", ...
                'receiverRuns', completedRuns, 'outputDirectory', string(outputDir));
            return;
        end
        localWriteText(fullfile(outputDir, 'PRECHECK_PASS'), ...
            localPrecheckText(precheck));
        state.status = "precheck_passed";
        localCheckpointSave(checkpointPath, packetRows, completedKeys, ...
            attemptedRuns, completedRuns, state.status, expectedKeys);
    end

    for packetId = 2:cfg.packetCount
        [packetRows, completedKeys, attemptedRuns, completedRuns] = ...
            localRunPacketSet(packetId, conditions, cfg, runCfg, packetRows, ...
            completedKeys, attemptedRuns, completedRuns, checkpointPath, ...
            expectedKeys);
        localCheckpointSave(checkpointPath, packetRows, completedKeys, ...
            attemptedRuns, completedRuns, "running", expectedKeys);
        fprintf('packetId=%d completedReceiverRuns=%d/%d\n', ...
            packetId, completedRuns, height(expectedKeys));
    end

    assert(completedRuns == 360 && height(packetRows) == 360, ...
        'ReceiverRunCountMismatch', 'Expected exactly 360 completed runs.');
    localAuditFinalRows(packetRows, cfg);
    design = localDesignTable(conditions, cfg);
    summary = localSummary(packetRows, conditions, cfg);
    [paired, bootstrap] = localPairedStatistics(packetRows, conditions, cfg);
    runtime = localRuntime(packetRows, conditions, cfg);
    claimGate = localClaimGate(summary, paired, bootstrap);
    writetable(design, fullfile(outputDir, 'robustness_ab_design.csv'));
    writetable(packetRows, fullfile(outputDir, 'robustness_ab_packet_level.csv'));
    writetable(summary, fullfile(outputDir, 'robustness_ab_summary.csv'));
    writetable(paired, fullfile(outputDir, 'robustness_ab_paired_statistics.csv'));
    writetable(bootstrap, fullfile(outputDir, 'robustness_ab_bootstrap_ci.csv'));
    writetable(localPairingHashes(packetRows), fullfile(outputDir, ...
        'robustness_ab_pairing_hashes.csv'));
    writetable(runtime, fullfile(outputDir, 'robustness_ab_runtime_audit.csv'));
    writetable(claimGate, fullfile(outputDir, 'robustness_ab_claim_gate.csv'));
    localMakeAllFigures(packetRows, cfg, outputDir);
    localWriteText(fullfile(outputDir, 'robustness_ab_report.txt'), ...
        localFinalReport(packetRows, summary, paired, claimGate, cfg));
    localWriteText(fullfile(outputDir, 'robustness_ab_manifest.txt'), ...
        localFinalManifest(cfg, packetRows, claimGate));
    localAssertRequiredDataArtifacts(outputDir);
    localAssertFrozenSourceHashes(cfg);
    localWriteText(fullfile(outputDir, 'COMPLETE_EXPERIMENT_A'), 'complete\n');
    localWriteText(fullfile(outputDir, 'COMPLETE_EXPERIMENT_B'), 'complete\n');
    localWriteText(fullfile(outputDir, 'COMPLETE_ROBUSTNESS_AB'), ...
        'complete\nreceiverRuns=360\nuniqueReceiverRuns=360\n');
    localCheckpointSave(checkpointPath, packetRows, completedKeys, ...
        attemptedRuns, completedRuns, "complete", expectedKeys);
    result = struct('status', "complete", 'receiverRuns', completedRuns, ...
        'uniqueReceiverRuns', height(unique(packetRows(:, ...
        {'conditionId','packetId','historicalMethodName'}), 'rows')), ...
        'outputDirectory', string(outputDir));
catch primaryError
    try
        localWriteText(fullfile(outputDir, 'RUN_FAILED'), ...
            getReport(primaryError, 'extended', 'hyperlinks', 'off'));
    catch failureLogError
        fprintf(2, 'RUN_FAILURE_LOG_ERROR: %s\n', failureLogError.message);
    end
    try
        localCheckpointFailureSave(checkpointPath, packetRows, completedKeys, ...
            attemptedRuns, completedRuns, expectedKeys);
    catch checkpointError
        fprintf(2, 'RUN_FAILURE_CHECKPOINT_ERROR: %s\n', ...
            checkpointError.message);
    end
    rethrow(primaryError);
end
end

function conditions = localConditions()
conditionId = (1:5).';
snrDb = [15;20;25;20;20];
dopplerHz = [200;200;200;100;300];
experiment = ["A";"A+B";"A";"B";"B"];
conditions = table(conditionId, snrDb, dopplerHz, experiment);
end

function keys = localExpectedKeys(conditions, cfg)
rows = cell(360, 1);
cursor = 0;
for conditionIndex = 1:height(conditions)
    methods = cfg.historicalMethods(1:3);
    if conditionIndex <= 3
        methods = cfg.historicalMethods;
    end
    for methodIndex = 1:numel(methods)
        for packetId = 1:cfg.packetCount
            cursor = cursor + 1;
            rows{cursor} = table(conditions.conditionId(conditionIndex), ...
                packetId, methods(methodIndex), ...
                'VariableNames', {'conditionId','packetId','historicalMethodName'});
        end
    end
end
keys = vertcat(rows{:});
end

function state = localStartOrResume(outputDir, checkpointPath, expectedKeys)
if exist(checkpointPath, 'file') == 2
    loaded = load(checkpointPath);
    assert(isfield(loaded, 'packetRows') && isfield(loaded, 'completedKeys'), ...
        'CheckpointSchemaMismatch', 'Checkpoint fields are incomplete.');
    assert(isfield(loaded, 'status') && isfield(loaded, 'completedRuns'), ...
        'CheckpointStateMissing', 'Checkpoint state is incomplete.');
    assert(isequal(loaded.expectedKeys, expectedKeys), ...
        'CheckpointGridMismatch', 'Checkpoint grid does not match frozen grid.');
    localValidateCheckpoint(loaded);
    state = loaded;
    if state.status == "precheck_failed"
        error('RobustnessAB:PreviousRunFailed', ...
            'Precheck failed; inspect PRECHECK_FAILED.');
    end
    return;
end
assert(exist(outputDir, 'dir') == 7, 'OutputDirectoryMissing', ...
    'Cannot initialize the experiment output directory.');
state = struct('status', "new", 'packetRows', localEmptyPacketTable(), ...
    'completedKeys', expectedKeys([],:), 'attemptedRuns', 0, ...
    'completedRuns', 0, 'expectedKeys', expectedKeys);
end

function [rows, keys, attempted, completed] = localRunPacketSet(packetId, ...
        conditions, cfg, runCfg, rows, keys, attempted, completed, ...
        checkpointPath, expectedKeys)
scenarioCache = cell(height(conditions), 1);
for conditionIndex = 1:height(conditions)
    condition = conditions(conditionIndex, :);
    cacheKey = find([conditions.dopplerHz] == condition.dopplerHz, 1);
    if isempty(scenarioCache{cacheKey})
        scenarioCache{cacheKey} = localBuildScenario(runCfg, cfg, packetId, ...
            condition.dopplerHz);
    end
    scenario = scenarioCache{cacheKey};
    pointCfg = runCfg;
    pointCfg.SNRdB = condition.snrDb;
    pointCfg.fdHz = condition.dopplerHz;
    pointCfg.noiseVar = 10^(-condition.snrDb/10);
    pointCfg.rho = ofdm.uavDopplerToRho(pointCfg.fdHz, pointCfg.Tsym);
    packet = auditRealizePairedSnrScenario(pointCfg, scenario, condition.snrDb);
    methods = cfg.historicalMethods(1:3);
    if condition.conditionId <= 3
        methods = cfg.historicalMethods;
    end
    for methodIndex = 1:numel(methods)
        method = methods(methodIndex);
        if localKeyComplete(keys, condition.conditionId, packetId, method)
            continue;
        end
        attempted = attempted + 1;
        localCheckpointSave(checkpointPath, rows, keys, attempted, completed, ...
            "running", expectedKeys);
        row = localRunOne(pointCfg, packet, scenario, condition, cfg, method, packetId);
        rows = [rows; row]; %#ok<AGROW>
        completed = completed + 1;
        key = table(condition.conditionId, packetId, method, ...
            'VariableNames', {'conditionId','packetId','historicalMethodName'});
        keys = [keys; key]; %#ok<AGROW>
        localCheckpointSave(checkpointPath, rows, keys, attempted, completed, ...
            "running", expectedKeys);
    end
end
end

function scenario = localBuildScenario(runCfg, cfg, packetId, dopplerHz)
scenarioCfg = runCfg;
scenarioCfg.masterSeed = physicalComRobustnessABPacketSeed(packetId, ...
    cfg.robustnessMasterSeed);
scenarioCfg.fdHz = dopplerHz;
scenarioCfg.rho = ofdm.uavDopplerToRho(dopplerHz, scenarioCfg.Tsym);
scenario = auditBuildPairedSnrScenario(scenarioCfg, 1);
scenario.channelInnovationHash = localChannelInnovationHash(...
    scenarioCfg.masterSeed, scenarioCfg.Npayload);
scenario.ltfHash = localLtfHash(scenarioCfg.masterSeed, scenarioCfg.active);
end

function value = localChannelInnovationHash(packetSeed, Npayload)
scenarioSeed = packetSeed + 100000;
channelSeed = scenarioSeed + 303;
rng(channelSeed, 'twister');
innovation = randn(4*12*Npayload, 1);
value = localHash(innovation);
end

function value = localLtfHash(packetSeed, active)
scenarioSeed = packetSeed + 100000;
pilotSeed = scenarioSeed + 505;
rng(pilotSeed, 'twister');
noise = 0.5 * (randn(numel(active), 2, 2) + ...
    1i*randn(numel(active), 2, 2));
value = localHash(single(noise));
end

function row = localRunOne(pointCfg, packet, scenario, condition, cfg, method, packetId)
online = struct('pilotObservation', packet.obs, 'receivedData', packet.y, ...
    'validDataMask', packet.validReMask, 'validReMask', packet.validReMask, ...
    'noiseVar', pointCfg.noiseVar, 'rho', pointCfg.rho, ...
    'Npayload', packet.Npayload, 'nCodeword', packet.nCodeword, ...
    'usefulBitMask', packet.usefulBitMask);
if method == "PerfectCSI_EP"
    Hhat = packet.H;
    receiver = auditMechanismOnlineReceive(pointCfg, online, Hhat, 0);
    estimate = struct('audit', struct('solverFailureCount', 0), ...
        'futureSymbolReadCount', 0, 'testTruthOnlineUseCount', 0, ...
        'finalCovariance', zeros(pointCfg.NFFT, 8, 8));
else
    estimate = auditMechanismRunSingleEstimator(pointCfg, online, method);
    Hhat = estimate.Hhat;
    receiver = auditMechanismOnlineReceive(pointCfg, online, Hhat, ...
        estimate.onlineEstimationRuntimeSeconds);
end
metric = auditMechanismOfflineDetectionMetrics(pointCfg, receiver, Hhat, ...
    packet.H, packet.qam, packet.codedBits, packet.validReMask);
solverFailure = estimate.audit.solverFailureCount;
allPsd = localCovariancePsd(estimate.finalCovariance);
allFinite = localAllFinite(metric, Hhat, receiver);
methodIndex = find(cfg.historicalMethods == method, 1);
physicalPacketHash = localHash([scenario.hashes.H; scenario.hashes.txBits; ...
    scenario.hashes.qam; scenario.hashes.unitNoise; ...
    localHash(packet.obs); localHash(packet.noise)]);
row = table( ...
    condition.experiment, condition.conditionId, packetId, ...
    physicalComRobustnessABPacketSeed(packetId, cfg.robustnessMasterSeed), ...
    condition.snrDb, condition.dopplerHz, cfg.payloadSymbols, method, ...
    cfg.paperMethods(methodIndex), cfg.causalityLabel, metric.csiNmse, ...
    metric.worstStreamCsiNmse, metric.p95ReNormalizedError, ...
    metric.p99ReNormalizedError, metric.deepFadeCsiNmse, metric.preLdpcBer, ...
    metric.softEvmRms, metric.softEvmRms^2, metric.evmEffectiveSinrDb, ...
    double(all(receiver.codewordPass)), metric.totalCodewordCount, ...
    metric.passedCodewordCount, metric.codewordPassRate, ...
    metric.payloadGoodputMbps, receiver.onlineRuntimeSeconds + ...
    metric.offlineAuditRuntimeSeconds, solverFailure, 0, 0, ...
    estimate.testTruthOnlineUseCount, allFinite, allPsd, ...
    scenario.hashes.txBits, localHash(scenario.codedBits), ...
    scenario.hashes.qam, ...
    scenario.channelInnovationHash, scenario.hashes.H, ...
    scenario.hashes.unitNoise, localHash(packet.noise), scenario.ltfHash, ...
    localHash(packet.obs), physicalPacketHash, ...
    'VariableNames', {'experiment','conditionId','packetId','packetSeed', ...
    'snrDb','dopplerHz','payloadSymbols','historicalMethodName', ...
    'paperMethodName','causalityLabel','avgCsiNmse','worstStreamNmse', ...
    'p95ReError','p99ReError','deepFadeNmse','preLdpcBer','softEvm', ...
    'softEvmSquared','effectiveSinrDb','codewordPass', ...
    'decodedCodewordCount','passedCodewordCount','codewordPassRate', ...
    'goodputMbps','processingTimeSec','solverFailure','paddingDaUses', ...
    'sameSymbolFeedback','truthLeak','allFinite','allPsd','txBitsHash', ...
    'codedBitsHash','qamHash','channelInnovationHash','hTrueHash', ...
    'baseAwgnHash','scaledAwgnHash','ltfHash','pilotObservationHash', ...
    'physicalPacketHash'});
end

function T = localEmptyPacketTable()
variableNames = {'experiment','conditionId','packetId','packetSeed', ...
    'snrDb','dopplerHz','payloadSymbols','historicalMethodName', ...
    'paperMethodName','causalityLabel','avgCsiNmse','worstStreamNmse', ...
    'p95ReError','p99ReError','deepFadeNmse','preLdpcBer','softEvm', ...
    'softEvmSquared','effectiveSinrDb','codewordPass', ...
    'decodedCodewordCount','passedCodewordCount','codewordPassRate', ...
    'goodputMbps','processingTimeSec','solverFailure','paddingDaUses', ...
    'sameSymbolFeedback','truthLeak','allFinite','allPsd','txBitsHash', ...
    'codedBitsHash','qamHash','channelInnovationHash','hTrueHash', ...
    'baseAwgnHash','scaledAwgnHash','ltfHash','pilotObservationHash', ...
    'physicalPacketHash'};
variableTypes = repmat({'double'}, size(variableNames));
stringVariables = ismember(variableNames, {'experiment','historicalMethodName', ...
    'paperMethodName','causalityLabel'});
logicalVariables = ismember(variableNames, {'allFinite','allPsd'});
variableTypes(stringVariables) = {'string'};
variableTypes(logicalVariables) = {'logical'};
T = table('Size', [0 numel(variableNames)], ...
    'VariableTypes', variableTypes, 'VariableNames', variableNames);
end

function tf = localKeyComplete(keys, conditionId, packetId, method)
tf = ~isempty(keys) && any(keys.conditionId == conditionId & ...
    keys.packetId == packetId & keys.historicalMethodName == method);
end

function localCheckpointSave(path, packetRows, completedKeys, attemptedRuns, ...
        completedRuns, status, expectedKeys)
tmp = [path '.tmp'];
rngState = rng;
checkpointVersion = "1.0";
save(tmp, 'packetRows', 'completedKeys', 'attemptedRuns', 'completedRuns', ...
    'status', 'expectedKeys', 'checkpointVersion', 'rngState', '-v7.3');
[ok, message] = movefile(tmp, path, 'f');
assert(ok, 'CheckpointAtomicMoveFailed', '%s', message);
end

function localCheckpointFailureSave(path, packetRows, completedKeys, ...
        attemptedRuns, completedRuns, expectedKeys)
if exist(path, 'file') == 2
    saved = load(path);
    hasCounts = isfield(saved, 'attemptedRuns') && ...
        isfield(saved, 'completedRuns');
    if hasCounts && saved.attemptedRuns >= attemptedRuns && ...
            saved.completedRuns >= completedRuns
        packetRows = saved.packetRows;
        completedKeys = saved.completedKeys;
        attemptedRuns = saved.attemptedRuns;
        completedRuns = saved.completedRuns;
    end
end
localCheckpointSave(path, packetRows, completedKeys, attemptedRuns, ...
    completedRuns, "failed", expectedKeys);
end

function localValidateCheckpoint(state)
assert(state.completedRuns == height(state.packetRows), ...
    'CheckpointCompletedCountMismatch');
assert(state.attemptedRuns >= state.completedRuns, ...
    'CheckpointAttemptedCountMismatch');
assert(height(state.completedKeys) == height(state.packetRows), ...
    'CheckpointKeyCountMismatch');
rowKeys = state.packetRows(:, ...
    {'conditionId','packetId','historicalMethodName'});
assert(isequal(sortrows(rowKeys), sortrows(state.completedKeys)), ...
    'CheckpointCompletedKeyMismatch');
assert(height(unique(rowKeys, 'rows')) == height(rowKeys), ...
    'CheckpointDuplicateCompletedKey');
hashNames = {'txBitsHash','codedBitsHash','qamHash','channelInnovationHash', ...
    'hTrueHash','baseAwgnHash','scaledAwgnHash','ltfHash', ...
    'pilotObservationHash','physicalPacketHash'};
for index = 1:numel(hashNames)
    assert(all(isfinite(state.packetRows.(hashNames{index}))), ...
        'CheckpointHashInvalid', 'Invalid saved hash field: %s', ...
        hashNames{index});
end
end

function localAssertFrozenSourceHashes(cfg)
expectedProtected = [
    "2047d3bc2f551b79975b1b0da545f5d237ae888e466751ded1a688e333f386bc"
    "e79ffdb32c006d15ccaf9783459ef626b8fd6f3b7fb6635ad0fc3ece271eb4d9"
    "c47be923f41fc66f902d98b09a8df6958e5c7fe13f26ff4be68e6098a65aece6"
];
expectedReceiver = [
    "03451df4a5eee32e5ec71169a6490d31999c9434dd5c1aef38b10d6a0cf935fb"
    "a4e6f222d377cc6b38e17d0e737a37d9d558cbc4b8da16f46181f30b754a3657"
];
assert(isequal(localFileHashes(cfg.protectedFiles), expectedProtected), ...
    'ProtectedSourceHashMismatch');
assert(isequal(localFileHashes(cfg.legacyReceiverFiles), expectedReceiver), ...
    'LegacyReceiverHashMismatch');
end

function hashes = localFileHashes(paths)
hashes = strings(numel(paths), 1);
for index = 1:numel(paths)
    hashes(index) = localSha256(paths(index));
end
end

function tf = localCovariancePsd(P)
tf = true;
if isempty(P)
    return;
end
for k = 1:size(P,1)
    M = squeeze(P(k,:,:));
    if any(~isfinite(M(:))) || min(eig((M+M')/2)) < -1e-9
        tf = false;
        return;
    end
end
end

function tf = localAllFinite(metric, Hhat, receiver)
values = [metric.csiNmse, metric.worstStreamCsiNmse, ...
    metric.p95ReNormalizedError, metric.p99ReNormalizedError, ...
    metric.deepFadeCsiNmse, metric.preLdpcBer, metric.softEvmRms, ...
    metric.evmEffectiveSinrDb, metric.codewordPassRate, ...
    metric.payloadGoodputMbps, receiver.onlineRuntimeSeconds, ...
    metric.offlineAuditRuntimeSeconds];
tf = all(isfinite(values)) && all(isfinite(Hhat(:))) && ...
    all(isfinite(receiver.llr(:)));
end

function precheck = localPrecheck(T, conditions, cfg)
checks = true(16,1);
for conditionId = 1:5
    rows = T(T.conditionId == conditionId, :);
    checks(1) = checks(1) && isscalar(unique(rows.txBitsHash));
    checks(2) = checks(2) && isscalar(unique(rows.hTrueHash));
    checks(3) = checks(3) && isscalar(unique(rows.baseAwgnHash));
    checks(4) = checks(4) && isscalar(unique(rows.ltfHash));
    checks(5) = checks(5) && isscalar(unique(rows.pilotObservationHash));
end
snrRows = T(ismember(T.conditionId, [1 2 3]), :);
checks(6) = isscalar(unique(snrRows.hTrueHash));
checks(7) = isscalar(unique(snrRows.baseAwgnHash));
dopplerRows = T(ismember(T.conditionId, [2 4 5]), :);
checks(8) = isscalar(unique(dopplerRows.txBitsHash));
checks(9) = isscalar(unique(dopplerRows.channelInnovationHash));
checks(10) = all(T.allFinite);
checks(11) = all(T.allPsd);
checks(12) = all(T.solverFailure == 0);
checks(13) = all(T.paddingDaUses == 0);
checks(14) = all(T.sameSymbolFeedback == 0);
checks(15) = all(T.truthLeak == 0);
checks(16) = nnz(T.conditionId == 2) == 4 && ...
    height(unique(T(T.conditionId == 2, {'conditionId','packetId', ...
    'historicalMethodName'}), 'rows')) == 4;
labels = [
    "withinConditionTxBits"
    "withinConditionHTrue"
    "withinConditionAwgn"
    "withinConditionLtf"
    "withinConditionPilotObservation"
    "crossSnrHTrue"
    "crossSnrBaseAwgn"
    "crossDopplerTxBits"
    "crossDopplerChannelInnovation"
    "allFinite"
    "allPsd"
    "solverFailureZero"
    "paddingDaUsesZero"
    "sameSymbolFeedbackZero"
    "ordinaryTruthLeakZero"
    "centerConditionSavedOnce"
];
precheck = struct('passed', all(checks), 'checks', table(labels, checks));
precheck.checks.Properties.VariableNames = {'gate','passed'};
precheck.expectedRows = 18;
precheck.actualRows = height(T);
precheck.conditions = conditions;
precheck.methods = cfg.historicalMethods;
end

function text = localPrecheckText(precheck)
lines = [
    "PhysicalCom robustness A/B packetId=1 precheck"
    sprintf("actualRows=%d", precheck.actualRows)
    sprintf("expectedRows=%d", precheck.expectedRows)
    sprintf("passed=%d", precheck.passed)
];
for index = 1:height(precheck.checks)
    lines(end+1) = sprintf("%s=%d", precheck.checks.gate(index), ...
        precheck.checks.passed(index)); %#ok<AGROW>
end
text = strjoin(lines, newline);
end

function design = localDesignTable(conditions, cfg)
grid = physicalComRobustnessABConditionGrid(cfg);
design = table();
for index = 1:height(grid)
    conditionId = find(conditions.snrDb == grid.snrDb(index) & ...
        conditions.dopplerHz == grid.dopplerHz(index), 1);
    row = table(conditionId, grid.experimentMembership(index), ...
        grid.snrDb(index), grid.dopplerHz(index), ...
        grid.historicalMethodName(index), grid.paperMethodName(index), ...
        grid.packetCount(index), cfg.causalityLabel, ...
        'VariableNames', {'conditionId','experiment','snrDb','dopplerHz', ...
        'historicalMethodName','paperMethodName','packetCount', ...
        'causalityLabel'});
    design = [design; row]; %#ok<AGROW>
end
end

function summary = localSummary(T, conditions, cfg)
metricNames = ["avgCsiNmse","preLdpcBer","softEvm","goodputMbps", ...
    "processingTimeSec","codewordPassRate"];
rows = cell(21,1);
cursor = 0;
for experimentIndex = 1:2
    if experimentIndex == 1
        conditionIds = [1 2 3];
        methods = cfg.historicalMethods;
        experiment = "A";
    else
        conditionIds = [4 2 5];
        methods = cfg.historicalMethods(1:3);
        experiment = "B";
    end
    for conditionId = conditionIds
        for method = methods.'
            cursor = cursor + 1;
            x = T(T.conditionId == conditionId & ...
                T.historicalMethodName == method, :);
            c = conditions(conditions.conditionId == conditionId, :);
            values = zeros(1,numel(metricNames));
            medians = values; stds = values; finiteCounts = values; failures = values;
            for m = 1:numel(metricNames)
                data = x.(metricNames(m));
                finiteCounts(m) = nnz(isfinite(data));
                failures(m) = nnz(~isfinite(data));
                values(m) = mean(data, 'omitnan');
                medians(m) = median(data, 'omitnan');
                stds(m) = std(data, 'omitnan');
            end
            rows{cursor} = table(experiment, conditionId, c.snrDb, ...
                c.dopplerHz, method, x.paperMethodName(1), cfg.packetCount, ...
                values(1), medians(1), stds(1), finiteCounts(1), failures(1), ...
                values(2), medians(2), stds(2), finiteCounts(2), failures(2), ...
                values(3), medians(3), stds(3), finiteCounts(3), failures(3), ...
                values(4), medians(4), stds(4), finiteCounts(4), failures(4), ...
                values(5), medians(5), stds(5), finiteCounts(5), failures(5), ...
                values(6), medians(6), stds(6), finiteCounts(6), failures(6), ...
                'VariableNames', {'experiment','conditionId','snrDb','dopplerHz', ...
                'historicalMethodName','paperMethodName','packetCount', ...
                'meanAvgCsiNmse','medianAvgCsiNmse','stdAvgCsiNmse', ...
                'finiteAvgCsiNmse','failureAvgCsiNmse','meanPreLdpcBer', ...
                'medianPreLdpcBer','stdPreLdpcBer','finitePreLdpcBer', ...
                'failurePreLdpcBer','meanSoftEvm','medianSoftEvm','stdSoftEvm', ...
                'finiteSoftEvm','failureSoftEvm','meanGoodputMbps', ...
                'medianGoodputMbps','stdGoodputMbps','finiteGoodputMbps', ...
                'failureGoodputMbps','meanProcessingTimeSec', ...
                'medianProcessingTimeSec','stdProcessingTimeSec', ...
                'finiteProcessingTimeSec','failureProcessingTimeSec', ...
                'meanCodewordPassRate','medianCodewordPassRate', ...
                'stdCodewordPassRate','finiteCodewordPassRate', ...
                'failureCodewordPassRate'});
        end
    end
end
summary = vertcat(rows{:});
end

function [paired, bootstrap] = localPairedStatistics(T, conditions, cfg)
metricNames = ["avgCsiNmse","preLdpcBer","softEvm","goodputMbps", ...
    "codewordPass"];
rowsPaired = cell(60,1);
rowsBootstrap = cell(60,1);
cursor = 0;
for experimentIndex = 1:2
    if experimentIndex == 1
        conditionIds = [1 2 3];
        experiment = "A";
    else
        conditionIds = [4 2 5];
        experiment = "B";
    end
    for conditionId = conditionIds
        for reference = ["BaseKalmanCausal_EP","FixedRadius3Causal_EP"]
            proposed = T(T.conditionId == conditionId & ...
                T.historicalMethodName == "CovarianceAwareLocalDAKalmanCausal_EP", :);
            referenceRows = T(T.conditionId == conditionId & ...
                T.historicalMethodName == reference, :);
            for metric = metricNames
                cursor = cursor + 1;
                [p, r, d] = localPairMetric(proposed, referenceRows, metric);
                ci = localBootstrapMean(d, cfg.bootstrapSeed, cfg.bootstrapCount);
                bothPass = nnz(p > 0 & r > 0);
                bothFail = nnz(p <= 0 & r <= 0);
                proposedOnly = nnz(p > 0 & r <= 0);
                referenceOnly = nnz(p <= 0 & r > 0);
                c = conditions(conditions.conditionId == conditionId, :);
                rowsPaired{cursor} = table(experiment, conditionId, c.snrDb, ...
                    c.dopplerHz, "CovarianceAwareLocalDAKalmanCausal_EP", ...
                    reference, metric, numel(d), mean(p), mean(r), mean(d), ...
                    median(d), bothPass, bothFail, proposedOnly, referenceOnly, ...
                    mean(p > 0), mean(r > 0), mean(p > 0)-mean(r > 0), ...
                    'VariableNames', {'experiment','conditionId','snrDb', ...
                    'dopplerHz','proposedMethod','referenceMethod','metric', ...
                    'pairCount','proposedMean','referenceMean', ...
                    'meanPairedDifference','medianPairedDifference', ...
                    'bothPass','bothFail','proposedOnlyPass','referenceOnlyPass', ...
                    'proposedPassRate','referencePassRate','passRateDifference'});
                rowsBootstrap{cursor} = table(experiment, conditionId, ...
                    c.snrDb, c.dopplerHz, ...
                    "CovarianceAwareLocalDAKalmanCausal_EP", reference, metric, ...
                    cfg.bootstrapCount, cfg.bootstrapSeed, mean(d), ci(1), ci(2), ...
                    cfg.confidenceLevel, ...
                    'VariableNames', {'experiment','conditionId','snrDb', ...
                    'dopplerHz','proposedMethod','referenceMethod','metric', ...
                    'bootstrapCount','bootstrapSeed','estimate','ciLower', ...
                    'ciUpper','confidenceLevel'});
            end
        end
    end
end
paired = vertcat(rowsPaired{:});
bootstrap = vertcat(rowsBootstrap{:});
end

function [proposed, reference, difference] = localPairMetric(proposedRows, ...
        referenceRows, metric)
proposedRows = sortrows(proposedRows, 'packetId');
referenceRows = sortrows(referenceRows, 'packetId');
assert(isequal(proposedRows.packetId, referenceRows.packetId), ...
    'PairPacketMismatch', 'Paired packet IDs do not match.');
if metric == "codewordPass"
    proposed = proposedRows.codewordPass;
    reference = referenceRows.codewordPass;
else
    proposed = proposedRows.(metric);
    reference = referenceRows.(metric);
end
difference = proposed-reference;
end

function ci = localBootstrapMean(values, seed, count)
rng(seed, 'twister');
n = numel(values);
indices = randi(n, n, count);
estimates = mean(values(indices), 1);
ci = [localPercentile(estimates, .025), localPercentile(estimates, .975)];
end

function value = localPercentile(values, probability)
values = sort(values(:));
position = 1 + (numel(values)-1)*probability;
lowerIndex = floor(position);
upperIndex = ceil(position);
if lowerIndex == upperIndex
    value = values(lowerIndex);
else
    value = values(lowerIndex) + (position-lowerIndex) * ...
        (values(upperIndex)-values(lowerIndex));
end
end

function runtime = localRuntime(T, conditions, cfg)
rows = cell(21,1);
cursor = 0;
for experimentIndex = 1:2
    if experimentIndex == 1
        conditionIds = [1 2 3]; methods = cfg.historicalMethods; experiment = "A";
    else
        conditionIds = [4 2 5]; methods = cfg.historicalMethods(1:3); experiment = "B";
    end
    for conditionId = conditionIds
        for method = methods.'
            cursor = cursor+1;
            x = T(T.conditionId == conditionId & T.historicalMethodName == method,:);
            c = conditions(conditions.conditionId == conditionId,:);
            rows{cursor} = table(experiment, conditionId, c.snrDb, c.dopplerHz, method, ...
                x.paperMethodName(1), height(x), mean(x.processingTimeSec), ...
                median(x.processingTimeSec), std(x.processingTimeSec), ...
                'VariableNames', {'experiment','conditionId','snrDb','dopplerHz', ...
                'historicalMethodName','paperMethodName','packetCount', ...
                'meanProcessingTimeSec','medianProcessingTimeSec','stdProcessingTimeSec'});
        end
    end
end
runtime = vertcat(rows{:});
for index = 1:height(runtime)
    base = runtime.experiment == runtime.experiment(index) & ...
        runtime.conditionId == runtime.conditionId(index) & ...
        runtime.historicalMethodName == "BaseKalmanCausal_EP";
    fixed = runtime.experiment == runtime.experiment(index) & ...
        runtime.conditionId == runtime.conditionId(index) & ...
        runtime.historicalMethodName == "FixedRadius3Causal_EP";
    runtime.relativeRuntimeToBase(index) = runtime.meanProcessingTimeSec(index) / ...
        runtime.meanProcessingTimeSec(base);
    runtime.relativeRuntimeToFixed(index) = runtime.meanProcessingTimeSec(index) / ...
        runtime.meanProcessingTimeSec(fixed);
end
end

function hashes = localPairingHashes(T)
hashes = unique(T(:, {'conditionId','packetId','snrDb','dopplerHz', ...
    'txBitsHash','codedBitsHash','qamHash','channelInnovationHash', ...
    'hTrueHash','baseAwgnHash','scaledAwgnHash','ltfHash', ...
    'pilotObservationHash','physicalPacketHash'}), 'rows');
end

function claimGate = localClaimGate(summary, paired, bootstrap)
rows = cell(4,1);
snrPair = paired(paired.experiment == "A", :);
dopplerPair = paired(paired.experiment == "B", :);
snrMean = localGateMeans(summary, "A", [1 2 3]);
dopplerMean = localGateMeans(summary, "B", [4 2 5]);
snrNmse = localGateCi(bootstrap, "A", "avgCsiNmse", [1 2 3], ...
    "BaseKalmanCausal_EP");
snrBer = localGateCi(bootstrap, "A", "preLdpcBer", [1 2 3], ...
    "BaseKalmanCausal_EP");
dopplerNmse = localGateCi(bootstrap, "B", "avgCsiNmse", [4 2 5], ...
    "BaseKalmanCausal_EP");
rows{1} = localClaimRow("snrStableImprovementVsBase", ...
    "SNR robustness", ...
    "Proposed lower mean NMSE and BER at all SNR points; CI <0 at >=2/3", ...
    all(snrMean.proposedNmse < snrMean.baseNmse) && ...
    all(snrMean.proposedBer < snrMean.baseBer) && ...
    nnz(snrNmse.ciUpper < 0) >= 2 && nnz(snrBer.ciUpper < 0) >= 2, ...
    "所提方法在15–25 dB范围内对Base表现出稳定改善。", ...
    snrPair, "BaseKalmanCausal_EP", "avgCsiNmse,preLdpcBer");
rows{2} = localClaimRow("dopplerTrackingAdvantageVsBase", ...
    "Doppler robustness", ...
    "Proposed lower mean NMSE and BER at all Doppler points; 300 Hz lower; NMSE CI <0 at >=2/3", ...
    all(dopplerMean.proposedNmse < dopplerMean.baseNmse) && ...
    all(dopplerMean.proposedBer < dopplerMean.baseBer) && ...
    dopplerMean.proposedNmse(dopplerMean.conditionId == 5) < ...
    dopplerMean.baseNmse(dopplerMean.conditionId == 5) && ...
    dopplerMean.proposedBer(dopplerMean.conditionId == 5) < ...
    dopplerMean.baseBer(dopplerMean.conditionId == 5) && ...
    nnz(dopplerNmse.ciUpper < 0) >= 2, ...
    "所提方法在100–300 Hz范围内保持信道跟踪优势。", ...
    dopplerPair, "BaseKalmanCausal_EP", "avgCsiNmse,preLdpcBer");
covMeanPass = all(snrMean.proposedNmse < snrMean.fixedNmse) && ...
    all(dopplerMean.proposedNmse(ismember(dopplerMean.conditionId, [4 5])) < ...
    dopplerMean.fixedNmse(ismember(dopplerMean.conditionId, [4 5])));
covCi = [localGateCi(bootstrap, "A", "avgCsiNmse", [1 2 3], ...
    "FixedRadius3Causal_EP").ciUpper; ...
    localGateCi(bootstrap, "B", "avgCsiNmse", [4 5], ...
    "FixedRadius3Causal_EP").ciUpper];
rows{3} = localClaimRow("covarianceIncrementVsFixed", ...
    "Covariance contribution", ...
    "Proposed lower mean NMSE than Fixed at all five unique points; CI <0 at >=4/5", ...
    covMeanPass && nnz(covCi < 0) >= 4, ...
    "候选相关协方差建模相对于Fixed方法提供稳定增益。", ...
    paired, "FixedRadius3Causal_EP", "avgCsiNmse");
goodput = localGoodputClaim(bootstrap);
rows{4} = localClaimRow("significantGoodputIncrease", ...
    "Goodput", "CI completely above zero", goodput, ...
    "significant improvement", bootstrap, "BaseKalmanCausal_EP", "goodputMbps");
claimGate = vertcat(rows{:});
claimGate.allowedTextChinese = string(claimGate.allowedTextChinese);
claimGate = claimGate(:, {'claimId','claimTopic','gateCondition','gatePass', ...
    'allowedTextEnglish','allowedTextChinese','forbiddenText', ...
    'supportingConditions','supportingMetrics'});
end

function row = localClaimRow(id, topic, condition, pass, allowedChinese, support, reference, metric)
row = table(string(id), string(topic), string(condition), logical(pass), ...
    "Only if every registered gate passes.", allowedChinese, ...
    "Do not claim strict causality, real-time, pilot-overhead reduction, UAV-specific, universal robustness, or hardware readiness.", ...
    string(join(unique(string(support.experiment)), ',')), string(metric), ...
    'VariableNames', {'claimId','claimTopic','gateCondition','gatePass', ...
    'allowedTextEnglish','allowedTextChinese','forbiddenText', ...
    'supportingConditions','supportingMetrics'});
if reference == "FixedRadius3Causal_EP"
    row.forbiddenText = row.forbiddenText + " Proposed-vs-Fixed wording must follow the actual CI.";
end
end

function values = localGateMeans(summary, experiment, conditionIds)
values = struct('conditionId', conditionIds(:), 'proposedNmse', zeros(numel(conditionIds),1), ...
    'baseNmse', zeros(numel(conditionIds),1), 'fixedNmse', zeros(numel(conditionIds),1), ...
    'proposedBer', zeros(numel(conditionIds),1), 'baseBer', zeros(numel(conditionIds),1));
for index = 1:numel(conditionIds)
    conditionId = conditionIds(index);
    x = summary(summary.experiment == experiment & summary.conditionId == conditionId, :);
    values.proposedNmse(index) = x.meanAvgCsiNmse(x.historicalMethodName == "CovarianceAwareLocalDAKalmanCausal_EP");
    values.baseNmse(index) = x.meanAvgCsiNmse(x.historicalMethodName == "BaseKalmanCausal_EP");
    values.fixedNmse(index) = x.meanAvgCsiNmse(x.historicalMethodName == "FixedRadius3Causal_EP");
    values.proposedBer(index) = x.meanPreLdpcBer(x.historicalMethodName == "CovarianceAwareLocalDAKalmanCausal_EP");
    values.baseBer(index) = x.meanPreLdpcBer(x.historicalMethodName == "BaseKalmanCausal_EP");
end
end

function values = localGateCi(bootstrap, experiment, metric, conditionIds, ...
        referenceMethod)
values = struct('conditionId', conditionIds(:), 'ciLower', zeros(numel(conditionIds),1), ...
    'ciUpper', zeros(numel(conditionIds),1));
for index = 1:numel(conditionIds)
    x = bootstrap(bootstrap.experiment == experiment & ...
        bootstrap.conditionId == conditionIds(index) & bootstrap.metric == metric & ...
        bootstrap.referenceMethod == referenceMethod, :);
    assert(height(x) == 1, 'ClaimGateCiLookupMismatch', ...
        'Expected one bootstrap row for the requested comparison.');
    values.ciLower(index) = x.ciLower(1);
    values.ciUpper(index) = x.ciUpper(1);
end
end

function pass = localGoodputClaim(bootstrap)
x = bootstrap(bootstrap.metric == "goodputMbps" & ...
    bootstrap.referenceMethod == "BaseKalmanCausal_EP", :);
pass = any(x.ciLower > 0);
end

function localAuditFinalRows(T, cfg)
assert(height(T) == 360, 'FinalRowCountMismatch');
assert(height(unique(T(:, {'conditionId','packetId','historicalMethodName'}), ...
    'rows')) == 360, 'DuplicateReceiverCombination');
assert(numel(unique(T.packetId)) == 20, 'PhysicalPacketIdCountMismatch');
assert(nnz(T.conditionId <= 3) == 240, 'ExperimentARowCountMismatch');
bMask = ismember(T.conditionId, [4 2 5]) & ...
    T.historicalMethodName ~= "PerfectCSI_EP";
assert(nnz(bMask) == 180, 'ExperimentBLogicalRowCountMismatch');
assert(all(T.allFinite) && all(T.allPsd), 'FiniteOrPsdGateFailed');
assert(all(T.solverFailure == 0), 'SolverFailureGateFailed');
assert(all(T.paddingDaUses == 0), 'PaddingDaUseGateFailed');
assert(all(T.sameSymbolFeedback == 0), 'SameSymbolFeedbackGateFailed');
assert(all(T.truthLeak == 0), 'TruthLeakGateFailed');
for method = cfg.historicalMethods.'
    expected = 100;
    if method == "PerfectCSI_EP"
        expected = 60;
    end
    assert(nnz(T.historicalMethodName == method) == expected, ...
        'MethodRunCountMismatch', '%s', method);
end
end

function localMakeAllFigures(T, cfg, outputDir)
localMakeFigures(T, [1 2 3], cfg.historicalMethods, ...
    cfg.paperMethods, "A", "snrDb", cfg, outputDir);
localMakeFigures(T, [4 2 5], cfg.historicalMethods(1:3), ...
    cfg.paperMethods(1:3), "B", "dopplerHz", cfg, outputDir);
end

function localMakeFigures(T, conditionIds, methods, paperMethods, ...
        experiment, xField, cfg, outputDir)
metricFields = ["avgCsiNmse","preLdpcBer","softEvm","codewordPassRate","goodputMbps"];
metricNames = ["nmse","pre_ldpc_ber","soft_evm","codeword_pass","goodput"];
for metricIndex = 1:numel(metricFields)
    metric = metricFields(metricIndex);
    if experiment == "A"
        axisName = "snr";
    else
        axisName = "doppler";
    end
    figureBase = sprintf('physicalcom_%s_%s_%s', experiment, ...
        axisName, metricNames(metricIndex));
    fig = figure('Visible', 'off');
    hold on;
    for methodIndex = 1:numel(methods)
        xValues = zeros(numel(conditionIds),1);
        yValues = zeros(numel(conditionIds),1);
        lowerCi = zeros(numel(conditionIds),1);
        upperCi = zeros(numel(conditionIds),1);
        for index = 1:numel(conditionIds)
            conditionId = conditionIds(index);
            row = T(T.conditionId == conditionId & ...
                T.historicalMethodName == methods(methodIndex), :);
            xValues(index) = row.(xField)(1);
            data = row.(metric);
            yValues(index) = mean(data);
            ci = localBootstrapMean(data, cfg.bootstrapSeed, cfg.bootstrapCount);
            lowerCi(index) = ci(1);
            upperCi(index) = ci(2);
        end
        if metric == "avgCsiNmse" || metric == "preLdpcBer"
            yValues = max(yValues, eps);
            lowerCi = max(lowerCi, eps);
            upperCi = max(upperCi, eps);
        end
        errorbar(xValues, yValues, yValues-lowerCi, upperCi-yValues, 'o-', ...
            'DisplayName', paperMethods(methodIndex), 'LineWidth', 1.1);
    end
    if metric == "avgCsiNmse" || metric == "preLdpcBer"
        set(gca, 'YScale', 'log');
    end
    if experiment == "A"
        xlabel('SNR (dB)');
    else
        xlabel('Doppler (Hz)');
    end
    ylabel(metric);
    title(sprintf('%s robustness: %s', experiment, metric));
    legend('Location', 'best', 'Interpreter', 'none');
    grid on;
    text(0.02, 0.02, 'packetCount=20; packet-buffered blockwise calibration', ...
        'Units', 'normalized', 'Interpreter', 'none');
    savefig(fig, fullfile(outputDir, [figureBase '.fig']));
    exportgraphics(fig, fullfile(outputDir, [figureBase '.png']));
    exportgraphics(fig, fullfile(outputDir, [figureBase '.pdf']), 'ContentType', 'vector');
    close(fig);
end
end

function text = localFinalReport(T, summary, paired, claimGate, cfg)
lines = [
    "PhysicalCom robustness A/B experiment report"
    ""
    "receiverRuns=360"
    "uniqueReceiverRuns=360"
    "physicalPacketIds=20"
    "SNR conditions=[15 20 25] dB at Doppler=200 Hz"
    "Doppler conditions=[100 200 300] Hz at SNR=20 dB"
    "A_result_rows=240"
    "B_logic_result_rows=180 (60 center rows reused from A)"
    "centerConditionReused=true"
    "BaseRuns=100"
    "FixedRuns=100"
    "ProposedRuns=100"
    "PerfectCSIRuns=60"
    sprintf("pairingPass=%d", localPairingPass(T))
    sprintf("allFinite=%d", all(T.allFinite))
    sprintf("allPsd=%d", all(T.allPsd))
    sprintf("solverFailures=%d", nnz(T.solverFailure))
    sprintf("paddingDaUses=%d", sum(T.paddingDaUses))
    sprintf("sameSymbolFeedback=%d", sum(T.sameSymbolFeedback))
    sprintf("ordinaryTruthLeaks=%d", sum(T.truthLeak))
    sprintf("snrRobustnessGate=%d", claimGate.gatePass(claimGate.claimId == "snrStableImprovementVsBase"))
    sprintf("dopplerRobustnessGate=%d", claimGate.gatePass(claimGate.claimId == "dopplerTrackingAdvantageVsBase"))
    sprintf("covarianceContributionGate=%d", claimGate.gatePass(claimGate.claimId == "covarianceIncrementVsFixed"))
    "postLdpcBer=not_used"
    "causalityLabel=blockwise_calibrated_not_strict_symbol_causal"
    "No strict causal, real-time, pilot-overhead, UAV-specific, universal robustness, or hardware-ready claim is permitted."
    sprintf("summaryRows=%d", height(summary))
    sprintf("pairedRows=%d", height(paired))
    sprintf("bootstrapCount=%d", cfg.bootstrapCount)
    "COMPLETE_EXPERIMENT_A=1"
    "COMPLETE_EXPERIMENT_B=1"
    "COMPLETE_ROBUSTNESS_AB=1"
];
text = strjoin(lines, newline);
end

function text = localFinalManifest(cfg, T, claimGate)
protected = cfg.protectedFiles;
lines = [
    "experimentName=run_physicalcom_robustness_ab_v1"
    "receiverRuns=360"
    "uniqueReceiverRuns=360"
    "physicalPacketIds=20"
    "robustnessMasterSeed=2026072801"
    "bootstrapSeed=2026072802"
    "bootstrapCount=10000"
    "confidenceLevel=0.95"
    "payloadSymbols=169"
    "packetCount=20"
    "fixedRadius=3"
    "llrThreshold=2.5"
    "minEffectiveSamples=2"
    "gramRcondThreshold=0.001"
    "RDA=RLS"
    "Joseph=true"
    "paddingExcluded=true"
    "noSameSymbolFeedback=true"
    "maxDaUpdatesPerTarget=1"
    "causalityLabel=blockwise_calibrated_not_strict_symbol_causal"
    sprintf("allFinite=%d", all(T.allFinite))
    sprintf("allPsd=%d", all(T.allPsd))
    sprintf("solverFailures=%d", nnz(T.solverFailure))
    sprintf("paddingDaUses=%d", sum(T.paddingDaUses))
    sprintf("sameSymbolFeedback=%d", sum(T.sameSymbolFeedback))
    sprintf("truthLeaks=%d", sum(T.truthLeak))
    sprintf("claimGateRows=%d", height(claimGate))
    "postLdpcBer=forbidden"
    "legacyReceiverModified=0"
    "sourceAlgorithmModified=0"
    ""
    "PROTECTED_HASHES"
];
for index = 1:numel(protected)
    lines(end+1) = sprintf("%s|sha256=%s", protected(index), localSha256(protected(index))); %#ok<AGROW>
end
lines(end+1) = "OUTPUT_FIGURES=physicalcom_A/B_*_{nmse,pre_ldpc_ber,soft_evm,codeword_pass,goodput}.{pdf,png,fig}";
text = strjoin(lines, newline);
end

function value = localPairingPass(T)
value = all(T.allFinite) && all(T.allPsd) && all(T.solverFailure == 0) && ...
    numel(unique(T.packetId)) == 20 && height(unique(T(:, ...
    {'conditionId','packetId','historicalMethodName'}), 'rows')) == 360;
end

function result = localFinishResult(state, outputDir)
requiredMarkers = ["COMPLETE_EXPERIMENT_A","COMPLETE_EXPERIMENT_B", ...
    "COMPLETE_ROBUSTNESS_AB"];
for marker = requiredMarkers
    assert(exist(fullfile(outputDir, marker), 'file') == 2, ...
        'CompleteCheckpointMarkerMissing', ...
        'Complete checkpoint exists but marker is missing: %s', marker);
end
result = struct('status', "complete", 'receiverRuns', state.completedRuns, ...
    'uniqueReceiverRuns', state.completedRuns, 'outputDirectory', string(outputDir));
fprintf('Existing complete run retained: receiverRuns=%d\n', state.completedRuns);
end

function tf = localRequiredArtifactsPresent(outputDir)
names = localRequiredArtifactNames(true);
tf = true;
for index = 1:numel(names)
    tf = tf && exist(fullfile(outputDir, names(index)), 'file') == 2;
end
end

function localAssertRequiredDataArtifacts(outputDir)
names = localRequiredArtifactNames(false);
for index = 1:numel(names)
    assert(exist(fullfile(outputDir, names(index)), 'file') == 2, ...
        'RequiredOutputMissing', 'Required output is missing: %s', ...
        names(index));
end
end

function names = localRequiredArtifactNames(includeMarkers)
names = [
    "robustness_ab_design.csv"
    "robustness_ab_packet_level.csv"
    "robustness_ab_summary.csv"
    "robustness_ab_paired_statistics.csv"
    "robustness_ab_bootstrap_ci.csv"
    "robustness_ab_pairing_hashes.csv"
    "robustness_ab_runtime_audit.csv"
    "robustness_ab_claim_gate.csv"
    "robustness_ab_checkpoint.mat"
    "robustness_ab_report.txt"
    "robustness_ab_manifest.txt"
    strings(30,1)
];
cursor = 11;
experiments = ["A","B"];
axes = ["snr","doppler"];
metrics = ["nmse","pre_ldpc_ber","soft_evm","codeword_pass","goodput"];
extensions = ["pdf","png","fig"];
for experimentIndex = 1:2
    for metricIndex = 1:numel(metrics)
        for extensionIndex = 1:numel(extensions)
            cursor = cursor + 1;
            names(cursor) = sprintf("physicalcom_%s_%s_%s.%s", ...
                experiments(experimentIndex), axes(experimentIndex), ...
                metrics(metricIndex), extensions(extensionIndex));
        end
    end
end
if includeMarkers
    names = [names; "COMPLETE_EXPERIMENT_A"; ...
        "COMPLETE_EXPERIMENT_B"; "COMPLETE_ROBUSTNESS_AB"];
end
end

function value = localHash(data)
values = double(data(:));
weights = mod((1:numel(values))', 104729) + 1;
value = sum(real(values).*weights) + sqrt(2)*sum(imag(values).*weights) + ...
    sum(abs(values).^2)/max(numel(values),1);
end

function hash = localSha256(path)
fileId = fopen(path, 'r');
assert(fileId >= 0, 'HashInputOpenFailed', 'Cannot open: %s', path);
cleanup = onCleanup(@() fclose(fileId));
bytes = fread(fileId, Inf, '*uint8');
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(bytes);
hashBytes = typecast(digest.digest(), 'uint8');
hash = string(lower(reshape(dec2hex(hashBytes,2).',1,[])));
end

function localWriteText(path, text)
fileId = fopen(path, 'w', 'n', 'UTF-8');
assert(fileId >= 0, 'OutputOpenFailed', 'Cannot open: %s', path);
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', text);
end
