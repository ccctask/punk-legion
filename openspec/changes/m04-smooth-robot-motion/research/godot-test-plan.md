# Godot运动改进：最小诊断与测试选集草案

状态：只读规划，待root评审；2026-11-18，motion_test_plan临时承担test_lead规划职责。没有运行Godot、测试、SDK、模拟器、HTTP、数据库或Docker，没有修改生产/测试实现或任务勾选。以下均不构成产品通过、工具源准入或执行门。

## 结论与当前基线

应先用Godot真实生产类和场景回答“服务是否按时推进、包何时到、显示如何追点”，再验新的GDScript运动呈现组件；不能只跑旧P95或录一段视频判断顺滑。当前1084/manifest4ea595…47bd是客户端新基线，用户六R2后端仍为原镜像/来源，必须分列。固定Godot4.6.1 console SHA bd9e27c6…5b56，GUT9.6.1及其archive SHA `343ba244e66e110273f4f6ca5343c16858eae19c0e35e9b45d404cf3385eba81`锁保持；性能与几何安全分别验收。

现有诊断不足以还原全部因果：

- `game/diagnostics/baseline.gd`的`_after_draw/_publish`保存渲染帧时、可见数量、draw calls和汇总，执行本地battle，并无真实网络到包/逐体显示pose时间轴。
- `game/party/tests/mobile_perf.gd::_timed_sync/_measure`记录阶段帧时、sync成本及CPU/GPU；未记录每包服务时间、接收monotonic、权威pose与显示pose对应关系。
- `game/net/solo.gd::_delta`有elapsed/pos/heading/walking并原位改state后emit changed；`expedition::_sync`将targets指向state.units，`_process`用`delta*16`追最新点。仅在changed回调保Dictionary引用，下一包会改掉旧样本；采样必须立即拷贝所需标量/Vector2，不保共享可变字典当历史。
- Solo普通delta没有路径拐点历史。两个合法端点的Godot线性插值可能穿转角，不能把“调用Vector2.lerp”当几何安全证明。若产品选择只客户端试点，必须明确可信路径/样本的来源或保守fallback，测试要有穿角反例。

建议先在隔离QA层观察生产对象，复用真实`net.changed`和正常SceneTree/`RenderingServer.frame_post_draw`。如无法从现有公开对象观察服务器每个真正sim step，可在已签AR后使用窄继承包装记录一次super前后结果；不得复制_walk/规划规则、加入常驻Autoload、改变tick/速率/HP或绕过碰撞。需要修改生产诊断开关时回root明确生命周期与发行排除，不默认塞永久trace。

## 现有入口与复用边界

| 已有路径 | 可复用 | 不可直接声称 |
|---|---|---|
| `tests/godot/run.py`、`process_owner.py`、固定GUT锁 | 真实依赖闭包、独立userdir、JUnit空/skip拒绝、唯一Windows Job及失败finally清理；适合小型呈现组件/场景生命周期测试 | 当前GROUPS仅rules/scene/async/alerts/treasure/refresh/refresh_pages/refresh_loot，**没有movement或motion组**，本文件不列虚构可执行命令；新组/闭包须先工具AR |
| `openspec/changes/m04-unit-movement-clearance/verification/testing/run.py`与`rules_probe.gd` | 实际Sim/Field/当前Mission：M1原子选点、M2同版本restore、M4钻头接近、M5逐段安全及已走前缀、AUTO_REPLAN节制、M3成本；按变更挑子集 | 旧门已消费；不能复用旧plan/grant/work。runner白名单及固定schema须新锁，新增case须先AR；M6/M7旧Field差分要求完整旧路径等值，若新路径形状有意改变不能机械当通过门 |
| 同目录`consumer_probe.gd` | `SOLO_SCRAP/COVER_ARRIVAL/PUMP_ROUTE/ARMORY_ROUTE/EXERCISE_MOVE`等真实current类自然消费者与恢复；阻挡/短射程/固定炮台按影响挑选 | 不为一次显示改动重跑全部消费者；不复制一套战斗算法/业务夹具 |
| 同目录`n_solo.gd`、`n_peer.gd`、`outing_ui_peer.gd`及`non_room_ui_support.py` | ENet实例/端口/源锁/QA admission oracle/真实RPC和场景生命周期的既有组合方法 | 旧outing_ui_peer在流程中显式关闭/重开server physics以控制反馈；旧n_solo覆_service是admission oracle，不是真实账户服务。**不能直接运行旧流程来证明自然20Hz、网络到包或服务器不卡**；只复用方法，不复用其刺激/已过期限的执行门 |
| M06正常帧采集工具和1082原始P95证据 | 未变资源依赖的历史结果、采样/帧时原始格式及限定解释方法 | 不能把旧1082的P95/118及1066ms长帧直接归因此次算法，也不能用headless或同步假时间证明Android帧率 |

## 先诊断，后修改：一段路线的共同时间轴

建议第一轮只选标准Solo，Godot服务器真实20Hz + 一个实际渲染客户端，最多两个引擎；不需要Android/真机/六个容器或完整战斗。新建内存Mission和独立QA userdata，正常命令产生直线、90度绕障、短距离停止/反向；固定路线与失败条件先写入准确plan，不现场换点追绿。

服务器记录真实sim elapsed、每步wall cost、权威pos/path index/walking/heading与实际发布时刻；客户端在接受回包后记录服务elapsed、Time.get_ticks_usec接收时刻和标量pose，在实际frame_post_draw记录渲染时间、当前呈现pose、动画状态。两进程单调时钟无共同epoch，不能直接相减算单程延迟；按服务elapsed/seq对齐，报告接收间隔和buffer age，另有握手估计也须说明误差。命令发送/ACK/首次权威移动/首次显示移动分列，不能把按钮反馈当机体开始走。

现有ENet调度实际发布门限可由上述新观察确定，不能用0.12的倒数代测量。若正常服务器step发生大停顿，应先登记该原因，不能通过客户端长缓动掩盖。首轮无需网络故障注入：先取得真实正常轨迹；抖动/乱序属于下一层的明确合成刺激，证据分账。

## 分层选集

| 层 | 最小断言 | 平台与限制 |
|---|---|---|
| A1 呈现数值/场景生命周期 | 等速样本下在30/60Hz合成delta采样速度连续；不因帧率改变轨迹总时长；±PI最短角；晚/重/乱序拒绝；短缺包不无限外推；stage/席位代次切换、首次生成、死亡、退场/释放/后台恢复显式reset，不从原点飞来 | GUT实际生产组件/真实SceneTree；合成delta仅是数值检查，**不是实测30/60FPS**。采用的delay/cap必须先由root据诊断签参数 |
| A2 Godot接入 | 实际场景收到新状态后保存独立历史，不被下一state原位改写；Unit.sync消费呈现数据且不写权威字典；禁止双重物理插值/手动追点叠加；Attack/Death优先和walking切换不过度重启 | 正常SceneTree和所需Autoload就绪后加载真实场景；不能以孤立check-only中不存在Autoload的报错判产品失败，也不能用假Autoload绕过 |
| A3 几何/视觉 | 一条真直角绕障及门柱旁路线；每个实际显示段检查所选可信安全合同；缺拐点/样本时fallback不把机体画进墙；停止后无明显来回抖，死亡不滑走；带盾机朝向显示误差受限、攻击/减伤继续权威 | 小型真实渲染Godot场景 + 记录pose；视频仅辅助。显示延迟轨迹需对齐其呈现时刻，不能把与“最新服务器位置”的必然距离都判算法错误 |
| B 路径跟随改变时 | M1/M4/M5/AUTO_REPLAN、COVER_ARRIVAL、动态阻挡取消与窄门；实际扫过整段而非只比较终点；body radius/门柱/钻头射程/0.5sim错峰不变；改到持久运动字段则M2当前版本恢复并同输入继续等值 | 用已有M04规则/consumer入口新锁；不碰旧格式或导旧库，不以M6原完整路径必须等值约束有意的新轨迹 |
| C 权威速度/转向改变时 | 最大速度不暗改；短起步、短刹停、不越目标；突然反向/阻挡时不延迟取消；shield角速度/正面伤害不变；新velocity/turn状态本轮strict checkpoint完整恢复，缺/非法字段明确拒绝而非旧格式回填 | 真实Sim规则先行；若影响Python秘宝权威则另审它的不同step和消费者，不能Godot一端通过就称全模式通过 |
| D 真网络与成本 | 正常Solo实际RPC与自然时钟一次；如改net包字段/发送节拍/协议，则扩大至每个受影响模式的真实RPC消费和重连，保旧序号/阶段/权限；比较server步时/寻路query/字节和渲染帧时 | headless规则不代ENet、桌面不代Android。共享组件接多个页面但net未变时，可页面生命周期+模式不同周期合成覆盖，是否加第二模式实网由实际接口差异定 |

首期仅呈现时，不重跑费用、首胜掉落、维修30秒、支付、三人完整泵站或全地图矩阵；这些领域规则未改。若权威path/速度改变并影响到达/战斗，相关消费者断言即失效，不能沿旧胜利结论外推新平衡。用户物理设备和听感仍由负责人完整可玩交付后终验，不能当前代签或要求提前设备。

## 数值记录与门槛来源

直线稳态区间的显示速度变异、近零停顿次数、角速度/加速度峰值、command/ACK/可见响应、buffer年龄/丢样本次数、位置/角差分布、每段几何/身体侵入、真实帧时和server wall cost分别报告。阈值不能先拍一个百分比让算法追绿：基线先记录实际值，root签本项目允许的延迟/位置误差和改善门；有效样本不足或路线未真正走到判未完成。与旧版比较必须同一源差异声明、固定输入/场景和环境，不删慢样本/择优多次执行。

## 预算与资源草案

预算仅供root选集，不是新执行许可：

- 小型组件GUT：解析/准备使用原入口独立预算（通常prepare上限90秒、run上限60秒）；若仅纯GD闭包不需要视觉导入，不强制加载整套模型。实际新组/路径未实现，须先最小工具AR，不新增assertion框架。
- 沿用M04规则runner时保其原`check_only10/rules_each45/host_each15/work180/cleanup_absolute210/outer220`，以白名单子集执行；不能为本次文档自动增加其中deadline。
- 一次正常网络诊断候选：准备/必要资源导入独立≤90秒，实际路线观察≤30秒/共同工作≤60秒、清理≤20秒；如复用既有准确runner有更短硬限则按其原限，新增接口或预算改变先AR。最多server+render client两个引擎，不启动SDK/容器/数据库，角色和端口独占。
- 安卓一次必要平台/运动观感及帧时切片只在Godot方案/源码/独立快速检查通过后安排；新包、精确选集与资源预算另签。不要把所有场景塞入一次逐图窗口，也不重演F a2为了最后无关导航耗尽公共预算。

首次失败保原首错/未运行项，不自动重试、扩时或改坐标。沿用唯一process_owner.owned_run；成功/失败/超时清自己的窗口、引擎、监听和子进程，保运行证据后核Job/强身份空；不按进程名结束，也不触用户六R2/手机。当前此计划零资源，无待接管实例。

## 当前只读源码定位

以本轮工作区为准（不是旧报告行号）：Field AStarGrid2D及DIAGONAL_MODE_NEVER在`game/battle/field.gd:12–18`；实际Sim._walk/安全扫段/恒速消耗在`game/battle/simulation.gd:640–719`；Solo delta接受原位修改在`game/net/solo.gd:703–739`；Expedition targets/actor更新在`game/expedition/expedition.gd:881–911`，显示lerp在1086；Camp在636，Treasure在409；Unit显示heading在`game/battle/unit.gd:114–116`。

核心当前SHA：Sim `6b956894aee08ba564d654e3d7b45252460552ef216b5dea4e38dba292419c01`；Field `b74a2ecac9e2793c379ccdf049e7e20c408b0e8451c2f187c14eeda0dd790757`；Expedition `289a046b96ad3fcdaa20aa03ce2c059ec57c9a22e36831b45c24dc043a6ae111`；Solo `309f3107e561bb14b9376a02f16f2b375a2971320bd567d5cdf32e794aedbba2`；Unit `f2523af7f7b3aa1fb72359635b6faa00275c7ae8de74ed601c67b2e5153f69b9`。未来实际准入须对真实选集重新封依赖锁，不能用这些研究SHA代执行包。
