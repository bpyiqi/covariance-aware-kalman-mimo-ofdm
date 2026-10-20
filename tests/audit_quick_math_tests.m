% Independent quick mathematical checks for the c1 paper audit.
% This file is audit-only and does not modify source code or historical results.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));
addpath(fullfile(root, 'audit_three_layer_helpers'));
addpath(fullfile(root, 'audit_three_layer_helpers', 'quality_aware_proposed'));

rng(20261008, 'twister');
cfg = auditCovarianceAwareFinalValidation50Config(root);

H0 = [1.0 + 0.2i, 0.3 - 0.1i; -0.2 + 0.4i, 0.8 - 0.3i];
X = [1, 0, 1, 0; 0, 1, 0, 1];
Y0 = H0 * X;
G = X * X';
theoryC = cfg.noiseVar * kron(G.' \ eye(2), eye(2));

% A/E: empirical local-LS covariance under independent proper complex AWGN.
nMC = 3000;
err = zeros(4, nMC);
estimatedR = zeros(8, 8, nMC);
for m = 1:nMC
    W = sqrt(cfg.noiseVar / 2) * (randn(2, 4) + 1i * randn(2, 4));
    Y = Y0 + W;
    Hls = (Y * X') / G;
    err(:, m) = Hls(:) - H0(:);
    a = auditEstimateLocalLsObservationCovariance(X, Y, Hls, cfg.noiseVar, cfg);
    estimatedR(:, :, m) = a.Rls;
end
empiricalC = (err * err') / nMC;
empiricalR = zeros(8, 8);
for m = 1:nMC
    empiricalR = empiricalR + estimatedR(:, :, m);
end
empiricalR = empiricalR / nMC;
theoryR = 0.5 * [real(theoryC), -imag(theoryC); imag(theoryC), real(theoryC)];
empiricalRealC = 0.5 * [real(empiricalC), -imag(empiricalC); imag(empiricalC), real(empiricalC)];

% B: two candidate matrices with different conditioning.
Xbad = [1, 1, 1, 1; 0, 0.04, 0.08, 0.12];
Gbad = Xbad * Xbad';
errBad = zeros(4, nMC);
for m = 1:nMC
    W = sqrt(cfg.noiseVar / 2) * (randn(2, 4) + 1i * randn(2, 4));
    Hls = ((H0 * Xbad + W) * Xbad') / Gbad;
    errBad(:, m) = Hls(:) - H0(:);
end

% C: controlled hard-decision errors should inflate residual-derived variance.
W = sqrt(cfg.noiseVar / 2) * (randn(2, 4) + 1i * randn(2, 4));
Yclean = H0 * X + W;
Hclean = (Yclean * X') / G;
Xwrong = X(:, [2, 3, 4, 1]);
Hwrong = (Yclean * Xwrong') / (Xwrong * Xwrong');
cleanAudit = auditEstimateLocalLsObservationCovariance(X, Yclean, Hclean, cfg.noiseVar, cfg);
wrongAudit = auditEstimateLocalLsObservationCovariance(X, Yclean, Hwrong, cfg.noiseVar, cfg);

% D: controlled local frequency variation creates a non-zero LS bias.
Hleft = H0 + 0.08 * [1, -1; 0.5, -0.5];
Hright = H0 - 0.02 * [1, -1; 0.5, -0.5];
Yvary = [Hleft * X(:, 1:2), Hright * X(:, 3:4)];
Hvary = (Yvary * X') / G;
varyBias = norm(Hvary - H0, 'fro');

% F: innovation/NIS consistency is checked without imposing a claim about
% the exact chi-square law after data decisions.
h = zeros(8, 1);
P = zeros(8);
nis = zeros(nMC, 1);
for m = 1:nMC
    z = h + sqrt(cfg.noiseVar / 2) * randn(8, 1);
    a = auditComputeInnovationConsistency(h, P, z, cfg.noiseVar * eye(8), cfg);
    nis(m) = a.nis;
end

rhoDirect = abs(besselj(0, 2 * pi * cfg.fdHz * cfg.Tsym));
Hchan = ofdm.generateItuaGmChannel(cfg.NFFT, 3, cfg.rho, cfg.Fs);
ltf = ofdm.makeNoisyLtfEstimate(squeeze(Hchan(:, 1, :, :)), cfg.active, cfg.noiseVar);
Hround = auditFeatureVectorToChannelMatrix(auditChannelMatrixToFeatureVector(H0));

rows = {
    'rho_direct_error', abs(cfg.rho - min(max(rhoDirect, 0), 0.9999999));
    'channel_size_ok', isequal(size(Hchan), [64 3 2 2]);
    'ltf_full_2x2_active_nonzero', nnz(abs(ltf(cfg.active, :, :)) > 0) == numel(cfg.active) * 4;
    'state_roundtrip_error', max(abs(H0(:) - Hround(:)));
    'ls_theory_complex_cov_rel_error', norm(empiricalC - theoryC, 'fro') / norm(theoryC, 'fro');
    'ls_theory_real_cov_rel_error', norm(empiricalRealC - theoryR, 'fro') / norm(theoryR, 'fro');
    'estimated_R_vs_theory_real_rel_error', norm(empiricalR - theoryR, 'fro') / norm(theoryR, 'fro');
    'bad_to_good_trace_ratio', trace((errBad * errBad') / nMC) / trace(empiricalC);
    'wrong_decision_sigma2_ratio', wrongAudit.sigma2Hat / cleanAudit.sigma2Hat;
    'frequency_variation_bias_fro', varyBias;
    'nis_mean', mean(nis);
    'nis_median', median(nis);
    'nis_p99', auditDeterministicPercentile(nis, 0.99);
    'rho', cfg.rho;
    'noise_var', cfg.noiseVar;
    'nMC', nMC;
    'seed', 20261008;
    };

out = fullfile(root, 'audit_output', 'quick_math_tests.csv');
fid = fopen(out, 'w', 'n', 'UTF-8');
assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'test,value\n');
for i = 1:size(rows, 1)
    value = rows{i, 2};
    if islogical(value)
        value = double(value);
    end
    fprintf(fid, '%s,%.16g\n', rows{i, 1}, double(value));
end
fprintf('Independent quick mathematical audit complete.\n');
disp(cell2table(rows, 'VariableNames', {'test', 'value'}));
