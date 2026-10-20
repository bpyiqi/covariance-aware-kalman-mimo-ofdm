# Fig.2--Fig.5 数据溯源

## 统一来源

汇总来源：
`D:\matlabfile\C1_PhysicalCommunication_Clean\results_three_layer_validation\physicalcom_robustness_ab_v1\robustness_ab_summary.csv`

逐包来源：
`D:\matlabfile\C1_PhysicalCommunication_Clean\results_three_layer_validation\physicalcom_robustness_ab_v1\robustness_ab_packet_level.csv`

协议来源：
`D:\matlabfile\C1_PhysicalCommunication_Clean\results_three_layer_validation\physicalcom_robustness_ab_v1\robustness_ab_manifest.txt`

manifest SHA256：`F6E58ADED2F1EF0A4419444FB62AA88E29682BE66C3305D4B87127BC0814D988`。

## Fig.2：NMSE versus SNR

- 实验：A；Doppler = 200 Hz；SNR = 15/20/25 dB。
- 方法：Base、Fixed、Proposed。
- 每点：20 个物理包。
- 数值顺序为 SNR = 15、20、25 dB。

| 方法 | NMSE |
|---|---|
| Base | 0.0625332295894623, 0.0200808178633451, 0.00660537835210562 |
| Fixed | 0.0381590388715267, 0.00973213277757168, 0.00305093987844884 |
| Proposed | 0.029172932729125, 0.00723643507808447, 0.00207515433430672 |

## Fig.3：NMSE versus Doppler

- 实验：B；SNR = 20 dB；Doppler = 100/200/300 Hz。
- 方法：Base、Fixed、Proposed。
- 每点：20 个物理包。

| 方法 | NMSE |
|---|---|
| Base | 0.0197649020701647, 0.0200808178633451, 0.0205294601619244 |
| Fixed | 0.00945144146680832, 0.00973213277757168, 0.0102607188746333 |
| Proposed | 0.00712444027885795, 0.00723643507808447, 0.00788591150194407 |

## Fig.4：Pre-LDPC BER versus SNR

- 实验：A；Doppler = 200 Hz；SNR = 15/20/25 dB。
- 方法：Base、Fixed、Proposed、Perfect CSI。
- 每点：20 个物理包。
- 指标明确为 Pre-LDPC BER，不是 Post-LDPC BER。

| 方法 | Pre-LDPC BER |
|---|---|
| Base | 0.114369598765432, 0.0509822530864198, 0.0197692901234568 |
| Fixed | 0.0893950617283951, 0.0371975308641975, 0.0143518518518519 |
| Proposed | 0.0796743827160494, 0.0344714506172839, 0.0139390432098765 |
| Perfect CSI | 0.0510231481481481, 0.0198078703703704, 0.00644058641975309 |

## Fig.5：Pre-LDPC BER versus Doppler

- 实验：B；SNR = 20 dB；Doppler = 100/200/300 Hz。
- 方法：Base、Fixed、Proposed。
- 每点：20 个物理包。

| 方法 | Pre-LDPC BER |
|---|---|
| Base | 0.0505077160493827, 0.0509822530864198, 0.051383487654321 |
| Fixed | 0.036287037037037, 0.0371975308641975, 0.038295524691358 |
| Proposed | 0.0339151234567901, 0.0344714506172839, 0.0354560185185185 |

## 中心点复用

20 dB、200 Hz 中心条件只有一组逐包数据，逐包 CSV 中标记为 `experiment=A+B, conditionId=2`。汇总 CSV 在 A 与 B 两个扫描视图中各保留一个对应汇总行。恢复 CSV 用 `summary_experiment` 和 `packet_experiment` 明确记录了这一点，未把中心条件复制成新的物理包样本。

## 与原图的关系

根目录 `plot_C1_Fig2_to_Fig5.m` 的定义与本任务一致：Fig.2 NMSE-SNR、Fig.3 NMSE-Doppler、Fig.4 Pre-LDPC BER-SNR、Fig.5 Pre-LDPC BER-Doppler。旧的 `paper\figures\plot_Fig2_to_Fig5.m` 将 Fig.3 和 Fig.4 的文件名对调；这属于图号/文件名冲突，不是数据缺失。投稿前必须统一正文图号、caption、文件名和脚本调用。

