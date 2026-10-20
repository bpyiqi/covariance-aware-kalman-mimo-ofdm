function x_hat = mmseEqualizeFeatureGrid(feat, t, data_sc, y, noise_var)
%MMSEEQUALIZEFEATUREGRID Vectorized 2x2 MMSE equalization over subcarriers.

a = complex(squeeze(feat(data_sc,t,1)).', squeeze(feat(data_sc,t,5)).');
c = complex(squeeze(feat(data_sc,t,2)).', squeeze(feat(data_sc,t,6)).');
b = complex(squeeze(feat(data_sc,t,3)).', squeeze(feat(data_sc,t,7)).');
d = complex(squeeze(feat(data_sc,t,4)).', squeeze(feat(data_sc,t,8)).');
y1 = y(1,:);
y2 = y(2,:);
A11 = abs(a).^2 + abs(c).^2 + noise_var;
A22 = abs(b).^2 + abs(d).^2 + noise_var;
A12 = conj(a).*b + conj(c).*d;
A21 = conj(A12);
r1 = conj(a).*y1 + conj(c).*y2;
r2 = conj(b).*y1 + conj(d).*y2;
detA = A11.*A22 - A12.*A21;
detA = detA + (abs(detA) < eps) .* eps;
x_hat = zeros(2, numel(data_sc));
x_hat(1,:) = (A22.*r1 - A12.*r2) ./ detA;
x_hat(2,:) = (-A21.*r1 + A11.*r2) ./ detA;
end

