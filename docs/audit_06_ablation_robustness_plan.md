# C1 消融与鲁棒性计划

## 已有证据

正式六方法对照已覆盖 Base、Fixed、Proposed、OJCD、Oracle、Perfect CSI。Proposed 还通过局部候选、LLR 门控、秩门控、NIS 门控和 PSD 保护形成了完整实现链。已有物理鲁棒性实验覆盖 SNR 15/20/25 和 Doppler 100/200/300。

## P0：投稿前必须处理

### Post-LDPC 指标

当前 online receiver 只返回 LDPC 解码结果用于通过/失败，未保留 post-LDPC bit vector，所以 meanPostLdpcBer=NaN。应新增解码后比特与参考 payload 的对齐输出，并在所有方法上统一计算；如果不需要该指标，应删除论文中的相关表述。

### 因果性定义

主路径的结果可审计为固定块内流程，但鲁棒性报告明确标注 blockwise_calibrated_not_strict_symbol_causal。必须二选一：将论文措辞改成 blockwise calibrated/causal-within-block，或补充严格逐符号在线接收实验，并记录每一符号可访问的数据时间戳。

### SNR/BLER 异常

已有 anomaly report 显示 raw BLER 非单调，且 Perfect CSI 也有异常。应先审计 LDPC 输入 LLR 的 bit ordering、符号、幅度归一化、validReMask 和 BLER 分母，再重新生成 SNR 曲线。修复前不应做门限或链路余量结论。

## P1：建议补充

- LTF 训练序列：明确从完整接收 LTF 计算 2×2 H 估计，或在论文中明确当前全 H0 带噪初值是仿真假设。
- 频率约定：用一个单独单元测试验证 fftshift、子载波编号、路径相位和数据子载波提取的一致性。
- Goodput：另给出扣除前导、LTF、CP、导频等开销后的帧级吞吐率。
- 稳定性：增加每个设置至少 200 packet，或给出跨 seed 重复实验。

## P2：工程质量

- 合并或重命名同名历史脚本，降低 addpath 路径优先级风险。
- 将 MATLAB 版本、toolbox 版本、git commit、seed、配置 hash 写入结果 manifest。
- 保留 post-LDPC bits、accepted DA count、reject reason histogram，便于审稿复核。

## 最小可接受闭环

修复 LLR/decoder 诊断，重跑 SNR 与 Doppler，补 post-LDPC BER，明确因果性措辞，再以现有 50 包 paired bootstrap 为基线追加一个独立 seed。若新增结果保持方向一致，论文的主要方法结论可进入投稿前终审。
