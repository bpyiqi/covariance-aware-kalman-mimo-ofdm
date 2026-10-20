function outputs=auditWriteValidation50PublicationTables(out)
%AUDITWRITEVALIDATION50PUBLICATIONTABLES Write Markdown and LaTeX from derived CSVs.
C=readtable(fullfile(out,'validation50_core_results_table.csv'),'TextType','string');
P=readtable(fullfile(out,'validation50_core_comparisons.csv'),'TextType','string');
W=readtable(fullfile(out,'validation50_codeword_results.csv'),'TextType','string');
md=fullfile(out,'validation50_publication_tables.md');tex=fullfile(out,'validation50_publication_tables.tex');
f=fopen(md,'w','n','UTF-8');assert(f>=0);cleanup=onCleanup(@()fclose(f));
fprintf(f,'# Frozen validation50 publication tables\n\nOperating point: SNR 20 dB, fd 200 Hz, 50 paired physical packets per payload length.\n\n');
fprintf(f,'## Core results\n\n| Payload | Method | NMSE | Pre-LDPC BER | Soft EVM | Codeword pass | Goodput (Mbps) | Runtime (s) |\n|---:|---|---:|---:|---:|---:|---:|---:|\n');
for i=1:height(C),fprintf(f,'| %d | %s | %.6g | %.6g | %.6g | %.3f | %.3f | %.3f |\n',C.payloadSymbols(i),localLabel(C.method(i)),C.meanAvgCsiNmse(i),C.meanPreLdpcBer(i),C.meanSoftEvm(i),C.codewordPassRate(i),C.meanGoodputMbps(i),C.meanProcessingTimeSec(i));end
fprintf(f,'\n## CovarianceAware paired comparisons\n\n| Payload | Reference | Metric | Relative improvement (%%) | Wins/Losses/Ties | Paired difference 95%% CI |\n|---:|---|---|---:|---:|---:|\n');
keep=ismember(P.metric,["avgCsiNmse","preLdpcBer","softEvm","goodputMbps"]);
for i=find(keep).',fprintf(f,'| %d | %s | %s | %.3f | %d/%d/%d | [%.6g, %.6g] |\n',P.payloadSymbols(i),localLabel(P.referenceMethod(i)),P.metric(i),P.relativeImprovementPercent(i),P.proposedWins(i),P.referenceWins(i),P.ties(i),P.ciLower(i),P.ciUpper(i));end
fprintf(f,'\n## Codeword denominator audit\n\nThe 169-symbol condition has one codeword per payload; 507 symbols has three. Per-codeword success and whole-payload all-codewords success are distinct.\n\n');
fprintf(f,'| Payload | Method | Decoded codewords | Codeword pass | Whole-payload pass |\n|---:|---|---:|---:|---:|\n');
for i=1:height(W),fprintf(f,'| %d | %s | %d | %.3f | %.3f |\n',W.payloadSymbols(i),localLabel(W.method(i)),W.decodedCodewordCount(i),W.codewordPassRate(i),W.wholePayloadAllCodewordsPassRate(i));end
clear cleanup;f=fopen(tex,'w','n','UTF-8');assert(f>=0);cleanup=onCleanup(@()fclose(f));
fprintf(f,'%% Frozen validation50 publication table; SNR=20 dB, fd=200 Hz.\n\\begin{tabular}{r l r r r r r}\n\\hline\nPayload & Method & NMSE & BER & EVM & CW pass & Goodput \\\\\n\\hline\n');
for i=1:height(C),fprintf(f,'%d & %s & %.4g & %.4g & %.4g & %.3f & %.3f \\\\\n',C.payloadSymbols(i),localTex(localLabel(C.method(i))),C.meanAvgCsiNmse(i),C.meanPreLdpcBer(i),C.meanSoftEvm(i),C.codewordPassRate(i),C.meanGoodputMbps(i));end
fprintf(f,'\\hline\n\\end{tabular}\n\n%% CW pass is per-codeword; whole-payload pass is reported separately in validation50_codeword_results.csv.\n');
outputs=struct('markdown',md,'latex',tex);fprintf('validation50 publication tables written: %s, %s\n',md,tex);
end
function label=localLabel(method)
label=replace(method,["BaseKalmanCausal_EP","FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP","OJCD_LMMSE_EP_Adapted","OracleDataAidedCausal_EP","PerfectCSI_EP"],["Base","FixedR3","CovarianceAware","OJCD-LMMSE","Oracle DA","Perfect CSI"]);
end
function value=localTex(value),value=replace(value,"_","\_");end

