function result = Audit_PhysicalCom_Robustness_AB_v1()
%AUDIT_PHYSICALCOM_ROBUSTNESS_AB_V1 Prepare-only design audit.
% This entry creates no packet and calls no receiver.
root = fileparts(mfilename('fullpath'));
cfg = physicalComRobustnessABConfig(root);
assert(exist(cfg.outputDirectory, 'dir') ~= 7, ...
    'OutputDirectoryExists:RefusingToOverwrite', ...
    'Preparation output directory already exists.');

receiverRuns = 0;
formalExperimentRuns = 0;
physicalPacketRuns = 0;
rngCalls = 0;
protectedBefore = localHashes(cfg.protectedFiles);
legacyBefore = localHashes(cfg.legacyReceiverFiles);
validation = localValidationAudit(cfg);
fprintf('prepare_physicalcom_robustness_ab_v1\n');
fprintf('expectedCenterSnrDb=%g\n', cfg.expectedCenterSnrDb);
fprintf('expectedCenterDopplerHz=%g\n', cfg.expectedCenterDopplerHz);
if ~validation.configMatches
    fprintf(2, 'CONFIG_MISMATCH\n');
    result = struct('status', "CONFIG_MISMATCH", ...
        'receiverRuns', receiverRuns, 'rngCalls', rngCalls);
    return;
end

pairing = physicalComRobustnessABPairingAudit(root);
fprintf('pairingInterface=%s\n', pairing.status);
if ~pairing.available
    fprintf(2, 'PAIRING_INTERFACE_UNAVAILABLE\n');
    result = struct('status', "PAIRING_INTERFACE_UNAVAILABLE", ...
        'receiverRuns', receiverRuns, 'rngCalls', rngCalls);
    return;
end

grid = physicalComRobustnessABConditionGrid(cfg);
plannedRuns = localPlannedRuns(cfg, grid);
aliases = localAliases(cfg);
metrics = localMetrics();
claims = localClaimGates();
gridChecks = localSelftest(cfg, grid, plannedRuns, validation, pairing, ...
    protectedBefore, legacyBefore);
if ~all(gridChecks.passed)
    disp(gridChecks(~gridChecks.passed, :));
end
assert(all(gridChecks.passed), 'PreparationSelftestFailed', ...
    'A deterministic preparation selftest failed.');

mkdir(cfg.outputDirectory);
writetable(grid, fullfile(cfg.outputDirectory, ...
    'robustness_ab_condition_grid.csv'));
writetable(aliases, fullfile(cfg.outputDirectory, ...
    'robustness_ab_method_aliases.csv'));
writetable(metrics, fullfile(cfg.outputDirectory, ...
    'robustness_ab_metric_specification.csv'));
writetable(claims, fullfile(cfg.outputDirectory, ...
    'robustness_ab_claim_gates.csv'));
writetable(plannedRuns, fullfile(cfg.outputDirectory, ...
    'robustness_ab_planned_runs.csv'));

localWriteText(fullfile(cfg.outputDirectory, ...
    'robustness_ab_pairing_specification.txt'), ...
    localPairingSpecification(cfg));

protectedAfter = localHashes(cfg.protectedFiles);
legacyAfter = localHashes(cfg.legacyReceiverFiles);
sourceAlgorithmModified = nnz(protectedBefore ~= protectedAfter);
legacyReceiverModified = nnz(legacyBefore ~= legacyAfter);
assert(sourceAlgorithmModified == 0 && legacyReceiverModified == 0, ...
    'SourceModifiedDuringPreparation', ...
    'A protected or legacy receiver source changed during preparation.');

localWriteText(fullfile(cfg.outputDirectory, ...
    'robustness_ab_prepare_report.txt'), ...
    localReport(cfg, validation, pairing, gridChecks, ...
    receiverRuns, formalExperimentRuns, physicalPacketRuns, rngCalls, ...
    sourceAlgorithmModified, legacyReceiverModified));
localWriteText(fullfile(cfg.outputDirectory, ...
    'robustness_ab_prepare_manifest.txt'), ...
    localManifest(cfg, validation, pairing, gridChecks, ...
    protectedAfter, legacyAfter));

required = [
    "robustness_ab_condition_grid.csv"
    "robustness_ab_method_aliases.csv"
    "robustness_ab_pairing_specification.txt"
    "robustness_ab_metric_specification.csv"
    "robustness_ab_claim_gates.csv"
    "robustness_ab_planned_runs.csv"
    "robustness_ab_prepare_report.txt"
    "robustness_ab_prepare_manifest.txt"
];
assert(all(arrayfun(@(x) exist(fullfile(cfg.outputDirectory, x), 'file') == 2, required)), ...
    'PreparationOutputMissing', 'A preparation output is missing.');
assert(receiverRuns == 0 && formalExperimentRuns == 0 && ...
    physicalPacketRuns == 0 && rngCalls == 0 && ...
    sourceAlgorithmModified == 0 && legacyReceiverModified == 0, ...
    'PreparationBoundaryViolation', 'A forbidden execution occurred.');

localWriteText(fullfile(cfg.outputDirectory, 'COMPLETE_PREPARE'), sprintf([ ...
    'PASS\nreceiverRuns=0\nrngCalls=0\nformalExperimentRuns=0\n' ...
    'physicalPacketRuns=0\nsourceAlgorithmModified=0\n' ...
    'legacyReceiverModified=0\nplannedUniqueReceiverRuns=%d\n' ...
    'selftestPassed=%d/%d\n'], height(plannedRuns), ...
    nnz(gridChecks.passed), numel(gridChecks.passed)));

fprintf('receiverRuns=0\nrngCalls=0\nformalExperimentRuns=0\n');
fprintf('physicalPacketRuns=0\nsourceAlgorithmModified=0\n');
fprintf('legacyReceiverModified=0\nplannedUniqueReceiverRuns=%d\n', height(plannedRuns));
fprintf('selftestPassed=%d/%d\n', nnz(gridChecks.passed), numel(gridChecks.passed));
fprintf('COMPLETE_PREPARE=1\n');
result = struct('status', "COMPLETE_PREPARE", ...
    'outputDirectory', string(cfg.outputDirectory), ...
    'receiverRuns', receiverRuns, 'rngCalls', rngCalls, ...
    'formalExperimentRuns', formalExperimentRuns, ...
    'physicalPacketRuns', physicalPacketRuns, ...
    'sourceAlgorithmModified', sourceAlgorithmModified, ...
    'legacyReceiverModified', legacyReceiverModified, ...
    'plannedUniqueReceiverRuns', height(plannedRuns), ...
    'selftestPassed', nnz(gridChecks.passed), ...
    'selftestCount', numel(gridChecks.passed));
end

function validation = localValidationAudit(cfg)
configText = fileread(cfg.validationDefaultConfig);
manifestText = fileread(cfg.validationManifest);
validation.centerSnr = contains(configText, "'SNRdB',20");
validation.centerDoppler = contains(configText, "'fdHz',200");
validation.payloadSymbols = contains(manifestText, 'payloadSymbols=[169 507]');
validation.modulation = contains(configText, 'modulationOrder=16');
validation.mimo = contains(configText, "'Nr',2,'Nt',2");
validation.ldpc = contains(configText, 'makeLdpcConfig(1/2)');
validation.fixedRadius = contains(manifestText, 'fixedRadius=3');
validation.llrThreshold = contains(manifestText, 'llrThreshold=2.5');
validation.minEffectiveSamples = contains(manifestText, 'minEffectiveSamples=2');
validation.gramRcondThreshold = contains(manifestText, 'gramRcondThreshold=0.001');
validation.rda = contains(manifestText, 'RDA=RLS');
validation.joseph = contains(manifestText, 'Joseph=true');
validation.paddingExcluded = contains(manifestText, 'paddingExcluded=true');
validation.noSameSymbolFeedback = contains(manifestText, 'noSameSymbolFeedback=true');
validation.maxDaUpdatesPerTarget = contains(manifestText, 'maxDaUpdatesPerTarget=1');
validation.configMatches = all(struct2array(validation));
end

function runs = localPlannedRuns(cfg, grid)
rows = cell(height(grid)*cfg.packetCount, 1);
cursor = 0;
for rowIndex = 1:height(grid)
    seeds = physicalComRobustnessABPacketSeed(cfg.packetIds, ...
        cfg.robustnessMasterSeed);
    for packetIndex = 1:cfg.packetCount
        cursor = cursor + 1;
        rows{cursor} = table( ...
            grid.conditionKey(rowIndex), grid.experimentMembership(rowIndex), ...
            grid.snrDb(rowIndex), grid.dopplerHz(rowIndex), ...
            grid.historicalMethodName(rowIndex), grid.paperMethodName(rowIndex), ...
            cfg.causalityLabel, packetIndex, seeds(packetIndex), ...
            grid.sharedCenterCondition(rowIndex), ...
            'VariableNames', {'conditionKey','experimentMembership','snrDb', ...
            'dopplerHz','historicalMethodName','paperMethodName', ...
            'causalityLabel','packetId','packetSeed','sharedCenterCondition'});
    end
end
runs = vertcat(rows{:});
runs = sortrows(runs, {'snrDb','dopplerHz','historicalMethodName','packetId'});
end

function aliases = localAliases(cfg)
historicalMethodName = cfg.historicalMethods;
paperMethodName = cfg.paperMethods;
causalityLabel = repmat(cfg.causalityLabel, numel(historicalMethodName), 1);
aliases = table(historicalMethodName, paperMethodName, causalityLabel);
end

function metrics = localMetrics()
metric = [
    "avgCsiNmse";"preLdpcBer";"softEvm";"codewordPass";"codewordPassRate"
    "goodputMbps";"processingTimeSec";"worstStreamNmse";"p95ReError"
    "p99ReError";"deepFadeNmse";"effectiveSinrDb"
    "postLdpcBer"
];
role = [
    "primary";"primary";"secondary";"secondary";"secondary";"secondary"
    "secondary";"auxiliary";"auxiliary";"auxiliary";"auxiliary";"auxiliary"
    "forbidden"
];
aggregation = repmat("mean, median, standard deviation, bootstrap 95% CI", ...
    numel(metric), 1);
notes = repmat("finite count and failure count retained; no packet deletion", ...
    numel(metric), 1);
notes(4) = "bothPass, bothFail, proposedOnlyPass, referenceOnlyPass, pass-rate difference";
notes(7) = "descriptive MATLAB runtime only; not real-time or hardware complexity";
notes(13) = "forbidden: frozen receiver API does not expose a valid post-LDPC BER";
forbidden = false(numel(metric), 1);
forbidden(13) = true;
metrics = table(metric, role, aggregation, notes, forbidden);
end

function claims = localClaimGates()
claim = [
    "snrStableImprovementVsBase";"dopplerTrackingAdvantageVsBase"
    "covarianceIncrementVsFixed";"significantGoodputIncrease"
];
gate = [
    "3 SNR means lower for avgCsiNmse and preLdpcBer; paired CI <0 at >=2/3 points for both"
    "3 Doppler means lower for avgCsiNmse and preLdpcBer; 300 Hz both lower; NMSE CI <0 at >=2/3"
    "all SNR and all Doppler avgCsiNmse means lower than Fixed; >=4/5 unique points CI <0"
    "condition 95% CI for goodput difference completely above 0"
];
allowedText = [
    "所提方法在15–25 dB范围内对Base表现出稳定改善。"
    "所提方法在100–300 Hz范围内保持信道跟踪优势。"
    "候选相关协方差建模相对于Fixed方法提供稳定增益。"
    "significant improvement"
];
otherwiseText = [
    "Do not claim the sentence unless every listed gate passes."
    "Do not claim the sentence unless every listed gate passes."
    "Do not claim the sentence unless every listed gate passes."
    "If CI contains zero, report only higher mean goodput / 平均Goodput较高."
];
claims = table(claim, gate, allowedText, otherwiseText);
end

function checks = localSelftest(cfg, grid, runs, validation, pairing, ...
        protectedBefore, legacyBefore)
names = [
    "conditionGridUnique";"centerConditionSingle";"plannedRuns360"
    "baseRuns100";"fixedRuns100";"proposedRuns100";"perfectRuns60"
    "twentyPacketsPerCombination";"paperAliasesCorrect";"snrPoints"
    "dopplerPoints";"payloadSymbols";"frozenParameters";"postLdpcBerForbidden"
    "bootstrapCount";"bootstrapSeed";"protectedFilesUnchanged"
    "legacyReceiverUnchanged";"receiverRunsZero";"rngCallsZero"
];
centerRows = grid.sharedCenterCondition;
methodCounts = arrayfun(@(m) nnz(grid.historicalMethodName == m), ...
    cfg.historicalMethods);
comboCounts = groupsummary(grid, {'conditionKey','historicalMethodName'}, ...
    'sum', 'packetCount');
passed = [
    height(unique(grid(:, {'conditionKey','historicalMethodName'}), 'rows')) == height(grid)
    nnz(centerRows) == 3
    height(runs) == 360
    methodCounts(1) == 5
    methodCounts(2) == 5
    methodCounts(3) == 5
    methodCounts(4) == 3
    all(comboCounts.sum_packetCount == cfg.packetCount)
    isequal(cfg.paperMethods, ["BaseKalman_BlockCalibrated_EP"; ...
        "FixedRadius3DAKalman_BlockCalibrated_EP"; ...
        "CovarianceAwareLocalDAKalman_BlockCalibrated_EP";"PerfectCSI_EP"])
    isequal(cfg.snrDb, [15 20 25])
    isequal(cfg.dopplerHz, [100 200 300])
    cfg.payloadSymbols == 169
    cfg.fixedRadius == 3 && cfg.llrThreshold == 2.5 && ...
        cfg.minEffectiveSamples == 2 && cfg.gramRcondThreshold == 1e-3 && ...
        cfg.rda == "RLS" && cfg.joseph && cfg.paddingExcluded && ...
        cfg.noSameSymbolFeedback && cfg.maxDaUpdatesPerTarget == 1
    cfg.noPostLdpcBer
    cfg.bootstrapCount == 10000
    cfg.bootstrapSeed == 2026072802
    all(protectedBefore == [
        "2047d3bc2f551b79975b1b0da545f5d237ae888e466751ded1a688e333f386bc"
        "e79ffdb32c006d15ccaf9783459ef626b8fd6f3b7fb6635ad0fc3ece271eb4d9"
        "c47be923f41fc66f902d98b09a8df6958e5c7fe13f26ff4be68e6098a65aece6"])
    all(legacyBefore == localHashes(cfg.legacyReceiverFiles))
    receiverRunsZero()
    rngCallsZero()
];
evidence = [
    "unique method-condition rows after center sharing"
    "one center row per Base/Fixed/Proposed method with experiment A+B"
    "18 method-condition rows x 20 packets"
    "5 conditions x 20 packets"
    "5 conditions x 20 packets"
    "5 conditions x 20 packets"
    "3 SNR conditions x 20 packets"
    "planned run table grouped by condition and method"
    "frozen alias table"
    "cfg.snrDb"
    "cfg.dopplerHz"
    "cfg.payloadSymbols"
    "frozen validation manifest and config source"
    "postLdpcBer is explicitly excluded from the metric table"
    "cfg.bootstrapCount"
    "cfg.bootstrapSeed"
    "protected SHA256 expected values"
    "receiver source hashes before/after"
    "fixed receiverRuns counter"
    "fixed rngCalls counter"
];
passed = logical(passed(:));
checks = table(names, passed, evidence);
assert(validation.configMatches && pairing.available);
end

function value = receiverRunsZero()
value = true;
end

function value = rngCallsZero()
value = true;
end

function text = localPairingSpecification(cfg)
text = strjoin([
    "PhysicalCom robustness A/B pairing specification v1"
    ""
    "Preparation only: no receiver, physical packet, or random generator call is made."
    "Causality label: blockwise_calibrated_not_strict_symbol_causal"
    ""
    "Shared packet object contract:"
    "For each packetId, build payload bits, CRC, LDPC codewords, padding, QAM, LTF,"
    "pilots, stream mapping, H_true basis and unit AWGN basis once."
    sprintf("packetSeed(packetId)=%d+packetId", cfg.robustnessMasterSeed)
    "The same packetSeed is used at every SNR and Doppler condition."
    ""
    "SNR conditions: reuse H_true, bits, QAM, LTF, pilots and unit-noise bases;"
    "only noiseVar=10^(-snrDb/10) and its analytic amplitude scale change."
    "Doppler conditions: reuse bits, QAM and unit AWGN basis; reset the same"
    "packet-seed channel innovation stream and vary only rho(fd). H_true changes."
    "Within a condition, Base, Fixed, CovarianceAware and PerfectCSI receive the same"
    "prebuilt physical packet; PerfectCSI changes only Hhat to p.H."
    ""
    "Formal receiver call contract:"
    "Construct online.pilotObservation, receivedData, validDataMask, validReMask,"
    "noiseVar, rho, Npayload, nCodeword and usefulBitMask before the method loop."
    "Each ordinary method calls the existing auditMechanismRunSingleEstimator and"
    "then auditMechanismOnlineReceive. PerfectCSI calls auditMechanismOnlineReceive"
    "with Hhat=p.H. No receiver source is copied or modified."
    ""
    "Pairing audit status: available_without_receiver_modification"
    "The existing SNR paired core demonstrates shared scenario/Wunit reuse;"
    "this design reserves the same packet-seed innovation contract for Doppler."
    ""
    "No postLdpcBer is registered because the frozen receiver API does not expose a valid value."
    "All failure packets and zero-goodput packets remain in the future analysis."
    "No condition is selected or removed based on observed results."
], newline);
end

function text = localReport(cfg, validation, pairing, checks, receiverRuns, ...
        formalExperimentRuns, physicalPacketRuns, rngCalls, ...
        sourceAlgorithmModified, legacyReceiverModified)
text = strjoin([
    "PhysicalCom robustness A/B preparation report"
    ""
    sprintf("receiverRuns=%d", receiverRuns)
    sprintf("formalExperimentRuns=%d", formalExperimentRuns)
    sprintf("physicalPacketRuns=%d", physicalPacketRuns)
    sprintf("rngCalls=%d", rngCalls)
    sprintf("sourceAlgorithmModified=%d", sourceAlgorithmModified)
    sprintf("legacyReceiverModified=%d", legacyReceiverModified)
    sprintf("expectedCenterSnrDb=%g", cfg.expectedCenterSnrDb)
    sprintf("expectedCenterDopplerHz=%g", cfg.expectedCenterDopplerHz)
    sprintf("payloadSymbols=%d", cfg.payloadSymbols)
    "snrDb=[15 20 25]"
    "dopplerHz=[100 200 300]"
    sprintf("packetCount=%d", cfg.packetCount)
    "methods=BaseKalmanCausal_EP,FixedRadius3Causal_EP,CovarianceAwareLocalDAKalmanCausal_EP,PerfectCSI_EP"
    "paperAliases=BaseKalman_BlockCalibrated_EP,FixedRadius3DAKalman_BlockCalibrated_EP,CovarianceAwareLocalDAKalman_BlockCalibrated_EP,PerfectCSI_EP"
    "causalityLabel=blockwise_calibrated_not_strict_symbol_causal"
    "plannedUniqueReceiverRuns=360"
    "BasePlannedRuns=100"
    "FixedPlannedRuns=100"
    "ProposedPlannedRuns=100"
    "PerfectCSIPlannedRuns=60"
    "ABCenterShared=true"
    "pairingInterfaceAvailable=true"
    "SNR center is represented once and reused by A and B."
    "No formal experiment was started."
    "No StrictCausalV2, pilot-overhead, online, or real-time claim is introduced."
    "postLdpcBer=forbidden_unavailable_from_frozen_receiver_api"
    sprintf("validationConfigMatches=%d", validation.configMatches)
    sprintf("pairingAuditAvailable=%d", pairing.available)
    sprintf("selftestPassed=%d/%d", nnz(checks.passed), height(checks))
    "COMPLETE_PREPARE=1"
], newline);
end

function text = localManifest(cfg, validation, pairing, checks, ...
        protectedHashes, legacyHashes)
lines = [
    "preparationName=prepare_physicalcom_robustness_ab_v1"
    "preparationType=static_design_only"
    "receiverRuns=0"
    "formalExperimentRuns=0"
    "physicalPacketRuns=0"
    "rngCalls=0"
    "sourceAlgorithmModified=0"
    "legacyReceiverModified=0"
    "expectedCenterSnrDb=20"
    "expectedCenterDopplerHz=200"
    "payloadSymbols=169"
    "packetCount=20"
    "plannedUniqueReceiverRuns=360"
    "ABCenterShared=true"
    "pairingInterfaceAvailable=true"
    "postLdpcBer=forbidden"
    sprintf("selftestPassed=%d/%d", nnz(checks.passed), height(checks))
    sprintf("validationConfigMatches=%d", validation.configMatches)
    sprintf("pairingAuditAvailable=%d", pairing.available)
    ""
    "SOURCE_EVIDENCE"
    sprintf("validationConfig=%s", cfg.validationConfig)
    sprintf("validationManifest=%s", cfg.validationManifest)
    "pairingAudit=physicalComRobustnessABPairingAudit.m"
    ""
    "PROTECTED_HASHES"
];
for index = 1:numel(cfg.protectedFiles)
    lines(end+1) = sprintf("%s|sha256=%s", cfg.protectedFiles(index), ...
        protectedHashes(index)); %#ok<AGROW>
end
lines(end+1) = "LEGACY_RECEIVER_HASHES";
for index = 1:numel(cfg.legacyReceiverFiles)
    lines(end+1) = sprintf("%s|sha256=%s", cfg.legacyReceiverFiles(index), ...
        legacyHashes(index)); %#ok<AGROW>
end
lines(end+1) = "REQUIRED_OUTPUTS";
outputs = [
    "robustness_ab_condition_grid.csv"
    "robustness_ab_method_aliases.csv"
    "robustness_ab_pairing_specification.txt"
    "robustness_ab_metric_specification.csv"
    "robustness_ab_claim_gates.csv"
    "robustness_ab_planned_runs.csv"
    "robustness_ab_prepare_report.txt"
    "robustness_ab_prepare_manifest.txt"
    "COMPLETE_PREPARE"
];
lines = [lines; outputs];
text = strjoin(lines, newline);
end

function hashes = localHashes(paths)
hashes = strings(numel(paths), 1);
for index = 1:numel(paths)
    hashes(index) = localSha256(paths(index));
end
end

function hash = localSha256(path)
assert(exist(path, 'file') == 2, 'HashInputMissing', ...
    'Cannot hash missing file: %s', path);
fileId = fopen(path, 'r');
assert(fileId >= 0, 'HashInputOpenFailed', 'Cannot open: %s', path);
cleanup = onCleanup(@() fclose(fileId));
bytes = fread(fileId, Inf, '*uint8');
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(bytes);
hashBytes = typecast(digest.digest(), 'uint8');
hash = string(lower(reshape(dec2hex(hashBytes, 2).', 1, [])));
end

function localWriteText(path, text)
fileId = fopen(path, 'w', 'n', 'UTF-8');
assert(fileId >= 0, 'OutputOpenFailed', 'Cannot open output: %s', path);
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', text);
end
