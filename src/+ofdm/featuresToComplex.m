function H = featuresToComplex(H_feat)
%FEATURESTOCOMPLEX Convert 8 real CSI features to [Nfft Nsym 2 2] complex.

N_FFT = size(H_feat, 1);
N_sym = size(H_feat, 2);
H = zeros(N_FFT, N_sym, 2, 2, 'single');
H(:,:,1,1) = complex(H_feat(:,:,1), H_feat(:,:,5));
H(:,:,2,1) = complex(H_feat(:,:,2), H_feat(:,:,6));
H(:,:,1,2) = complex(H_feat(:,:,3), H_feat(:,:,7));
H(:,:,2,2) = complex(H_feat(:,:,4), H_feat(:,:,8));
end

