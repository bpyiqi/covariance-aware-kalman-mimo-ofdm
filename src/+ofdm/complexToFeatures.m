function H_feat = complexToFeatures(H)
%COMPLEXTOFEATURES Convert [Nfft Nsym 2 2] complex CSI to 8 real features.

N_FFT = size(H, 1);
N_sym = size(H, 2);
H_feat = zeros(N_FFT, N_sym, 8, 'single');
H_feat(:,:,1) = real(H(:,:,1,1));
H_feat(:,:,2) = real(H(:,:,2,1));
H_feat(:,:,3) = real(H(:,:,1,2));
H_feat(:,:,4) = real(H(:,:,2,2));
H_feat(:,:,5) = imag(H(:,:,1,1));
H_feat(:,:,6) = imag(H(:,:,2,1));
H_feat(:,:,7) = imag(H(:,:,1,2));
H_feat(:,:,8) = imag(H(:,:,2,2));
end

