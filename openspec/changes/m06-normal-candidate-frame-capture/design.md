## 性能准备与UI断言分离（2026-11-16）

按[夹具有限系统评审](verification/root-performance-ready-fixture-development-review.md)，复用a3已过的UI链，性能场仅显式批准本轮新数据正常API加入/Ready并实图确认；默认UI模式不变，不改租期或统计，不给夹具UI通过信用。

## 合作入口观察补充（2026-11-16）

按[合作切页观察系统评审](verification/root-coop-transition-observation-development-review.md)，仅一次Coop提交后等待实际新图，旧页必须同泵站且无输入；复用原三attempt/预算，不能判点击已消费，不能重发或扩成通用导航。产品与Owner不改。

# Design

2026-11-16当前正常候选三席测量接入按[系统评审](verification/root-pump-scenario-integration-development-review.md)实施固定pump_measurement工具组合；当前源已冻结，新包/新镜像与实际运行另门，未提高通过数。

## Context

见proposal及[只读输入附录](../../../build/architecture-review/m06-next-performance-slice-input.md)。r2有效采集链为归档bundle runtime-r2 wrapper→runtime/reuse→full-pump/runtime/capture；统计已有同poll相邻对、Clock、全场global/tail及覆盖合同。不能直接执行这些旧上下文/端点/授权。

## Goals / Non-Goals

为M23新整合候选提供可复核的低频正常游戏测量入口，不再建立独立回放应用。原33.333ms、全场/主要交火覆盖、所有慢帧、真实场次与完整终局保持。无新玩法、动画优化、主循环/GPU/ETW平台、数据迁移或旧回放恢复。

## Decisions

### 实现前AR：2026-11-15 root带约束通过，仅工具实现/静态定向自检

**归属和依赖。** M06采集器拥有外部查询节拍、原始观测、资格及拒绝，不拥有Godot场景、网络会话或业务状态；M23 owner提供本轮不可变APK/源码/端点/设备及任务目录，并消费报告。复用原capture、analyze/Clock、r2 global/tail与既有纯ring思路；不改已签旧文件、不复制改写统计引擎，不引入通用观测管理器。允许本change verification/tools内薄adapter及一个必要纯策略模块/边界自检；实际旧依赖、转换锚点/次数/SHA和最终执行源码须显式留证，不能宽松字符串替换或旧context兜底。

**状态和生命周期。** owner创建独立任务上下文并给真实设备/Surface/路径，collector配置名义start-to-start间隔→窗外平台资格→逐poll观测/守卫→正常终局及tail→离线同守卫复核→保存原件→原owner清理。资格或观测失败先保存已有poll/错误/原因，不另开场或降节拍；取消/超时同样留原始部分。暂停不拼接成连续测量；需重开必须另签新轮。collector只拥有自身Job，不关闭共享设备/服务；主owner负责准确创建身份和终态。

**节拍和ring。** 显式配置单一名义间隔（拟1.5s，实际资格不足必须拒绝，不在同场静默改值）；用monotonic计划下一次查询，命令超期不密集追赶。留实际计划/起止、命令/校准/可见性检查耗时。资格必须保存原始历史槽形状及设备支持最高刷新率依据，不能用当前FPS/当前有效行数/假定60Hz替代。采用保守safe=(records-2)/max_hz*0.9及跨查询current.mono_after-previous.mono_before包络<safe、至少两个actual-present共同值；说明slot语义及解析来源，无法证明就拒绝。

每次正常poll及tail同规则验证；层、模式/容量变化或空/无重叠/包络超界保原件并判无效/部分。运行周期核模式/层的最小策略须在工具报告明确，检查本身计入包络。最高120Hz/128槽的safe0.945s必须拒1.5s，60Hz/128槽safe1.89s仍需实际每对安全，不能只核名义间隔。

**统计合同。** 不补跨poll帧，不删慢帧，不扣估计查询耗时，不因失效缩短全场分母。复用原相邻去重/否定粗对、Clock时钟pad/拒外插、global receipt最大上界及tail支持，整场覆盖至少95%，主要满编交火连续至少4秒/80间隔；原实际边界要求仍生效。保留原raw字段并只加资格/monotonic/守卫证据；离线入口重新计算守卫而非信任在线passed。实际测量有效与性能达标是两结论。

**方案取舍。** 直接改sleep(1.5)无法约束实际间隔且可能绕ring；原0.4秒高频不证明无扰动；旧QA A/B没有ready资格。选正常游戏低频全覆盖，可以评价本轮候选在已声明采集条件下是否达标，不能评价查询因果、零探针帧率或代码优化收益；不回写77.455/80.811ms旧失败。

**准入范围。** 允许原开发代理只读旧原件/工具/当前源，写本change工具与说明、必要QA纯夹具；不启动Godot/ADB/AVD/容器/真实服务/账号/网络采样、不签包。开发必要自检只运行纯解析/策略固定小集合，使用临时独立输出，入口/调用夹具须无迁移；全部子进程若有须受既有OwnedJob及<=30秒边界，资源终态保存。不得执行旧完整工具或重跑游戏矩阵。独立测试、实际设备资格和M23正式场次由test_lead另提具体锁/命令/预算、root另签，不由本AR自动放行。

**验收。** 先静读准确转换/依赖闭包；定向验证有效节拍、命令/附加检查超期、120Hz拒绝、空/少槽/坏行/缺最高模式、少于2共同值、tail/Clock/慢帧保留及在线离线同判断。用实际保全r2原raw只作解析输入、不重投业务战报或生成新游戏数据；原旧raw无新monotonic/资格时必须标不具新守卫资格，不能补造它们。当前工具行为不变部分按实际依赖复用。M23正式场次可以同时提供首次真实平台资格和完整测量，只执行一次获准场次，不为工具资格另造APK/回放。

## Risks / Trade-offs

2026-11-16，a4后正常终局编排按[Route后只读到达观察AR](verification/root-pump-goal-observation-development-review.md)窄修consumer/pure/新交接，Owner/peer/生产/采集与原终局及统计门不变。当前只准测试源码实现，资格与实际1081场另门；不据此宣称性能优化。

- 平台slot/模式解析未知→保源及原文、精确拒绝，不以推测放行。
- 多层旧reuse掩盖最终代码→源/SHA及实际执行文本固化，root/test_lead审变换和context，旧授权不继承。
- 低频仍有扰动→限制透明；不从采样条件变化推因果改善，也不回写旧预算失败。
- 工具工作膨胀→仅薄adapter/纯守卫，缺更多平台能力时回审，不新增trace/replay框架；正式功能整合继续按M23推进。

## 下一实际组合的已核输入（2026-11-15，尚未准开发或运行）

只读复核已确认：本change工具35项及两个增量纯资格可复用；实际新AOSP平台槽语义/最高刷新率/查询包络与正常满编测量仍缺。当前M23 profile+Solo单首机链不能提供该证据，不给它追加SF轮询。既有单key、Move履带、分辨率/渲染器、隐藏Attack轨道、209空叶隔离及刚性合批均已有否定结果；祖先热点不授权再次试同方向，也不据旧平台P95推新平台必失败或收益。

下一最小组合为profile+Party，手机及两个现有headless ENet peer；规模准确为三席各6标准机/12点，共18友军加PumpMission生成的6敌军，analyze满编要求alive=[18,6]，不是24台玩家机或24台同时可见。场景/服务/peer归M23唯一owner，采集器仅持自身查询与证据，不另造资源管理器；资源/租期/数据权限及具体改动仍须下一份完整AR。

可复用来源为m06-full-pump-playtest-readiness/verification/runtime的phase.prepare/lobby/launch和peer.gd/peers.py机制。旧main/common/service/device/flow硬绑定1076、334xx及旧路径/授权，不可直接执行；旧service六卷不照搬。其新库fixture先正常注册/命名，在无探索且各只有一台时，以生产workshop.initial_fit新增五台，属于需明确批准的容量数据生成器，不证明正常制造费用；新实现必须核本轮新CID/schema21/账号归属/事务前后状态，不读旧库或导入旧档。正常制造费用仍由M23真实玩家链单独验证。

当前adapter.analyze需要本轮fixture三owner/机器人、launch.room/before_utc、两peer连续观察与各自真实receipt/received_utc、初终stocks/robots/career/receipts/含room与party_phase的expeditions、完整capture与peer Job、capture-tail全局receipt时刻和whole-raw。checkpoint-copy.json目前仅消费room个人mission映射，不是授权读取或解码.save；旧finalize/read_orders不可机械调用。后续AR应先核正常API/既有peer seq与权威回执能否承担所需事实，缺口另明示，不新增生产trace或二进制解码平台。

本段只记录已核输入供下一评审，不建立新授权、源码进度或性能结论。实际组合排在当前玩家链后，不占用其设备/端口；原33.333ms双P95及有效覆盖出口保持。
# 滚后稳定观察补充决策（2026-11-16）

当前1080 a1实际正常登录和UP滚动成立，滚后原图点击误入，未测性能。仅测试侧按[根系统评审](verification/root-post-scroll-observation-development-review.md)增加一次绑定A/B原图的稳定正认，当前图B授权输入、A仅只读比较。原预算、无迁移、职责与资源清理不变；不是产品修改或下一场运行许可。

## 1082采样配置修订（2026-11-17）

唯一a1实际末对包络1.976026秒超过127槽/最高60Hz的1.875秒安全余量，原1.5秒名义间隔仅剩约.375秒查询余量；80poll查询最大.471956秒。按[单参数系统评审](verification/root-pump1082-cadence-development-review.md)下一候选只在Owner既有上下文参数设1.0秒，不在旧场改变。原ring/next_poll/adapter/在线离线守卫/统计/tail/时间上限均不改，新场实际两poll-ready及全程核验必须成立；采证频率增加50%须明示观测条件，不从此推游戏性能改进。a1原失败不重写，新准确门与fresh operator另行指定。

