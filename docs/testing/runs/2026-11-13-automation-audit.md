# 测试自动化现状审计

日期：2026-11-13。维护：`test_lead`。类型：只读证据审查与文档维护；本次未运行测试、游戏、模拟器、容器或新诊断，未修改runner及历史证据。

## 已有能力与实际收益边界

[GUT试点及原始证据](2026-11-12-gut-pilot.md)已由主代理验收，[M00已归档](../../../openspec/changes/archive/2026-11-12-m00-test-agent-automation-baseline/verification/root-review.md)。固定GUT9.6.1/Godot4.6.1：三组6用例、83断言，冷暖各零跳过/错误。覆盖实际装配与集合规则（显式30秒边界）、真实lobby.tscn组合及InputEvent、真实apply_preview.tscn的HTTP失败/刷新/在途关闭。负断言、空集、pending和超时均有独立拒绝/清理证据，不能只看引擎退出0。官方版本表9.6.1对应4.6.x，9.7.1对应4.7.x，保持现有pin：[官方来源](https://github.com/bitwes/Gut#version-links)。

历史冷/暖引擎执行4.6948/4.4791秒，运行窗口8.1438/7.6837秒；首次准备11.222秒单计。运行内模型介入0；整段研发往返未计量。可减少对应规则/场景的重复手工检查，但没有同覆盖旧基线，不计算节省比例。日常按变化选择相关组运行一次，冷暖比较不是每次默认动作。

后续独立执行说明：本审计记录保留当时环境阻断事实；现已通过显式路径的[定向执行](../../../openspec/changes/archive/2026-11-13-m00-gut-explicit-engine-path/verification/test-report.md)，root已独立签收。未改旧默认路径，不回填为本审计运行。

## 当前入口环境阻断

[run.py](../../../tests/godot/run.py)仍硬编码normal Local下的Godot路径；当前该文件不存在。[入口README](../../../tests/godot/README.md)中的相同先决路径也已不符本机。现存引擎位于 `C:/Users/alienware/AppData/Local/Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Local/PunkLegion/tools/godot-4.6.1/`，console SHA与历史锁一致（`bd9e27c6994a128aaab45cdda4d372de87b91900618ba2de55c6aa29248d5b56`）。本项依据静态源码及本轮主代理Test-Path核查，不代表本次重新运行。

因此：历史试点已验收，当前固定入口存在环境阻断，不能宣称当前可直接执行。本轮未修runner。后续最小实现建议为显式engine参数、保持默认与固定SHA校验、明确前置缺失错误；不扫描安装、不下载引擎、不改旧证据。获派后只做参数/拒绝路径及受影响入口的有界验证，不重跑原生完整矩阵。

## 协作与选集

[协作规则](../README.md)和[用例选集](../cases.md)已明确：开发代理实现与自测；测试代理独立执行/维护证据/收尾；主代理审范围、断言、原始证据和资源终态后签收；进度代理引用签收。各次记录执行、复用、失效、未覆盖及依赖哈希，缺口只补相关断言，不重复整套矩阵。

GUT不替代真实Android安装/触控/HOME/生命周期、真实ENet与新库费用/权限/幂等、渲染或实体性能。当前1076原生及双席结算独立见[M23签收](../../../openspec/changes/archive/2026-11-12-m23-lobby-recovery-android/verification/root-review.md)，不能由源码GUT结果推断。

## M06独立未运行项

[整场入口受阻原报告](../../../openspec/changes/m06-full-pump-playtest-readiness/verification/blocked-entry-report.md)：正常手机大厅读取耗尽，一次明确手动刷新后仍未到可出发状态。未创建mission，未启动两peer/采样器，整场性能未运行，不能记为性能通过/性能回归或GUT试点失败。原始日志缺少请求级元数据，godot:V输出0字节，不能据此归因。

该次设备正常退出，临时2容器及1专网已删除、六新卷保留、私有凭据清理；当前1076六服及共享服务保持，具体终态沿用原报告。本次未再启动任何资源或补场。

## 主代理签收

2026-11-13，root：通过本次文档与证据审计。已审框架评估、用例选集、历史试点报告与原签收、现有runner固定路径及本机路径存在性；官方版本表仍支持保持9.6.1。认可按变化选集、条件复用及专职测试分工。历史6例/83断言不重标为本轮执行，当前入口路径缺口明确保留；没有重新运行测试或据此提升M06、安卓或联机结论。后续引擎路径修订须先建最小OpenSpec任务，再由实现/测试代理分别交付，主代理审查签收。
