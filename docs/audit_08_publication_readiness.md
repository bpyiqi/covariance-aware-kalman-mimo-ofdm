# C1 投稿就绪性判定

## 判定

当前状态：有条件通过技术审计，不建议立即以“严格在线实时、已显著提升 Goodput、已完成 post-LDPC BER”版本投稿。核心算法和主要论文表格是可追溯且数值一致的，但仍有三个投稿阻断项：post-LDPC 指标缺失、因果性措辞过强、SNR/BLER 异常未闭环。

## 已被证据支持的主张

- 局部 LS 协方差感知 Kalman 在当前仿真设置中降低 CSI NMSE。
- Proposed 相对 Base 的 Pre-LDPC BER、EVM 和 codeword pass 在正式配对实验中改善。
- Proposed 相对 Fixed 的 NMSE 和 Pre-LDPC BER 改善具有配对 bootstrap 支持。
- 协方差估计包含 LLR、秩、NIS 和 PSD 防护，数学实现通过自检。
- Table 3 和 Table 4 与冻结结果目录数值一致。

## 需要收窄或补证据的主张

- “strict symbol-causal”：当前只能支持 blockwise calibrated，除非补逐符号时间访问审计。
- “显著提高 Goodput”：Goodput CI 包含 0，且口径未扣除前导开销。
- “改善 post-LDPC BER”：当前值为 NaN，需补齐。
- “SNR threshold/link margin”：raw BLER 非单调，需先修复 decoder/LLR 诊断。
- “实时硬件可部署”：缺少 FPGA/ASIC 资源与时序证据。

## 论文最小修改清单

1. 在 Methods 中给出 seed、packet 数、payload 分母、Goodput 公式和开销口径。
2. 加入 Proposed-Fixed 的 paired bootstrap CI，并说明 Goodput CI 包含 0。
3. 用 blockwise calibrated wording 替代 strict online wording，或补实验。
4. 删除或补齐 post-LDPC BER。
5. 解释 LTF 初始估计和子载波频率映射。
6. 对 raw BLER 非单调现象给出诊断和处理，不做未经验证的门限外推。

## 最终建议

完成上述 P0 修复后重新生成所有相关表格、图和摘要；若新结果与现有方向一致，可进入投稿前格式和语言审校。
