function output = auditAggregateMechanismRejections(input,schema)
%AUDITAGGREGATEMECHANISMREJECTIONS One row per payload-method-radius key.
radiusKey=input.candidateRadius;radiusKey(isnan(radiusKey))=-1;
keys=unique(table(input.payloadSymbols,input.method,radiusKey,'VariableNames',{'payloadSymbols','method','radiusKey'}),'rows');
names=schema.rejection(4:end);cells=cell(height(keys),1);
for index=1:height(keys)
    selected=input.payloadSymbols==keys.payloadSymbols(index)&input.method==keys.method(index)&radiusKey==keys.radiusKey(index);
    part=input(selected,:);values=cellfun(@(name)localSumOrNan(part.(name)),names,'UniformOutput',false);
    radius=keys.radiusKey(index);if radius==-1,radius=NaN;end
    cells{index}=cell2table([{keys.payloadSymbols(index),keys.method(index),radius},values],'VariableNames',schema.rejection);
end
output=vertcat(cells{:});output=sortrows(output,{'payloadSymbols','method','candidateRadius'},{'ascend','ascend','ascend'});
assert(height(output)==height(keys),'Rejection aggregation produced duplicate keys.');
end

function value=localSumOrNan(data)
if all(isnan(data)),value=NaN;else,value=sum(data,'omitnan');end
end
