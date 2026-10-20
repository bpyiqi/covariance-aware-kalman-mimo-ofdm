function packed=auditEpVariancePostprocessV2PackLlr(chunk,frozenRecord)
%AUDITEPVARIANCEPOSTPROCESSV2PACKLLR Frozen receiver's original LLR packing and padding mask.
truthUseful=logical(chunk.codedBits(:));frozenLlrUseful=double(frozenRecord.rawUsefulLlr(:));assert(numel(truthUseful)==3*64800&&numel(frozenLlrUseful)==3*64800);
truthByRe=reshape(truthUseful,4,[]).';llrByRe=reshape(frozenLlrUseful,4,[]).';assert(isequal(size(truthByRe),[48600 4])&&isequal(size(llrByRe),[48600 4]));
mask4=reshape(chunk.usefulBitMask,4,[]);assert(all(all(mask4==mask4(1,:),1)));usefulReMask=mask4(1,:).';
packed=struct('truthUseful',truthUseful,'frozenLlrUseful',frozenLlrUseful,'truthByRe',truthByRe,'llrByRe',llrByRe, ...
    'hardBits',llrByRe<0,'bitErrorByRe',(llrByRe<0)~=truthByRe,'usefulReMask',logical(usefulReMask));
end
