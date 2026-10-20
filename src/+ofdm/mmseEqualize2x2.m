function x_hat = mmseEqualize2x2(y, H, noise_var)
%MMSEEQUALIZE2X2 2x2 MMSE equalizer for one subcarrier.

A = H' * H + noise_var * eye(2);
b = H' * y;
if rcond(A) < 1e-10
    x_hat = pinv(A) * b;
else
    x_hat = A \ b;
end
x_hat(isnan(x_hat) | isinf(x_hat)) = 0;
end

