# Godot测试框架评估

状态：GUT9.6.1已在隔离工程实际试运行，主代理已采纳。适用：本项目Godot 4.6.1与GDScript。维护角色：`test_lead`。核查日期：2026-11-12。

已固定 **GUT 9.6.1** 并完成小型试点，不升级引擎，不同时维护两套断言框架。GUT官方兼容表将9.6.1对应到Godot 4.6.x；已有规则检查和场景脚本可逐项接入统一报告。[官方版本表](https://github.com/bitwes/Gut#version-links)

## 框架比较

| 方案 | 与当前项目的关系 | 处置 |
|---|---|---|
| GUT 9.6.1 | GDScript测试、命令行选集、setup/teardown、有界异步等待、JUnit XML；明确对应Godot 4.6.x | 已锁版本/提交/ZIP哈希并通过本机4.6.1三组试点；正式采纳已由主代理签收 |
| GdUnit4 6.2.x | 官方兼容表包含4.6.1，带Scene Runner、模拟输入、mock/spy和报告；master 7.0要求4.7 | 保留备选，不装latest、不与GUT并装；只有试点暴露具体缺口时再评估切换 |
| 既有SceneTree/Python脚本 | 已有真实规则、UI、HTTP和ENet检查，覆盖部分项目契约 | 先登记、选用与封装；不因引入框架全部重写 |

GUT可按指定测试或目录选集，CLI区分通过与失败退出码并导出JUnit XML。框架的pending不一定影响退出码，因此运行器还须核对实际测试数和跳过项，不能只看退出0。[命令行说明](https://gut.readthedocs.io/en/v9.6.1/Command-Line.html)、[结果导出](https://gut.readthedocs.io/en/v9.6.1/Export-Test-Results.html)

GdUnit4的版本要求和Scene Runner能力来自[官方仓库](https://github.com/godot-gdunit-labs/gdUnit4#compatibility-overview)及[官方文档](https://godot-gdunit-labs.github.io/gdUnit4/latest/)。它的场景工具值得保留为备选，但当前没有为此引擎升级或双框架维护的必要。

## 首个试点范围

| 类别 | 真实生产对象 | 首批断言与通过条件 |
|---|---|---|
| 规则 | `game/loadout/rules.gd`；补充`game/net/party_mission.gd`边界 | 用当前内存夹具验证装配归属、接口与额度边界；用已有显式时间参数验证全员到场/到期缺席，不真实睡眠30秒 |
| 场景组合 | `game/party/lobby.tscn`及原脚本 | 实例化现有场景，核初始读保护、正常快照后的按钮状态、实际控件输入与请求信号次数、草案保留和节点释放 |
| 异步失败 | `game/owned/apply_preview.tscn`及原脚本 | 本机临时HTTP夹具先500再200；正常入口发出预览请求，失败时禁确认，明确刷新后恢复；关闭途中不更新旧界面，不直接调用完成回调冒充网络 |

第三类场景主要依赖Catalog和Endpoints，不需3D美术或完整基地/探索入口，可先证明异步测试的价值。预览接口虽使用POST，测试必须注明它是预览读取，不能据此宣称制造/出征写入幂等已通过。

试点使用隔离测试工程、独立user目录和本轮夹具；不改正式APK、冻结源或游戏行为。插件和测试文件不得进入正式发行包。可运行入口与固定依赖见[tests/godot/README.md](../../tests/godot/README.md)，本次冷暖、负对照与资源终态见[执行报告](runs/2026-11-12-gut-pilot.md)。

每类至少有一个故意破坏断言或响应的负对照，证明运行器能报失败；还需验证空用例/全部跳过不假绿、结构化报告、成功/失败/超时收尾。保持小范围，不能为断言数量复制整套生产逻辑。

## 能减少的重复与保留边界

GUT的 `wait_for_signal`、`wait_until` 提供超时边界，适合等待真实信号和状态，减少固定睡眠和逐步模型往返。[异步等待](https://gut.readthedocs.io/en/v9.6.1/Awaiting.html)。`simulate`仅调用process方法，不推动真实计时器，不能用它伪造网络或原生后台事件。[模拟限制](https://gut.readthedocs.io/en/v9.6.1/Simulate.html)

当前M15已有25场景/59检查约147秒的自动化运行，主要额外成本来自安卓环境准备、模型逐图往返、工具错误和机械重复整套矩阵，见[既有主验](../../openspec/changes/archive/2026-11-11-m15-lobby-read-recovery/verification/root-review.md)。优先减少这些编排和复测成本，不把所有收益归于框架。

源代码场景测试可覆盖按钮、信号和读状态逻辑；它不能代替签名包安装、Android键盘/触控、HOME/返回、真实ENet认证、个人SQL结算或设备帧率。R3六个原生故障场景是否复用，按[覆盖交接](runs/2026-11-12-handoff.md)逐条核依赖，而非要求框架重新模拟一遍。
