function output=auditRawClipTransform(raw,clipLevel,kind)
%AUDITRAWCLIPTRANSFORM Symmetric decoder-input-only confidence transform.
arguments,raw,clipLevel (1,1) double {mustBePositive},kind (1,1) string="hard",end
if isinf(clipLevel),output=raw;return;end
switch kind
    case "hard",output=sign(raw).*min(abs(raw),clipLevel);
    case "tanh",output=clipLevel.*tanh(raw./clipLevel);
    otherwise,error('Unknown raw clipping transform: %s',kind);
end
end
