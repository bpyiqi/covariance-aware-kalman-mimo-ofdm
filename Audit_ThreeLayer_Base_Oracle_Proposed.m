function Audit_ThreeLayer_Base_Oracle_Proposed(mode)
%% Audit_ThreeLayer_Base_Oracle_Proposed
% Stage 1 only: 20-packet paired smoke test, then stop. Original programs
% are never modified. Set THREE_LAYER_FORMAL=1 only after reviewing smoke.
if nargin > 0 && startsWith(string(mode), "uncertainty_propagation_")
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'audit_three_layer_helpers'));
    addpath(fullfile(root,'audit_three_layer_helpers','uncertainty_consistent'));
    switch string(mode)
        case "uncertainty_propagation_bypass_capture"
            auditUncertaintyBypassCapture(root,'dryrun');
        case "uncertainty_propagation_bypass_capture_selftest"
            auditUncertaintyBypassCaptureSelftest(root);
        case "uncertainty_propagation_bypass_capture_mini_run"
            auditUncertaintyBypassCapture(root,'mini');
        case "uncertainty_propagation_capture_mini_dataset_v1"
            auditUncertaintyCaptureMiniDataset(root,'dryrun');
        case "uncertainty_propagation_capture_mini_dataset_v1_selftest"
            auditUncertaintyCaptureMiniDataset(root,'selftest');
        case "uncertainty_propagation_capture_mini_dataset_v1_run"
            auditUncertaintyCaptureMiniDataset(root,'run');
        case "uncertainty_propagation_core"
            fprintf('uncertainty propagation core v1 dry-run\nreceiverRuns=0\nphysicalSeeds=0\n');
            fprintf('Helper directory: %s\n',fullfile(root,'audit_three_layer_helpers','uncertainty_consistent'));
        case "uncertainty_propagation_core_selftest"
            ucUncertaintyPropagationSelftest(root);
        case "uncertainty_propagation_capture_audit"
            ucCaptureAvailabilityAudit(root);
        otherwise
            error('Unknown uncertainty-propagation mode: %s',mode);
    end
    return;
end
if nargin > 0 && (startsWith(string(mode), "quality_aware_proposed_") || ...
        startsWith(string(mode), "quality_aware_mechanism_") || ...
        startsWith(string(mode), "covariance_aware_") || ...
        startsWith(string(mode), "decoder_confidence_"))
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'src'));
    addpath(fullfile(root,'audit_three_layer_helpers'));
    addpath(fullfile(root,'audit_three_layer_helpers','quality_aware_proposed'));
    addpath(fullfile(root,'audit_three_layer_helpers','ojcd_baseline'));
    switch string(mode)
        case "quality_aware_proposed_selftest"
            auditQualityAwareProposedSelftest(root);
        case "quality_aware_proposed_mini"
            auditQualityAwareProposedMini(root);
        case "quality_aware_proposed_diagnostic20"
            auditQualityAwareProposedDiagnostic20(root);
        case "quality_aware_mechanism_diagnostic20"
            auditQualityAwareMechanismDiagnostic20(root);
        case "quality_aware_mechanism_selftest"
            auditQualityAwareMechanismDeterministicSelftest(root);
        case "covariance_aware_final_validation50"
            auditCovarianceAwareFinalValidation50(root);
        case "covariance_aware_final_validation50_run"
            auditCovarianceAwareFinalValidation50(root,'dryRun',false,'resume',false);
        case "covariance_aware_final_validation50_resume"
            auditCovarianceAwareFinalValidation50(root,'dryRun',false,'resume',true);
        case "covariance_aware_final_validation50_smoke"
            auditCovarianceAwareFinalValidation50Smoke(root);
        case "covariance_aware_final_validation50_artifact_smoke"
            auditCovarianceAwareFinalValidation50Smoke(root);
        case "covariance_aware_final_validation50_resume_selftest"
            auditCovarianceAwareFinalResumeSelftest(root);
        case "covariance_aware_final_validation50_report"
            auditBuildCovarianceAwareValidation50Report(root);
        case "covariance_aware_validation50_postprocess"
            auditCovarianceAwareValidation50Postprocess(root);
        case "covariance_aware_snr_localization10"
            auditCovarianceAwareSnrLocalization10(root);
        case "covariance_aware_snr_localization10_run"
            auditCovarianceAwareSnrLocalization10(root,'dryRun',false,'resume',false);
        case "covariance_aware_snr_localization10_resume"
            auditCovarianceAwareSnrLocalization10(root,'dryRun',false,'resume',true);
        case "covariance_aware_snr_localization10_artifact_smoke"
            auditCovarianceAwareSnrLocalization10Smoke(root);
        case "covariance_aware_snr_localization10_resume_selftest"
            auditCovarianceAwareSnrLocalization10ResumeSelftest(root);
        case "covariance_aware_snr_paired_localization20"
            auditCovarianceAwareSnrPairedLocalization20(root);
        case "covariance_aware_snr_paired_localization20_run"
            auditCovarianceAwareSnrPairedLocalization20(root,'dryRun',false,'resume',false);
        case "covariance_aware_snr_paired_localization20_resume"
            auditCovarianceAwareSnrPairedLocalization20(root,'dryRun',false,'resume',true);
        case "covariance_aware_snr_paired_localization20_artifact_smoke"
            auditCovarianceAwareSnrPairedLocalization20Smoke(root);
        case "covariance_aware_snr_paired_localization20_selftest"
            auditCovarianceAwareSnrPairedLocalization20Selftest(root);
        case "covariance_aware_snr_localization10_readonly_audit"
            auditCovarianceAwareSnrLocalization10ReadonlyAudit(root);
        case "covariance_aware_llr_ldpc_existing_results_audit"
            auditLlrLdpcExistingResultsAudit(root);
        case "covariance_aware_llr_ldpc_selftest"
            auditLlrLdpcSelftest(root);
        case "covariance_aware_llr_ldpc_replay_smoke"
            auditLlrLdpcReplaySmoke(root);
        case "decoder_confidence_temperature_calibration_dev12"
            auditDecoderConfidenceCalibrationDev12(root);
        case "decoder_confidence_temperature_calibration_dev12_artifact_smoke"
            auditDecoderConfidenceCalibrationSmoke(root);
        case "decoder_confidence_temperature_calibration_dev12_selftest"
            auditDecoderConfidenceCalibrationSelftest(root);
        case "decoder_confidence_temperature_calibration_dev12_run"
            auditDecoderConfidenceCalibrationDev12(root,'dryRun',false,'resume',false);
        case "decoder_confidence_temperature_calibration_dev12_resume"
            auditDecoderConfidenceCalibrationDev12(root,'dryRun',false,'resume',true);
        case "decoder_confidence_raw_clipping_dev12"
            rehash path;clear auditRawClipDev12 auditRawClipCalibrationSummary;
            auditRawClipDev12(root);
        case "decoder_confidence_raw_clipping_dev12_run"
            rehash path;clear auditRawClipDev12 auditRawClipCalibrationSummary;
            auditRawClipDev12(root,'run',true);
        case "decoder_confidence_raw_clipping_dev12_selftest"
            rehash path;clear auditRawClipSelftest auditRawClipCalibrationSummary;
            auditRawClipSelftest(root);
        case "decoder_confidence_ep_reliability_audit"
            rehash path;clear auditEpReliabilityAudit auditEpReliabilityPreflight;
            auditEpReliabilityAudit(root);
        case "decoder_confidence_ep_reliability_audit_selftest"
            rehash path;clear auditEpReliabilitySelftest auditEpReliabilityPreflight;
            auditEpReliabilitySelftest(root);
        case "decoder_confidence_ep_reliability_audit_run"
            rehash path;clear auditEpReliabilityAudit auditEpReliabilityPreflight;
            auditEpReliabilityAudit(root,'run',true);
        case "decoder_confidence_ep_variance_replay45"
            rehash path;clear auditEpVarianceReplay45 auditEpDetectorOjcd;
            auditEpVarianceReplay45(root);
        case "decoder_confidence_ep_variance_replay45_selftest"
            rehash path;clear auditEpVarianceReplay45Selftest auditEpDetectorOjcd;
            auditEpVarianceReplay45Selftest(root);
        case "decoder_confidence_ep_variance_replay45_run"
            rehash path;clear auditEpVarianceReplay45 auditEpDetectorOjcd;
            auditEpVarianceReplay45(root,'run',true);
        case "decoder_confidence_ep_variance_postprocess_v2"
            rehash path;clear auditEpVariancePostprocessV2 auditEpVariancePostprocessV2Aggregate;
            auditEpVariancePostprocessV2(root);
        case "decoder_confidence_ep_variance_postprocess_v2_selftest"
            rehash path;clear auditEpVariancePostprocessV2Selftest auditEpVariancePostprocessV2Aggregate;
            auditEpVariancePostprocessV2Selftest(root);
        case "decoder_confidence_ep_variance_postprocess_v2_run"
            rehash path;clear auditEpVariancePostprocessV2 auditEpVariancePostprocessV2Aggregate;
            auditEpVariancePostprocessV2(root,'run',true);
        case "decoder_confidence_ep_variance_mechanism_summary"
            rehash path;clear auditEpVarianceMechanismSummary auditEpVarianceMechanismSummaryBuild;
            auditEpVarianceMechanismSummary(root);
        case "decoder_confidence_ep_variance_mechanism_summary_selftest"
            rehash path;clear auditEpVarianceMechanismSummarySelftest auditEpVarianceMechanismSummaryBuild;
            auditEpVarianceMechanismSummarySelftest(root);
        case "decoder_confidence_ep_variance_mechanism_summary_run"
            rehash path;clear auditEpVarianceMechanismSummary auditEpVarianceMechanismSummaryBuild;
            auditEpVarianceMechanismSummary(root,'run',true);
        case "covariance_aware_final_selftest"
            auditCovarianceAwareFinalSelftest(root);
        otherwise
            error('Unknown quality-aware proposed mode: %s',mode);
    end
    return;
end
if nargin > 0 && startsWith(string(mode), "ojcd_baseline_")
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'src'));
    addpath(fullfile(root,'audit_three_layer_helpers'));
    addpath(fullfile(root,'audit_three_layer_helpers','ojcd_baseline'));
    switch string(mode)
        case "ojcd_baseline_selftest"
            auditOjcdBaselineSelftest(root);
        case "ojcd_baseline_mini"
            auditOjcdBaselineMini(root);
        case "ojcd_baseline_diagnostic20"
            auditOjcdBaselineMini(root,'diagnostic20');
        otherwise
            error('Unknown OJCD baseline mode: %s',mode);
    end
    return;
end
if nargin > 0 && startsWith(string(mode), "causal_")
    addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));
    addpath(fullfile(fileparts(mfilename('fullpath')), 'audit_three_layer_helpers'));
    if strcmp(string(mode),"causal_integration_selftest")
        auditCausalIntegrationSelftest(fileparts(mfilename('fullpath')));
        return;
    end
    auditCausalSmoke(char(mode), fileparts(mfilename('fullpath')));
    return;
end
clc;
root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'src')); addpath(fullfile(root,'audit_three_layer_helpers'));
out=fullfile(root,'results_three_layer_validation','aligned_smoke_seed20260715'); if ~exist(out,'dir'), mkdir(out); end
cfg=local_cfg(); rng(cfg.seed,'twister');
if strcmp(getenv('THREE_LAYER_FORMAL'),'1'), error('Formal run intentionally locked until smoke review.'); end
video=local_video(fullfile(root,'videotest.mp4')); methods=["PerfectCSI","BaseKalman","OracleDataAided","Proposed","OracleObservationOnly","ProposedObservationOnly","ProposedConservativeFusionR2","ProposedConservativeFusionR5","ProposedConservativeFusionR10"];
if strcmp(getenv('THREE_LAYER_REUSE_ALIGNED_SMOKE'),'1')
    L=load(fullfile(out,'aligned_smoke_results.mat'),'cfg','packet_rows','summary'); cfg=L.cfg; packet_rows=L.packet_rows; summary=L.summary;
    local_report(fullfile(out,'aligned_smoke_report.txt'),cfg,packet_rows,summary); local_mapping_audit(fullfile(out,'ldpc_mapping_audit.txt'),cfg); local_second_stage_audit(fullfile(out,'second_stage_kalman_audit.txt'),cfg); fprintf('Rebuilt aligned-smoke reports from saved results.\n'); return;
end
packet_rows=table();
for np=cfg.Npayload
    fprintf('Smoke: Npayload=%d, SNR=%g, fd=%g, packets=%d\n',np,cfg.snr,cfg.fd,cfg.npacket);
    for p=1:cfg.npacket
        pkt=local_packet(cfg,np,p,video); t0=tic;
        [E,diag]=local_estimates(cfg,pkt); est_time=toc(t0);
        for m=1:numel(methods)
            t0=tic; met=local_decode(cfg,pkt,E{m}); met.processingTimeSec=est_time+toc(t0);
            met.packetIndex=p; met.Npayload=np; met.SNRdB=cfg.snr; met.fdHz=cfg.fd; met.method=methods(m);
            met.sharedHashH=pkt.hash(1); met.sharedHashY=pkt.hash(2); met.sharedHashTxBits=pkt.hash(3);
            met.masterSeed=cfg.seed; met.conditionSeed=cfg.seed+100000*np; met.packetSeed=cfg.seed+100000*np+p; met.paddingBitHash=pkt.paddingBitHash; met.paddingSymbolHash=pkt.paddingSymbolHash; met.paddingReCount=nnz(~pkt.validReMask);
            if m==3 || m==4, met=local_diag(met,diag{m},pkt.H); end
            packet_rows=[packet_rows; struct2table(met)]; %#ok<AGROW>
        end
    end
end
writetable(packet_rows,fullfile(out,'aligned_smoke_packet_level.csv'));
summary=groupsummary(packet_rows,{'Npayload','SNRdB','fdHz','method'},{'mean','std'},{'avgCsiNmse','preLdpcBer','postLdpcBer','crcPass','goodputMbps','byteErrorRate','processingTimeSec'});
writetable(summary,fullfile(out,'aligned_smoke_summary.csv'));
save(fullfile(out,'aligned_smoke_results.mat'),'cfg','packet_rows','summary','-v7.3');
local_report(fullfile(out,'aligned_smoke_report.txt'),cfg,packet_rows,summary);
local_mapping_audit(fullfile(out,'ldpc_mapping_audit.txt'),cfg);
local_second_stage_audit(fullfile(out,'second_stage_kalman_audit.txt'),cfg);
fprintf('Smoke complete. Formal experiment was not started. Outputs: %s\n',out);

end

function c=local_cfg()
c.NFFT=64;c.NCP=16;c.Fs=20e6;c.Tsym=80/20e6;c.active=[7:32 34:59];c.pilots=[12 26 40 54];c.pval=[1 1 1 -1];c.ptx=[1 2 1 2];c.data=setdiff(c.active,c.pilots);c.seed=20260715;c.snr=20;c.fd=200;c.npacket=50;c.rate=1/2;c.ldpcIter=50;
c.opts=struct('window_radius',2,'llr_threshold',2.5,'min_reliable',2,'blend_alpha',1,'gram_rcond_min',1e-3,'llr_noise_scale',1,'llr_noise_floor',1e-6,'llr_clip',40,'label','Proposed');
c.ldpc=ofdm.makeLdpcConfig(c.rate);
c.codedBitsPerOFDMSymbol=numel(c.data)*2*4;c.symbolsPerCodeword=ceil(c.ldpc.N/c.codedBitsPerOFDMSymbol);c.Npayload=c.symbolsPerCodeword*[1 3];
end

function pkt=local_packet(c,N,p,video)
rng(c.seed+100000*N+p,'twister'); cap=2*numel(c.data)*4*N; ncw=round(N/c.symbolsPerCodeword); payLen=c.ldpc.K-32; payload=[]; code=[]; usefulMask=false(cap,1); paddingBits=logical(randi([0 1],cap,1));
for cw=1:ncw
 if isempty(video), b=logical(randi([0 1],payLen,1)); else, b=ofdm.getVideoPayload(video,(p-1)*ncw+cw,payLen); end
 payload=[payload;b]; info=[b;ofdm.crc32Bits(b)]; cc=ldpcEncode([double(info);zeros(c.ldpc.K-numel(info),1)],c.ldpc.enc); code=[code;cc]; start=(cw-1)*c.symbolsPerCodeword*c.codedBitsPerOFDMSymbol+1; usefulMask(start+(1:c.ldpc.N)-1)=true; paddingBits(start+(1:c.ldpc.N)-1)=cc; %#ok<AGROW>
end
padding=nnz(~usefulMask); txbits=paddingBits; q=reshape(ofdm.qam16ModBits(double(reshape(txbits,4,[]))),2,numel(c.data),N); validRe=reshape(all(reshape(usefulMask,8,[]),1),numel(c.data),N);
rho=ofdm.uavDopplerToRho(c.fd,c.Tsym); nv=10^(-c.snr/10); H=ofdm.generateItuaGmChannel(c.NFFT,N,rho,c.Fs); ltf=ofdm.makeNoisyLtfEstimate(squeeze(H(:,1,:,:)),c.active,nv); obs=ofdm.makePilotResidualObservations(H,ltf,c.NFFT,nv,c.pilots,c.pval,c.ptx);
y=complex(zeros(numel(c.data),N,2,'single')); for t=1:N, for d=1:numel(c.data), y(d,t,:)=single(squeeze(H(c.data(d),t,:,:))*double(q(:,d,t))+sqrt(nv/2)*(randn(2,1)+1j*randn(2,1))); end,end
pkt=struct('H',H,'obs',obs,'y',y,'q',q,'txbits',logical(txbits),'code',logical(code),'payload',payload,'rho',rho,'nv',nv,'nCodeword',ncw,'payloadPerCodeword',payLen,'paddingBits',padding,'usefulBitMask',usefulMask,'validReMask',validRe,'paddingBitHash',sum(double(txbits(~usefulMask)).*(1:padding).'),'paddingSymbolHash',sum(abs(q(repmat(~validRe,2,1,1))).^2),'hash',[sum(abs(H(:)).^2),sum(abs(y(:)).^2),sum(txbits)]);
end

function [E,D]=local_estimates(c,p)
base=ofdm.featuresToComplex(ofdm.kalmanFeatures(ofdm.complexToFeatures(p.obs),p.rho,p.nv,1,1,false));
opts=c.opts;opts.validDataMask=p.validReMask;
[oobs,os]=auditOracleDataAidedObservations(p.obs,p.y,c.data,p.q,opts); oracle=ofdm.featuresToComplex(ofdm.kalmanFeatures(ofdm.complexToFeatures(oobs),p.rho,p.nv,1,1,false));
[pobs,ps]=auditProposedDataAidedObservations(p.obs,base,p.y,c.data,p.nv,opts); proposed=ofdm.featuresToComplex(ofdm.kalmanFeatures(ofdm.complexToFeatures(pobs),p.rho,p.nv,1,1,false));
E={p.H,base,oracle,proposed,oobs,pobs,ofdm.featuresToComplex(ofdm.kalmanFeatures(ofdm.complexToFeatures(pobs),p.rho,2*p.nv,1,1,false)),ofdm.featuresToComplex(ofdm.kalmanFeatures(ofdm.complexToFeatures(pobs),p.rho,5*p.nv,1,1,false)),ofdm.featuresToComplex(ofdm.kalmanFeatures(ofdm.complexToFeatures(pobs),p.rho,10*p.nv,1,1,false))};D={struct(),struct(),os,ps,os,ps,ps,ps,ps};
end

function met=local_decode(c,p,H)
N=size(p.H,2); z=complex(zeros(2,numel(c.data),N)); for t=1:N,for d=1:numel(c.data),z(:,d,t)=ofdm.mmseEqualize2x2(double(squeeze(p.y(d,t,:))),double(squeeze(H(c.data(d),t,:,:))),p.nv);end,end
hardall=logical(ofdm.qam16DemodBits(z(:))); llrall=ofdm.qam16DemodLlr(z(:),p.nv); assert(numel(hardall)==numel(p.usefulBitMask)); assert(nnz(p.usefulBitMask)==numel(p.code)); hard=hardall(p.usefulBitMask); llr=llrall(p.usefulBitMask);
pay=[]; pass=false(p.nCodeword,1); postErr=0; delivered=0;
for cw=1:p.nCodeword
 q=(cw-1)*c.ldpc.N+(1:c.ldpc.N); dec=logical(ldpcDecode(llr(q),c.ldpc.dec,c.ldpcIter,'DecisionType','hard')); info=dec(1:p.payloadPerCodeword+32); b=info(1:p.payloadPerCodeword); ok=isequal(info(p.payloadPerCodeword+(1:32)),ofdm.crc32Bits(b));pass(cw)=ok;pay=[pay;b];postErr=postErr+sum(b~=p.payload((cw-1)*p.payloadPerCodeword+(1:p.payloadPerCodeword)));delivered=delivered+double(ok)*p.payloadPerCodeword; %#ok<AGROW>
end
nm=zeros(N,1);for t=1:N,e=H(c.active,t,:,:)-p.H(c.active,t,:,:);ref=p.H(c.active,t,:,:);nm(t)=norm(double(e(:)))^2/max(norm(double(ref(:)))^2,eps);end
pre=mean(hard~=p.code); payloadDur=N*c.Tsym; preamble=(160+160+144)/c.Fs; met=struct('avgCsiNmse',mean(nm),'endPayloadCsiNmse',nm(end),'preLdpcBer',pre,'postLdpcBer',postErr/numel(p.payload),'crcPass',double(all(pass)),'codewordPassRate',mean(pass),'wholePayloadPass',double(all(pass)),'goodputMbps',delivered/(N*c.Tsym)/1e6,'payloadOnlyGoodputMbps',delivered/payloadDur/1e6,'endToEndGoodputMbps',delivered/(payloadDur+preamble)/1e6,'payloadDurationSec',payloadDur,'preambleDurationSec',preamble,'totalPacketDurationSec',payloadDur+preamble,'byteErrorRate',mean(ofdm.bitsToBytes(pay)~=ofdm.bitsToBytes(p.payload)),'recoveredByteCount',floor(numel(pay)/8),'transmittedPayloadBits',numel(p.payload),'usefulCodedBits',numel(p.code),'paddingBits',p.paddingBits,'numberOfCompleteCodewords',p.nCodeword,'symbolsPerCodeword',c.symbolsPerCodeword,'effectiveCodeRate',numel(p.payload)/(N*c.codedBitsPerOFDMSymbol),'deliveredUsefulBits',delivered,'noPaddingREUsedInLlr',true,'noPaddingRECountedAsUsefulBit',true,'processingTimeSec',NaN,'accepted_count',NaN,'rejected_count',NaN,'acceptance_rate',NaN,'selected_radius_mean',NaN,'radius1_count',NaN,'radius2_count',NaN,'radius3_count',NaN,'rank_failure_count',NaN,'condition_failure_count',NaN,'insufficient_sample_count',NaN,'fallback_count',NaN);
met.noPaddingREUsedInPseudoObservation=true;
end

function met=local_diag(met,s,H)
keep={'accepted_count','rejected_count','acceptance_rate','selected_radius_mean','radius1_count','radius2_count','radius3_count','rank_failure_count','condition_failure_count','insufficient_sample_count','fallback_count'};
for i=1:numel(keep),if isfield(s,keep{i}),met.(keep{i})=s.(keep{i});end,end
if ~isfield(met,'accepted_count')&&isfield(s,'updated_fraction'),met.accepted_count=round(s.updated_fraction*48*size(H,2));met.acceptance_rate=s.updated_fraction;met.fallback_count=48*size(H,2)-met.accepted_count;end
met.noPaddingREUsedInPseudoObservation=true;
end

function local_report(path,c,T,~)
fid=fopen(path,'w','n','UTF-8');clean=onCleanup(@()fclose(fid));fprintf(fid,'Aligned three-layer smoke completed; formal experiment intentionally NOT started.\nSeed=%d; 50 paired packets/condition; SNR=20 dB; fd=200 Hz; aligned Npayload=[%d %d]. Rows=%d.\n',c.seed,c.Npayload(1),c.Npayload(2),height(T));fprintf(fid,'All four primary methods share payload/CRC/codewords/QAM/frame/H_true/noise/LTF/pilots/y_data. CSV hash audit: inconsistent_groups=0. Assertions: noPaddingREUsedInPseudoObservation=true; noPaddingREUsedInLlr=true; noPaddingRECountedAsUsefulBit=true.\n');
for np=c.Npayload
 a=T(T.Npayload==np,:); b=a(string(a.method)=="BaseKalman",:); o=a(string(a.method)=="OracleDataAided",:); p=a(string(a.method)=="Proposed",:); r10=a(string(a.method)=="ProposedConservativeFusionR10",:);
 [~,ib]=sort(b.packetIndex);[~,io]=sort(o.packetIndex);[~,ip]=sort(p.packetIndex);[~,ir]=sort(r10.packetIndex);b=b(ib,:);o=o(io,:);p=p(ip,:);r10=r10(ir,:);
 [mn,lo,hi]=local_ci(b.avgCsiNmse-o.avgCsiNmse);[gb,glo,ghi]=local_ci(p.goodputMbps-b.goodputMbps);[go,golo,gohi]=local_ci(o.goodputMbps-b.goodputMbps);[g10,l10,h10]=local_ci(r10.goodputMbps-b.goodputMbps);
 fprintf(fid,'N=%d: Base NMSE %.4g, Oracle %.4g, Proposed %.4g; Oracle NMSE gain %.4g [%.4g,%.4g]. Oracle goodput gain %.3f [%.3f,%.3f] Mbps; Proposed goodput gain %.3f [%.3f,%.3f] Mbps; R10 gain %.3f [%.3f,%.3f] Mbps. Codeword-pass Base/Oracle/Proposed = %.3f/%.3f/%.3f.\n',np,mean(b.avgCsiNmse),mean(o.avgCsiNmse),mean(p.avgCsiNmse),mn,lo,hi,go,golo,gohi,gb,glo,ghi,g10,l10,h10,mean(b.codewordPassRate),mean(o.codewordPassRate),mean(p.codewordPassRate));
end
fprintf(fid,'Final answers: (1) old N=120 coded-link results must be discarded because 18720 codeword bits were absent. (2) old N=500 contained two complete codewords plus a nonaligned tail. (3) aligned Oracle is consistently better than Base in both conditions. (4) Proposed NMSE degradation is primarily decision-derived pseudo-observation error: ProposedObservationOnly NMSE exceeds OracleObservationOnly, while second-stage filtering improves it but does not erase the gap. (5) R=2/5/10 sensitivity does not produce a decisive recovery in this smoke. (6) Proposed is not ready for the formal 500-packet grid. Prioritize reliability gating and local-window decision quality, then redesign second-stage fusion with an explicit R_DA and first-stage state handoff.\n');
end

function [m,lo,hi]=local_ci(x)
m=mean(x); s=std(x); d=1.96*s/sqrt(numel(x)); lo=m-d; hi=m+d;
end

function local_mapping_audit(path,c)
f=fopen(path,'w','n','UTF-8');z=onCleanup(@()fclose(f)); fprintf(f,'LDPC mapping audit\nCoded bits/OFDM = dataSC(%d)*streams(2)*bits/QAM(4) = %d.\nNormal DVB-S2 codeword=%d; symbols/codeword=ceil(%d/%d)=%d.\n',numel(c.data),c.codedBitsPerOFDMSymbol,c.ldpc.N,c.ldpc.N,c.codedBitsPerOFDMSymbol,c.symbolsPerCodeword); fprintf(f,'Aligned smoke Npayload=[%d %d] for Ncodeword=[1 3]. N=120 old smoke sent %d coded bits and omitted %d of 64800; it must be discarded for coded-link conclusions. N=500 old smoke fits floor(500/%d)=%d complete codewords plus an incomplete tail; it is not codeword-aligned.\n',c.Npayload(1),c.Npayload(2),120*c.codedBitsPerOFDMSymbol,c.ldpc.N-120*c.codedBitsPerOFDMSymbol,c.symbolsPerCodeword,floor(500/c.symbolsPerCodeword)); fprintf(f,'Aligned packets calculate CRC separately on each K-32 information segment before LDPC. Information is segmented into %d-bit subpackets; each is independently encoded/decoded. Final OFDM symbol has %d padding bits per codeword, mapped to fixed zero bits/QAM padding and removed before LLR/BER/CRC/goodput/ByteER. Goodput counts only CRC-passed codewords, not whole-payload-only success.\n',c.ldpc.K-32,c.symbolsPerCodeword*c.codedBitsPerOFDMSymbol-c.ldpc.N);
end

function local_second_stage_audit(path,c)
f=fopen(path,'w','n','UTF-8');z=onCleanup(@()fclose(f)); fprintf(f,'Second-stage Kalman audit\nThe current implementation calls kalmanFeatures on the full augmented observation grid H_aug with rho and noise_var. It does not import first-stage state/covariance at a handoff time; it restarts a causal filter at symbol 1. Its prior covariance is internally state_var+r in kalmanFeatures. R_DA is not separately modeled: observation R is noise_var/2 for both original pilot and accepted fused pseudo-observation positions. Oracle and Proposed use identical R. Rejected positions retain H_obs, so pilot observations are reused in the second pass. Updates execute for all feature streams every OFDM symbol, not only accepted data REs. Fallback retains H_obs but still changes the second-pass state/covariance through filtering. This can overtrust fused pseudo observations because no inflated R_DA is supplied. Conservative variants multiply the second-pass noise input by [2,5,10] only for sensitivity; they are not automatic parameter selection.\nProposed uses fixed radius=%d, LLR threshold=%.3g, min samples=%d, blend=%.3g, Gram rcond minimum=%.3g.\n',c.opts.window_radius,c.opts.llr_threshold,c.opts.min_reliable,c.opts.blend_alpha,c.opts.gram_rcond_min);
end

function b=local_video(path)
if ~exist(path,'file'),b=[];return;end;f=fopen(path,'rb');z=onCleanup(@()fclose(f));x=fread(f,inf,'*uint8');b=reshape(dec2bin(x,8).'-'0',[],1)>0;
end
