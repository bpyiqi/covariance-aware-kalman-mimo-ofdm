# C1 可复现性审计

## 环境

- MATLAB：R2024a，24.1.0.2537033。
- 已确认工具箱：MATLAB、Communications Toolbox、Satellite Communications Toolbox。
- 已确认函数：dvbs2ldpc、ldpcEncode、ldpcDecode、qammod、qamdemod、besselj、checkcode。
- 工程没有 mlx 或内部 DOCX 论文副本。

## 可安全复现的检查

以下检查已执行并通过：

1. auditCovarianceAwareFinalValidation50(root,'dryRun',true)：PASS，6 方法、600 行预期结构。
2. auditCovarianceAwareSnrPairedLocalization20(root,'dryRun',true)：PASS，700 行预期结构。
3. auditQualityAwareMechanismDiagnostic20(root,'dryRun',true)：PASS。
4. auditLdpcIdealLlrSelftest(root)：PASS。
5. ucUncertaintyPropagationSelftest(root)：18/18 通过。
6. 对 11 个关键源码运行 checkcode：问题数为 0。
7. quick_math_tests.m：PASS，结果在 quick_math_tests.csv。

## 已有正式实验

正式 50 包结果已存在且完整，结果报告显示 pairing hash 100/100 通过、future reads 0、truth leaks 0、solver failures 0、padding DA uses 0、same-symbol feedback 0。审计未重复执行完整 100 包统计，以避免无必要地消耗时间并改变历史结果。

鲁棒性结果也存在且完整：20 包、SNR 15/20/25 或 Doppler 100/200/300，360 receiver runs，allFinite=1、allPsd=1、solver failures 0，并明确标记为 blockwise calibrated 而不是 strict symbol causal。

## 论文文件限制

已按文档技能尝试渲染 c1.docx，但当前环境没有 soffice/LibreOffice，因此无法完成页面级 PNG 视觉 QA。已完成 DOCX 的段落、表格、公式对象和媒体对象结构提取；论文公式主要以 WMF 图片存在。该限制不影响数值表格与代码指标核对，但版式、公式清晰度和图注位置仍需用户在 Word 中目视确认。

## 推荐复现命令

建议在 MATLAB 中以工程根目录为当前目录，显式传入 root，先运行 dryRun 和自检，再读取既有结果目录。不要从同名历史脚本副本启动实验，不要让 genpath 覆盖冻结入口的依赖顺序。
