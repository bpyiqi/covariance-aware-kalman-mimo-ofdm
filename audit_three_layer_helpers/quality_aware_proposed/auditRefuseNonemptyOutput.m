function auditRefuseNonemptyOutput(out)
%AUDITREFUSENONEMPTYOUTPUT Reject accidental overwrite of any nonempty directory.
if exist(out,'dir')~=7,return;end
files=dir(out);assert(~any(~ismember({files.name},{'.','..'})), ...
    'Refusing to overwrite nonempty output: %s',out);
end
