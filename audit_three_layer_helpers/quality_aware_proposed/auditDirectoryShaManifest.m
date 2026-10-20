function manifest=auditDirectoryShaManifest(directory)
%AUDITDIRECTORYSHAMANIFEST Stable per-file SHA-256 manifest for a directory.
files=dir(fullfile(directory,'**','*'));files=files(~[files.isdir]);paths=sort(string(fullfile({files.folder},{files.name})).');
relative=erase(paths,string(directory)+filesep);hashes=strings(numel(paths),1);
for i=1:numel(paths),hashes(i)=auditFileSha256(paths(i));end
manifest=table(relative,hashes,'VariableNames',{'relativePath','sha256'});
end
