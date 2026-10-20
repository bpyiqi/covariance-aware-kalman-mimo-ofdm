# C1 论文—代码—结果一致性

## 核心结论

c1.docx 中 Table 3 与正式 50 包验证结果逐项一致。Table 4 中 Fixed、OJCD、Perfect CSI 也与正式结果逐项一致。论文主要数值表不是由另一套未知代码生成的，且冻结验证报告与论文表格的 NMSE、Pre-LDPC BER、Soft EVM、Codeword pass、Goodput 均能对齐。

## 对齐的代表性数值

| Payload | Method | NMSE | Pre-LDPC BER | EVM | CW pass | Goodput |
|---|---|---:|---:|---:|---:|---:|
| 169 | Base | .01305098 | .03138704 | .17983 | .4600 | 22.02556 |
| 169 | Proposed | .00332035 | .01823796 | .10887 | .6800 | 32.55953 |
| 507 | Base | .01377959 | .03187233 | .18022 | .5200 | 24.89846 |
| 507 | Proposed | .00294425 | .01822037 | .10437 | .7867 | 37.66690 |

Table 4 的 Fixed、OJCD、Perfect CSI 数值同样对齐；Perfect CSI 的 NMSE 为 0 是指标定义下的理想 CSI 基线，不代表接收机实际估计误差为零。

## 论文设置与代码设置

- 主实验 SNR 20、Doppler 200、50 packets、payload 169/507：一致。
- Doppler 扫描 100/200/300 与鲁棒性结果：一致。
- 169 payload 的 96 个剩余编码位、507 payload 的 288 个剩余编码位：代码存在明确 validReMask。
- Proposed 的主路径是局部 LS 协方差感知 Kalman，而不是离线使用真值协方差。

## 需要补充或修正

1. 论文必须写明主结果来自 seed 20260721 的冻结 50 包验证，bootstrap 使用 seed 2026072101。
2. 鲁棒性实验使用独立 master seed 2026072801，不能与主表当作同一批随机样本。
3. 鲁棒性报告将因果性标为 blockwise_calibrated_not_strict_symbol_causal；正文若写成 strict online causal，需要改写或补实验。
4. Online receiver 没有保留 post-LDPC bit vector，meanPostLdpcBer 最终为 NaN；论文不能声称已经报告 post-LDPC BER。
5. Goodput 采用 passed×(K-32)/(N×Tsym)，未扣除前导/LTF 和其他帧级开销，应避免直接称为 MAC 层吞吐。
6. 已有 SNR localization 报告提示 raw BLER 存在非单调现象，即使 Perfect CSI 也出现异常；在 decoder/LLR 诊断解决前，不应从该实验外推 SNR threshold 或 link margin。
