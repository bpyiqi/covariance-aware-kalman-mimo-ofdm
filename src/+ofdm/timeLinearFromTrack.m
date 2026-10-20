function H_time = timeLinearFromTrack(H_obs, track_stride)
%TIMELINEARFROMTRACK Linear interpolation between sparse tracked symbols.

N_FFT = size(H_obs, 1);
N_sym = size(H_obs, 2);
num_ch = size(H_obs, 3);
track_idx = unique([1:track_stride:N_sym, N_sym]);
H_time = zeros(size(H_obs), 'single');
t_all = (1:N_sym).';
for ch = 1:num_ch
    obs = squeeze(H_obs(:,track_idx,ch));
    for k = 1:N_FFT
        H_time(k,:,ch) = single(interp1(track_idx(:), double(obs(k,:)).', ...
            t_all, 'linear', 'extrap'));
    end
end
end

