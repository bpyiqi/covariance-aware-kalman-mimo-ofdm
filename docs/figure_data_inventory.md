# C1 Fig.2--Fig.5 原始绘图数据清单

## 结论

四张图所需的真实数值均已在 clean 工程中找到。数据来自 `physicalcom_robustness_ab_v1` 的冻结逐包 CSV 与冻结汇总 CSV，不使用 50 包主实验、20 包独立 seed 消融、历史图片反推或新仿真。

## 已核对的关键资产

| 资产 | 完整路径 | 内容 | 状态 |
|---|---|---|---|
| 冻结逐包数据 | `D:\matlabfile\C1_PhysicalCommunication_Clean\results_three_layer_validation\physicalcom_robustness_ab_v1\robustness_ab_packet_level.csv` | 360 行，逐物理包、逐方法 | VERIFIED_COMPLETE_WITH_CAVEAT |
| 冻结汇总数据 | `D:\matlabfile\C1_PhysicalCommunication_Clean\results_three_layer_validation\physicalcom_robustness_ab_v1\robustness_ab_summary.csv` | 21 个条件-方法汇总行 | VERIFIED_COMPLETE |
| 实验 manifest | `D:\matlabfile\C1_PhysicalCommunication_Clean\results_three_layer_validation\physicalcom_robustness_ab_v1\robustness_ab_manifest.txt` | seed、协议、样本量、质量门 | VERIFIED_COMPLETE |
| checkpoint MAT | `D:\matlabfile\C1_PhysicalCommunication_Clean\results_three_layer_validation\physicalcom_robustness_ab_v1\robustness_ab_checkpoint.mat` | `packetRows` table，360 行 | VERIFIED_COMPLETE |
| 当前恢复入口 | `D:\matlabfile\C1_PhysicalCommunication_Clean\plot_C1_Fig2_to_Fig5.m` | Fig.2--Fig.5 原始风格重建入口 | MAPPING_MATCHES_TASK |
| 当前论文绘图脚本 | `D:\matlabfile\C1_PhysicalCommunication_Clean\paper\figures\plot_Fig2_to_Fig5.m` | 直接读取汇总 CSV 的旧绘图入口 | FIG3_FIG4_NAMING_CONFLICT |

## 协议

- 2×2 MIMO-OFDM，payload = 169 symbols。
- SNR 扫描：15、20、25 dB，Doppler = 200 Hz。
- Doppler 扫描：100、200、300 Hz，SNR = 20 dB。
- 每个曲线点对应 20 个物理包。
- robustness master seed = 2026072801；packet seeds = 2026072802--2026072821。
- 主方法为 Base、Fixed、Proposed。Fig.4 的 SNR Pre-LDPC BER 数据还包含 Perfect CSI，对应现有恢复入口的 method list。
- causality label = `blockwise_calibrated_not_strict_symbol_causal`。

## 排除的候选

- `validation50_*`：50 包正式主实验，不能替代鲁棒性扫描。
- `independent_seed_*`：20 包独立 seed 验证，不能替代鲁棒性扫描。
- `physicalcom_robustness_ab_v1_prepare`：只有设计与计划，不是数值结果。
- 根目录旧版 `Fig_*.pdf` 与长 payload/video-link 资产：没有当前 C1 鲁棒性数据绑定。
- `.fig/.pdf/.png`：仅作图形输出和 QA 证据，不作为原始数值来源。

## 文件一致性

clean 与历史工程中同名 robustness A/B 关键 CSV、manifest 的 SHA256 一致。恢复文件只复制已核对的数值，不覆盖任何冻结文件。

