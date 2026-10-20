function H = featuresToMatrix(feat, k, t)
%FEATURESTOMATRIX Extract a 2x2 complex channel matrix from feature CSI.

h11 = complex(feat(k,t,1), feat(k,t,5));
h21 = complex(feat(k,t,2), feat(k,t,6));
h12 = complex(feat(k,t,3), feat(k,t,7));
h22 = complex(feat(k,t,4), feat(k,t,8));
H = [h11, h12; h21, h22];
end

