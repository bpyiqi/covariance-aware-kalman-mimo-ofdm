function cfg = physicalComRobustnessABConfig(root)
%PHYSICALCOMROBUSTNESSABCONFIG Frozen design configuration for prep only.
if nargin < 1
    root = fileparts(mfilename('fullpath'));
end
cfg = struct();
cfg.root = string(root);
cfg.outputDirectory = fullfile(root, 'results_three_layer_validation', ...
    'physicalcom_robustness_ab_v1_prepare');
cfg.expectedCenterSnrDb = 20;
cfg.expectedCenterDopplerHz = 200;
cfg.payloadSymbols = 169;
cfg.packetCount = 20;
cfg.packetIds = (1:20).';
cfg.snrDb = [15 20 25];
cfg.dopplerHz = [100 200 300];
cfg.robustnessMasterSeed = 2026072801;
cfg.bootstrapSeed = 2026072802;
cfg.bootstrapCount = 10000;
cfg.confidenceLevel = 0.95;
cfg.modulation = "16QAM";
cfg.mimo = "2x2";
cfg.ldpc = "DVB-S2";
cfg.fixedRadius = 3;
cfg.llrThreshold = 2.5;
cfg.minEffectiveSamples = 2;
cfg.gramRcondThreshold = 1e-3;
cfg.rda = "RLS";
cfg.joseph = true;
cfg.paddingExcluded = true;
cfg.noSameSymbolFeedback = true;
cfg.maxDaUpdatesPerTarget = 1;
cfg.causalityLabel = "blockwise_calibrated_not_strict_symbol_causal";
cfg.historicalMethods = [
    "BaseKalmanCausal_EP"
    "FixedRadius3Causal_EP"
    "CovarianceAwareLocalDAKalmanCausal_EP"
    "PerfectCSI_EP"
];
cfg.paperMethods = [
    "BaseKalman_BlockCalibrated_EP"
    "FixedRadius3DAKalman_BlockCalibrated_EP"
    "CovarianceAwareLocalDAKalman_BlockCalibrated_EP"
    "PerfectCSI_EP"
];
cfg.protectedFiles = [
    string(fullfile(root, 'Compare_LongPayload_VideoLink_Kalman.m'))
    string(fullfile(root, 'Exp_ProblemExistence_CSI_Aging.m'))
    string(fullfile(root, 'Audit_ProblemExistence_CSI_Aging.m'))
];
cfg.validationConfig = string(fullfile(root, ...
    'audit_three_layer_helpers', 'quality_aware_proposed', ...
    'auditCovarianceAwareFinalValidation50Config.m'));
cfg.validationDefaultConfig = string(fullfile(root, ...
    'audit_three_layer_helpers', 'quality_aware_proposed', ...
    'auditQualityAwareDefaultConfig.m'));
cfg.validationManifest = string(fullfile(root, ...
    'results_three_layer_validation', ...
    'covariance_aware_final_validation50_seed20260721', ...
    'validation50_frozen_method_manifest.txt'));
cfg.legacyReceiverFiles = [
    string(fullfile(root, 'audit_three_layer_helpers', ...
    'quality_aware_proposed', 'auditMechanismRunSingleEstimator.m'))
    string(fullfile(root, 'audit_three_layer_helpers', ...
    'quality_aware_proposed', 'auditMechanismOnlineReceive.m'))
];
cfg.packetSeedFormula = "packetSeed(packetId)=robustnessMasterSeed+packetId";
cfg.conditionSeedFormula = "conditionSeed=packetSeed; no condition-dependent payload seed";
cfg.noPostLdpcBer = true;
end
