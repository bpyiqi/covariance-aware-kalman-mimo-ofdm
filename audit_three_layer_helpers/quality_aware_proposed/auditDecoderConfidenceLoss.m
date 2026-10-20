function [loss,count]=auditDecoderConfidenceLoss(beta,margins)
%AUDITDECODERCONFIDENCELOSS Mean bitwise logistic NLL for positive beta.
assert(isscalar(beta)&&isfinite(beta)&&beta>0);margins=double(margins(:));assert(all(isfinite(margins)));
count=numel(margins);assert(count>0);loss=mean(auditStableSoftplus(-beta*margins));
end

