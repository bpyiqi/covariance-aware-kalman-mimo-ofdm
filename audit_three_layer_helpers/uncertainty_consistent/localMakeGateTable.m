function T = localMakeGateTable(method,names,checks)
%LOCALMAKEGATETABLE Canonical gate-table constructor for bypass audits.
method = string(method);
names = string(names(:));
checks = logical(checks(:));
assert(isscalar(method),'Method must be scalar.');
assert(numel(names) == numel(checks),'GateCheckCountMismatch');
methodColumn = repmat(method,numel(names),1);
T = table(methodColumn,names,checks, ...
    'VariableNames',{'method','gate','passed'});
end
