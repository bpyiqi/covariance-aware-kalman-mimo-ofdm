function value = envOverride(name, default_value)
%ENVOVERRIDE Numeric scalar environment override helper.

raw = getenv(name);
if isempty(raw)
    value = default_value;
    return;
end
parsed = str2double(raw);
if isnan(parsed)
    value = default_value;
else
    value = parsed;
end
end

