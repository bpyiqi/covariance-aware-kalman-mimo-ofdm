function hash=auditFileSha256(path)
%AUDITFILESHA256 Lowercase SHA-256 of one file.
file=fopen(path,'rb');assert(file>=0,'Cannot open file for hashing: %s',path);cleanup=onCleanup(@()fclose(file));
bytes=fread(file,inf,'*uint8');digest=java.security.MessageDigest.getInstance('SHA-256');if ~isempty(bytes),digest.update(bytes);end
hash=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
end
