function file_name = taggedFileName(base_file, output_tag)
%TAGGEDFILENAME Add a safe output tag before the file extension.
%   Empty tags return BASE_FILE unchanged. Non-empty tags are sanitized for
%   portable root-level experiment artifact names.

tag = strtrim(string(output_tag));
if tag == ""
    file_name = char(base_file);
    return;
end

tag = regexprep(char(tag), '[^A-Za-z0-9_-]', '_');
[folder, name, ext] = fileparts(char(base_file));
tagged = sprintf('%s_%s%s', name, tag, ext);
if isempty(folder)
    file_name = tagged;
else
    file_name = fullfile(folder, tagged);
end
end
