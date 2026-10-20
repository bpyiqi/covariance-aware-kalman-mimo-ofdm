function values = envVector(name, default_values)
%ENVVECTOR Numeric vector environment override helper.
%
% Supported formats:
%   '20 25 30'
%   '20,25,30'
%   '20;25;30'
%   '[20 25 30]'
%   '[20, 25, 30]'
%   '0.999998421 0.999993683 0.999974734 0.999898938'

raw = getenv(name);

if isempty(raw)
    values = default_values;
    return;
end

raw = strtrim(raw);

if isempty(raw)
    values = default_values;
    return;
end

% Remove brackets and convert common separators to spaces
raw = strrep(raw, '[', ' ');
raw = strrep(raw, ']', ' ');
raw = strrep(raw, '(', ' ');
raw = strrep(raw, ')', ' ');
raw = strrep(raw, ',', ' ');
raw = strrep(raw, ';', ' ');

% Parse numeric values separated by any whitespace
values = sscanf(raw, '%f').';

if isempty(values)
    warning('envVector:ParseFailed', ...
        'Could not parse environment variable %s="%s". Using default.', ...
        name, getenv(name));
    values = default_values;
end
end