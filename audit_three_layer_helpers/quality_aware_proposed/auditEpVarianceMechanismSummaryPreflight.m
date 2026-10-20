function input=auditEpVarianceMechanismSummaryPreflight(cfg)
%AUDITEPVARIANCEMECHANISMSUMMARYPREFLIGHT Read schemas only from frozen results.
assert(isfile(fullfile(cfg.v2Directory,'COMPLETE')),'V2 COMPLETE is missing.');
names=["ep_variance_postprocess_v2_hash_audit.csv","ep_variance_postprocess_v2_method_snr.csv","ep_variance_postprocess_v2_error_status.csv","ep_variance_postprocess_v2_floor_rollback.csv","ep_variance_postprocess_v2_ojcd_layers.csv"];
for i=1:numel(names),assert(isfile(fullfile(cfg.v2Directory,names(i))),'V2 input is missing: %s.',names(i));end
input=struct();
input.hash=readtable(fullfile(cfg.v2Directory,names(1)));input.method=readtable(fullfile(cfg.v2Directory,names(2)));input.tail=readtable(fullfile(cfg.v2Directory,names(3)));input.floor=readtable(fullfile(cfg.v2Directory,names(4)));input.ojcd=readtable(fullfile(cfg.v2Directory,names(5)));
assert(height(input.hash)==45&&all(input.hash.correctedPreBerMatches),'V2 BER mapping audit is incomplete.');
assert(height(input.method)==54&&height(input.tail)==270&&height(input.floor)==54);
end
