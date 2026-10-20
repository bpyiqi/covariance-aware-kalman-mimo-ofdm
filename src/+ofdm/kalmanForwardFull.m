function fwd = kalmanForwardFull(Z, rho, Q, R)
%KALMANFORWARDFULL Kalman前向滤波，返回完整中间量供RTS平滑使用。
%
% 输入：
%   Z   [F x T] 观测序列（实数特征，每行一个特征维度）
%   rho 标量，AR(1)系数
%   Q   [F x 1] 过程噪声方差（每特征独立）
%   R   标量或 [F x 1]，观测噪声方差
%
% 输出 fwd（结构体）：
%   .x_pred  [F x T] 预测状态均值
%   .p_pred  [F x T] 预测误差方差
%   .x_filt  [F x T] 滤波状态均值
%   .p_filt  [F x T] 滤波误差方差
%   .K       [F x T] Kalman增益
%   .innov   [F x T] 创新序列

[F, T] = size(Z);
Q = Q(:);
if isscalar(R)
    R = R * ones(F, 1);
else
    R = R(:);
end

x_pred = zeros(F, T);
p_pred = zeros(F, T);
x_filt = zeros(F, T);
p_filt = zeros(F, T);
K      = zeros(F, T);
innov  = zeros(F, T);

% 初始化：用第一个观测
x_filt(:,1) = Z(:,1);
p_filt(:,1) = Q + R;          % 初始不确定性

% 第1步预测量（供RTS使用）
x_pred(:,1) = Z(:,1);
p_pred(:,1) = Q + R;
K(:,1)      = p_filt(:,1) ./ max(p_filt(:,1) + R, eps);
innov(:,1)  = zeros(F,1);

for t = 2:T
    % 预测
    xp = rho .* x_filt(:,t-1);
    pp = rho^2 .* p_filt(:,t-1) + Q;

    % 创新
    inn = Z(:,t) - xp;
    S   = pp + R;
    k   = pp ./ max(S, eps);

    % 更新
    x_filt(:,t) = xp + k .* inn;
    p_filt(:,t) = (1 - k) .* pp;

    x_pred(:,t) = xp;
    p_pred(:,t) = pp;
    K(:,t)      = k;
    innov(:,t)  = inn;
end

fwd.x_pred = x_pred;
fwd.p_pred = p_pred;
fwd.x_filt = x_filt;
fwd.p_filt = p_filt;
fwd.K      = K;
fwd.innov  = innov;
end
