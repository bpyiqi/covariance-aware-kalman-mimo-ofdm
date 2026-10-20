function startup_C1()
% Explicit startup for the C1 data/code release.
root = fileparts(mfilename('fullpath'));
addpath(root);
addpath(fullfile(root,'src'));
addpath(fullfile(root,'audit_three_layer_helpers'));
addpath(fullfile(root,'audit_three_layer_helpers','quality_aware_proposed'));
addpath(fullfile(root,'audit_three_layer_helpers','ojcd_baseline'));
addpath(fullfile(root,'audit_three_layer_helpers','uncertainty_consistent'));
addpath(fullfile(root,'experiments'));
addpath(fullfile(root,'code','plotting'));
addpath(fullfile(root,'tests'));
disp(['C1 release root: ', root]);
end
