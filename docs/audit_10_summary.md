# C1 高级算法审计摘要

## 直接结论

1. 论文 Table 3、Table 4 与正式 MATLAB 结果逐项一致，未发现主要表格的数值伪造或错配。
2. Proposed 的核心数学链条基本正确：局部 LS、残差协方差、复到实映射、Joseph Kalman、MMSE、LLR 和 LDPC 自检均通过。
3. 主要算法结论有证据支持：Proposed 相对 Base 显著降低 NMSE 和 Pre-LDPC BER；相对 Fixed 的 NMSE/BER 差值 bootstrap 区间不跨零。
4. Goodput 不是当前最强证据：Proposed-Fixed 的 Goodput 95% CI 包含零，且该指标未扣除前导/LTF 等帧级开销。
5. 当前代码没有有效 post-LDPC BER，online receiver 的 meanPostLdpcBer 为 NaN；论文不能声称已经验证该指标。
6. 鲁棒性实验明确是 blockwise calibrated，不是严格逐符号 symbol-causal；论文需要收窄措辞或补实验。
7. 已有 SNR/BLER 诊断发现 raw BLER 非单调，甚至 Perfect CSI 也有告警；在 LLR/decoder/分母诊断闭环前，不应外推 SNR threshold 或 link margin。
8. 工程可复现性总体良好，但存在同名脚本副本和 addpath/genpath 路径优先级风险；正式入口本身有冻结 manifest、哈希配对和无 future-read 证据。

## 投稿建议

判定为“有条件通过技术审计”。优先修复 post-LDPC、因果性定义和 BLER 异常三个 P0 问题，然后重新生成相关结果和论文表述。核心方法无需推倒重来，但投稿版本必须收窄未经统计或物理模型支持的强主张。

## 产物

- 01_PROJECT_MAP.md：工程与调用链。
- 02_MODEL_AND_MATH_AUDIT.md：数学与实现审计。
- 03_REPRODUCIBILITY.md：环境与复现实验。
- 04_RESULTS_CONSISTENCY.md：论文表格一致性。
- 05_STATISTICAL_VALIDATION.md：置信区间与样本量。
- 06_ABLATION_AND_ROBUSTNESS_PLAN.md：消融和鲁棒性补强。
- 07_COMPLEXITY_AUDIT.md：复杂度与硬件边界。
- 08_PUBLICATION_READINESS.md：投稿就绪性。
- 09_ACTION_PLAN.md：修复顺序和验收标准。
- quick_math_tests.csv：独立快速数值测试。
- audit_findings.csv：结构化问题清单。
