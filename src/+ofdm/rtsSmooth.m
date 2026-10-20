function smo = rtsSmooth(fwd, rho, Q)
%RTSSMOOTH Rauch-Tung-Striebel反向平滑器。
%
% 输入：
%   fwd  kalmanForwardFull的输出结构体
%   rho  标量，AR(1)系数
%   Q    [F x 1] 过程噪声方差
%
% 输出 smo（结构体）：
%   .x_smo     [F x T]   平滑状态均值   E[x_t | z_{1:T}]
%   .p_smo     [F x T]   平滑误差方差   Var[x_t | z_{1:T}]
%   .p_cross   [F x T-1] 交叉协方差     Cov[x_t, x_{t-1} | z_{1:T}]，t=2..T
%                         p_cross(:,k) 对应 Cov[x_{k+1}, x_k]

[F, T] = size(fwd.x_filt);
Q = Q(:);

x_smo   = zeros(F, T);
p_smo   = zeros(F, T);
p_cross = zeros(F, T-1);   % p_cross(:,t-1) = Cov[x_t, x_{t-1}|z_{1:T}]

% 初始化：最后一步平滑 = 滤波
x_smo(:,T) = fwd.x_filt(:,T);
p_smo(:,T) = fwd.p_filt(:,T);

% 反向递推
for t = T-1:-1:1
    % RTS增益
    % G_t = p_filt(:,t) * rho / p_pred(:,t+1)
    G = fwd.p_filt(:,t) .* rho ./ max(fwd.p_pred(:,t+1), eps);

    % 平滑均值和方差
    x_smo(:,t) = fwd.x_filt(:,t) + G .* (x_smo(:,t+1) - fwd.x_pred(:,t+1));
    p_smo(:,t) = fwd.p_filt(:,t) + G.^2 .* (p_smo(:,t+1) - fwd.p_pred(:,t+1));

    % 交叉协方差 Cov[x_{t+1}, x_t | z_{1:T}]
    % p_cross(:,t) 对应索引t（即x_{t+1}与x_t之间）
    p_cross(:,t) = G .* p_smo(:,t+1);
end

smo.x_smo   = x_smo;
smo.p_smo   = p_smo;
smo.p_cross = p_cross;
end
