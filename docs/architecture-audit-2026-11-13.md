# 游戏模块、功能边界与 Godot 实践审计

状态：静态审计记录，非开发规格及正式验收；日期：2026-11-13；维护角色：主代理。适用：本工作区当前源码的架构排查和后续需求评审；各发行物以其冻结源与实际服务台账为准。

2026-11-14后续：负责人要求架构整改优先、实现前系统评审；执行入口为[评审流程](architecture-review.md)、[模块边界](module-boundaries.md)和[整改台账](architecture-remediation.md)。下文保留原审计事实与当时建议，当前顺序以新台账为准，不再据“继续性能归因”自动启动旧测试。此更新不将静态风险升级为已修复。

## 结论与范围

项目具备按玩法目录拆分、无场景战斗模拟、权威服务和收据等基础；主要问题集中在保存失败边界、跨玩法全局事务、场景控制器职责、规则多份实现和资产挂点。M06 当前试玩模拟器场景已测帧预算不达标，不能把其他结构问题推断为性能根因。审计的首要动作是验证保存失败风险和保持正在进行的性能归因，再针对实际修改需求分块治理，而非全盘重写。

本记录逐一映射 M00–M24，并按主要运行路径抽查场景、GDScript、服务端、规格与已签证据；**不是每个文件、每个功能场景、每条 RPC 和每个规格 scenario 的穷尽逐行审计**。表中“未发现”仅指抽查内容，“待核”不是合规。静态检查不产生产品测试通过结论；未启动服务、模拟器、数据库或迁移。后续正式测试由 test_lead 按 [测试索引](testing/README.md) 选择并记录新数据、来源和资源终态。

工作树无可用 Git HEAD（文件显示为未跟踪），因此本记录不能以 commit 锁源。关键工作树 SHA-256：`game/expedition/expedition.gd` 21accc5ce60111730545acc5ee0648fd5c5ca65ac46f6989a5f7ff775776f999；`game/battle/simulation.gd` 93f81b2d5b8cd3130056745d38a66eb64f164baadb0391f0fdb1f21edbb80738；`services/profile/server.py` c88f75eb8c86856fecf13a5ee55b3aafca991df54cd643e9cf1461f968b0b82f。其余链接表示审计时路径，后续须按实际源码重新锁定。

当前交付是 [1077 客户端及 1076-delivery-r2 后端](current-playable-delivery.md)，客户端冻结清单和服务运行来源分别登记；不能把工作树发现直接归结为该 APK/服务的已复现故障。路线名称参照 [M00–M24 研发步骤](https://chatgpt.com/space/page_4a8d0df5d3f481919df4dc6f25058920)，当前进度参照[研发总览](https://chatgpt.com/space/page_c894f922bf588191bf36f9527b7e1016)，历史签收只适用于原记录的版本和断言。

### 判定方式

- **已证实结构事实**：可直接由所列源码、数据或既有原始测试报告支持；风险及修复收益仍需验证。
- **待验证风险**：代码路径存在，但尚未注入故障、复现或比较完整契约；不是已确认玩家缺陷。
- **规格缺口**：对照生效 SHALL 的具体要求，现有静态材料不足以证明，或代码存在与要求冲突的具体路径；不得仅凭建议性设计稿宣称违规。
- P0：已证实的广泛数据损失/安全事故或当前节点不可接受的性能阻塞；P1：直接影响存档、结算、授权或当前关键链路的高风险；P2：可扩展性和维护风险；P3：局部改进。P1/P2 是排查和整改顺序，不是断言故障已发生。

## Godot 4.6 调研基准

1. [场景组织](https://docs.godotengine.org/en/4.6/tutorials/best_practices/scene_organization.html)：场景尽可能自包含，外部依赖由上层提供；信号向外报告事件，兄弟节点关系由共同上层协调；节点树按生命周期组织。
2. [Autoload 与普通节点](https://docs.godotengine.org/en/4.6/tutorials/best_practices/autoloads_versus_regular_nodes.html)：全局生命周期与全局访问确有必要时使用 Autoload；普通场景、静态函数和 Resource 可以承担局部共享。Autoload 数量、绝对路径本身不自动构成违规。
3. [Resources](https://docs.godotengine.org/en/4.6/tutorials/scripting/resources.html)：Resource 用于数据且加载时通常共享；实例可变状态必须有明确隔离。使用常量/JSON 而非自定义 Resource 不自动违反 Godot 实践，关键是权威来源与可编辑性。
4. [高级多人网络](https://docs.godotengine.org/en/4.6/tutorials/networking/high_level_multiplayer.html)：明确服务器权威、RPC 权限和传输模式，考虑 UDP 的丢包/乱序及通道。`any_peer` 自身不是漏洞，关键在每条 RPC 的授权、参数与重放校验。
5. [性能测量](https://docs.godotengine.org/en/4.6/tutorials/performance/general_optimization.html)：先在目标场景和平台测量，区分 CPU、GPU、同步和系统开销；优化后比较同条件效果，不能从脚本大小或节点数量直接推断瓶颈。
6. [项目组织](https://docs.godotengine.org/en/4.6/tutorials/best_practices/project_organization.html)：资源尽量靠近使用它的场景，按功能组织；不存在所有工程都必须采用的唯一目录树。

项目生效约束以 [engineering-baseline](../openspec/specs/engineering-baseline/spec.md) 和各领域规格为准。[M00 设计](../openspec/changes/archive/2026-11-08-m00-godot-network-baseline/design.md)标注讨论稿，其中依赖注入、Resource 和网络节奏是设计参照，不全部等同生效 SHALL；其历史测试分工已由当前协作规则更新。

## 问题与整改顺序

### A01｜P1：单人指令保存结果被忽略，确认与持久化边界不一致

**证据与事实。** [solo.gd `_order`](../game/net/solo.gd#L176) 在 `mission.order` 成功后调用 `_save(mission)`，但不检查布尔结果，随后发送 `_full` 或 `_ack`；[_save](../game/net/solo.gd#L192) 明确会在打开、写入或重命名失败时返回 false。对照 [party.gd](../game/net/party.gd#L145) 在发布状态前检查 `_save_before_publish`。单人正常帧处理另有保存失败分支，不改变上述指令路径事实。

**风险／边界。** 文件系统写失败后客户端可能收到确认，而重启恢复的检查点不包含该指令。具体可见后果取决于指令、随后的成功保存和故障时机；本轮未做故障注入，不能宣称已复现丢失或违反所有续接场景。涉及 [单人探索规格](../openspec/specs/solo-expedition/spec.md)的权威恢复。

**建议与验收。** 先冻结触发条件、单人及派生玩法的期望提交语义；在独立新卷对打开/写入/重命名失败、指令确认、恢复同一场景和终局去重分别注入，检查原始状态及回执。再决定暂停发布、恢复重试或其他方案，不直接照搬组队实现。正式测试与资源清理由 test_lead 执行。

### A02｜P0：当前 M06 帧预算未达，根因尚待定位

[当前三席运行](testing/runs/2026-11-13-m23-service-bundle-r2.md)记录整场 P95 77.455 ms、满编交火 P95 80.811 ms，对照 33.333 ms 预算不通过；[当前交付](current-playable-delivery.md)限定了模拟器、实际版本和无实体设备证据。P0 指当前 M06 性能出口未达，不推定游戏整体不可玩。[native profile 任务](../openspec/changes/m06-current-release-native-profile/tasks.md)仍在进行，采样门的失败和未完成须保留。

原审计建议继续同构建采样与独立审查；负责人后续要求架构整改优先，当前暂不启动新采样轮，恢复须按[整改台账](architecture-remediation.md)与独立运行门定案。不要因本报告的脚本大小、抽象或节点结构直接改变渲染、场景或规则，也不要用模拟器结果代表 ARM 真机、热状态或人手操作。

### A03｜P1：大多数档案请求隐式推进多个领域并取得写事务

[server.handle](../services/profile/server.py#L218) 为个别读接口建立只读快照；对其后的多数请求，[统一事务](../services/profile/server.py#L226)依次运行服务记录、维修、组队、探索、营地、好友、秘宝、袭击的过期或到期处理。随后才鉴权并路由（另有明确例外）。[transaction](../services/profile/server.py#L46) 使用 `BEGIN IMMEDIATE`。这使无关功能的错误、工作量或锁竞争可能影响其他请求；源码不能单独证明当前发生超时或死锁。

梳理每次推进的领域所有权、排序依赖与原子性，例如生产/袭击的先后；只在有实际收益的领域将到期处理限制为必要范围或交专门调度。新库验证并发、故障回滚、余额、离线进度、拒绝请求后的到期语义；不要为抽象整齐而跨事务移动账务。

### A04｜P1：多套战斗执行与定义存在规则漂移风险

[Godot 战斗模拟](../game/battle/simulation.gd#L3)读取 [Godot catalog](../game/loadout/catalog.gd#L3)；[秘宝权威模拟](../services/profile/treasure_combat.py#L1)使用 [服务端 workshop](../services/profile/workshop.py#L11) 加载的 JSON；[私人袭击](../services/profile/raids.py#L95)又使用另一套模拟。各玩法允许有明确差异，重复实现本身不证明结果错误。静态上共有装配、维修、干扰等概念，当前逐项语义是否应相同、数据是否一致和生产构建是否一致尚未完成对照。

建立玩法规则矩阵：标注同名能力的共同不变量、故意差异、数值权威与版本；优先比较底盘/槽位/武器/维修/干扰的交集及拒绝行为。可为权威数据建立机器可核对的契约或生成流程，不强迫跨语言共享运行时，也不抹平玩法差异。用代表性边界样例验证双方及部署版本，防止引用同一实现的镜像测试。

### A05｜P1：秘宝大厅读失败后仍可能发出排队写请求

[treasure.gd `_request`/`_response`](../game/treasure/treasure.gd#L87) 在读取进行中缓存一个写请求；读取返回失败时设置错误提示，随后仍执行排队写入。排队体在点击时固定，可能基于旧队伍视图。服务端 [treasure.confirm](../services/profile/treasure.py#L218) 对双方阵容有版本验证；这可缓解部分过期操作，不能仅凭此认定所有排队操作均安全或已出现错误结算。

核对每一种排队操作及单人/双人服务器前置条件；在 GET 超时、成员变动、退出页面及延迟回调下用新场次验证不会未经有效确认执行不合时宜的操作。优先考虑成功刷新后重新核意图，或明确提示玩家重试；尊重已确认的现有交互规格。

### A06｜P2：探索基类承担界面、请求恢复、状态机与战斗视图

[expedition.gd](../game/expedition/expedition.gd#L43) 同时管理信号、HTTP、前后台/读取恢复、编队、战斗输入和视图；[factory](../game/factory/outing.gd#L1)、[pump](../game/pump/outing.gd#L1)、[armory](../game/armory/outing.gd#L1) 继承并覆盖请求或展示逻辑。超类的行为变更影响多个玩法，测试和子场景单独运行成本随之上升；并非行数超标即缺陷。

先记录各玩法确实共用的请求语义和差异，再按大厅状态、编队、战场表现提取少量有生命周期的组件，父场景协调。保留恢复、指令、回执语义，按受影响活动及 Android 生命周期独立回归。

### A07｜P2：场景依赖全局网络节点及父节点结构

[project.godot](../game/project.godot#L14) 装载 Room/Solo/Party/Camp/Treasure；[探索](../game/expedition/expedition.gd#L45)、[营地](../game/camp/camp.gd#L40)、[秘宝](../game/treasure/treasure.gd#L46) 按绝对路径取得网络节点，[基地](../game/base/base.gd#L178)还负责启动其他场景。全局传输跨场景存活可能是合理要求；具体耦合是子场景自己寻找全局对象而非其使用了 Autoload。

在改动这些场景时由上层提供明确的会话/入口依赖并以信号汇报退出；确认断线、切场与重连的生命周期后再改变所有权。不主张删除所有 Autoload。

### A08｜P2：机器人组合依赖具体模型内部节点与跨模型复制

生效 [工程规格](../openspec/specs/engineering-baseline/spec.md)要求可独立预览的宿主与模块及重导后的身份和安装姿态。[robot.gd](../game/assets/steam_crawler/robot.gd#L60)按底盘切模型、递归查找模型内节点及定制偏移；[双足装配](../game/assets/steam_biped/assembly.gd#L17)从履带模型复制部件并依赖命名。当前资产可以正常工作，但静态代码不能证明兼容重导或模块独立预览普遍满足规格；也不能据此宣称现有资产损坏。

按下次实际资产迭代建立宿主/挂点/模块包装的明确契约，保留现有消费版本；用不对称样板、独立预览、替换兼容部件及重导前后姿态/身份验证，缺失挂点给清晰配置错误。无需一次重做所有美术。

### A09｜P2：公共数据和实例状态边界应明确，当前有正面实例

[unit.gd](../game/battle/unit.gd#L10)为单位创建独立 `StandardMaterial3D`，并在 [setup](../game/battle/unit.gd#L49)复制队伍材质；这是避免实例间颜色联动的正确模式。[robot.gd](../game/assets/steam_crawler/robot.gd#L173)引用共享材质作为覆盖，静态未见其在此处修改共享材质本身。后续若修改共享 Mesh、Material 或 Animation 的属性，应核实资源缓存与实例隔离；目前没有证据证明发生串色，P2 为规则和评审缺口，不是已证缺陷。

### A10｜P2：服务端模块名已拆分，但领域依赖与路由编排集中

[server.py](../services/profile/server.py#L258)直接分派多个领域路由并拼装跨领域响应；[inventory.apply_stock](../services/profile/inventory.py#L67)调用生产更新，[production](../services/profile/production.py)和 [raids](../services/profile/raids.py)又互相参与时间推进，[private_base](../services/profile/private_base.py)与设施、袭击交叉引用。这些依赖部分体现真实经济规则；问题是调用顺序、事务所有者及允许的跨领域修改尚未在统一边界表中明确，修改时难以判断影响面。

先绘制账户、库存、生产、设施、出征、战果的所有权和同事务不变量，按一次真实变更提炼领域入口；不要将 SQL 调用机械包成泛化 Repository 或打破必要原子性。

### A11｜P2：界面请求、取消与未知写结果处理多处独立实现

[工坊](../game/owned/workshop.gd#L151)保存操作号并处理未知结果；[好友](../game/friends/friends.gd#L60)替换取消的 HTTPRequest；[基地](../game/base/base.gd#L246)、[世界地图](../game/world/world.gd#L53)、[营地](../game/camp/camp.gd#L88)各自编排请求。实现各有业务原因，但相同的请求生命周期、旧回调和未知写入语义很难整体复核；并不能据此断言每处都有缺陷。

先为各操作列出只读/写入、取消、超时、幂等键、凭据变更及页面退出语义；仅提炼已证相同的传输与生命周期机制，业务收据校验保留在领域层。复用现有各变更证据须核候选、依赖和断言。

### A12｜P2：发行包范围和公开部署的安全边界需要独立核验

[导出预设](../game/export_presets.cfg#L8)使用 `all_resources`，排除测试、服务端场景和部分预览；这只能证明配置文本，不能证明生成包内没有其他调试资源或服务脚本。[正式端点示例](../deploy/runtime_endpoints.example.cfg)使用 HTTPS，[端点校验](../game/client/endpoints.gd#L99)同时接受 HTTP，当前试玩明确仅为本机模拟器。没有证据表明当前私测边界外暴露或发生泄露。

公开发布前检查实际 APK/PCK 内容、诊断入口、凭据、传输与服务暴露策略；独立评审生产环境是否必须拒绝明文 HTTP，而不要破坏已授权的本机试玩配置。网络认证和安全审计需要单独范围与实测，不能由此报告认证通过。

## M00–M24 逐项边界登记

“已抽查”指检查下列代表路径而非整个模块通过；`→` 为需重点追踪的边界。问题编号指适用项，不表示该模块的其他功能都通过。

| 模块 | 代码/设计入口与边界 | 静态判读及后续证据 |
|---|---|---|
| M00 工程基线 | [工程规格](../openspec/specs/engineering-baseline/spec.md)、[project.godot](../game/project.godot) | 场景组合与权威结算有生效要求；设计稿部分为建议。A07/A08；逐项重导和结算不可由静态阅读签收。 |
| M01 工程骨架 | [range](../game/client/range.gd)、[端点](../game/client/endpoints.gd) | 桌面及 Android 入口不同，配置/全局生命周期需按实际导出核对；A07/A12。 |
| M02 资产样板 | [机器人](../game/assets/steam_crawler/robot.gd)、[双足装配](../game/assets/steam_biped/assembly.gd) | 有视觉包装和部件组装，仍依赖内部名称与硬编码适配；A08。 |
| M03 数据与装配 | [规则](../game/loadout/rules.gd)、[客户端目录](../game/loadout/catalog.gd)、[服务目录](../services/profile/workshop.py) | 有接口、容量校验；跨端数据权威与同步待核，A04。 |
| M04 战斗与指挥 | [模拟](../game/battle/simulation.gd)、[战斗表现](../game/battle/unit.gd)、[音效](../game/audio/battle_audio.gd) | 规则与表现有实质分离、信号和独立材质；模拟内多能力聚集，按实际需求评估 A04/A09，不按文件长度裁定。 |
| M05 联机权威房间 | [room](../game/net/room.gd)、[result outbox](../game/net/result_outbox.gd)、[账本](../services/profile/inventory.py) | 有 sender/目标校验、可靠和有序不可靠通道、结果队列与唯一业务键；未穷举所有 RPC、重放/失败路径，A12。 |
| M06 移动性能 | [实测记录](testing/runs/2026-11-13-m23-service-bundle-r2.md)、[活动任务](../openspec/changes/m06-current-release-native-profile/tasks.md) | 预算未达，继续同构建定位，A02；实体和热状态未验。 |
| M07 账号身份 | [account_access](../services/profile/account_access.py)、[beta entry](../game/beta/entry.gd) | 账号恢复和认证由服务处理；客户端入口同时管理认证、引导与页面。安全性与设备恢复未全面测试，关联 A11/A12。 |
| M08 背包结算 | [inventory](../services/profile/inventory.py)、[service_record](../services/profile/service_record.py) | 数据库有收据唯一键和待出征约束；原子性依赖调用事务，A03/A10；未独立验证所有玩法的重复结算。 |
| M09 工坊制造 | [workshop UI](../game/owned/workshop.gd)、[服务工坊](../services/profile/workshop.py) | 有持久意图号和确认逻辑；控制器承担多类业务，A04/A11。实际未知写入必须以同业务号和收据验证。 |
| M10 档案累计 | [service_record](../services/profile/service_record.py)、[profile UI](../game/profile/profile.gd) | 服务记录和战后结算连接；应核所有战斗来源对三项累计的语义和归属，A04/A10；未逐项复验。 |
| M11 私人基地 | [private_base](../services/profile/private_base.py)、[base UI](../game/base/base.gd) | 布局检查与呈现分离；基地页也负责导航/HTTP，领域与生产/袭击交叉，A07/A10/A11。 |
| M12 生产研究 | [production](../services/profile/production.py)、[inventory](../services/profile/inventory.py#L67) | 库存变化先推进产线是明确时序；需守住离线、容量和袭击时序，A03/A10。 |
| M13 维修恢复 | [recovery](../services/profile/recovery.py)、[repair bay](../game/base/repair_bay.gd) | 有报价和恢复业务入口；全局请求推进与库存相互影响，A03/A10，账目故障场景待测。 |
| M14 单人探索 | [solo mission](../game/net/solo_mission.gd)、[solo transport](../game/net/solo.gd)、[expedition service](../services/profile/expedition.py) | 有模拟、网络与业务服务分层，但指令确认保存路径有 A01；UI/派生活动 A06。 |
| M15 组队探索 | [party transport](../game/net/party.gd)、[party mission](../game/net/party_mission.gd)、[party service](../services/profile/party.py) | 保存前检查作为正向例子；继承 solo 和探索页面，行为变更横跨玩法，A06/A11；真实网络证据不可由源码代替。 |
| M16 野生袭击 | [raids service](../services/profile/raids.py)、[raid watch](../game/raids/raid_watch.gd) | 服务自行生成及推进袭击，视图负责复杂状态解析；与基地、生产、维修紧耦合，A03/A04/A10。 |
| M17 新手和日常 | [onboarding service](../services/profile/onboarding.py)、[guide](../game/onboarding/guide.gd)、[entry](../game/beta/entry.gd) | 引导跨探索、基地、制造读取状态；检查结果来自权威事实而非 UI 状态，入口职责关联 A11。 |
| M18 世界日程 | [world_calendar](../services/profile/world_calendar.py)、[world UI](../game/world/world.gd) | 服务维护日程、准入和归属，客户端展示与导航；服务器时间、UTC 边界需原始用例，A10/A11。 |
| M19 营地攻防 | [camp service](../services/profile/camp.py)、[camp transport](../game/net/camp.gd)、[camp UI](../game/camp/camp.gd) | 依赖世界归属、好友援助和装配；检查保存/费用/争议结果与所有权，A03/A07/A10。 |
| M20 好友援助 | [friends service](../services/profile/friends.py)、[friends UI](../game/friends/friends.gd) | 社交、援军与跨玩法占用互相依赖；请求取消有独立处理，A10/A11；授权与并发互斥未穷举。 |
| M21 外观模拟商店 | [storefront](../services/profile/storefront.py)、[store UI](../game/store/store.gd) | 服务维护权益和槽位，客户端存在待确认请求；A10/A11/A12。当前模拟支付不能推断真实支付合规。 |
| M22 经济和运维 | [operations](../services/profile/operations.py)、[交付与维护](current-playable-delivery.md) | 有角色化运营入口和资源台账；实际补偿授权、权限和运行配置独立于源码静态审计，A03/A10/A12。 |
| M23 安卓内测 | [导出预设](../game/export_presets.cfg)、[交付版本](current-playable-delivery.md)、[beta entry](../game/beta/entry.gd) | 1077 源、签名包和 r2 后端分别锁定；当前仅模拟器范围，生命周期和包内容须按候选实证，A02/A11/A12。 |
| M24 秘宝 | [treasure service](../services/profile/treasure.py)、[combat](../services/profile/treasure_combat.py)、[客户端](../game/treasure/treasure.gd) | 秘宝由 Python 权威推进，Godot 负责转发/视图；存在大厅排队写的 A05 和跨模拟规则的 A04；不把旧版签收当当前全面覆盖。 |

## 已有合理抽象与应保留的边界

- [battle/simulation.gd](../game/battle/simulation.gd) 是 `RefCounted` 而非绑定画面的 Node，战斗表现由 [unit.gd](../game/battle/unit.gd) 消费状态；网络目录有可复用的 mission 类。这支持规则、网络和视觉分层，但不自动证明所有玩法一致。
- [inventory.py](../services/profile/inventory.py#L23)用唯一键、签名和事务内账本抵御重复操作；[result_outbox](../game/net/result_outbox.gd)保留待交付结果。不要用纯客户端确认替代服务端账目。
- [party.gd](../game/net/party.gd#L84)显式处理持久化失败，作为需比较语义的正面参考；不意味着单人可以未经验证直接复制该实现。
- 功能目录、信号和独立 `.tscn` 符合 Godot 项目组织方向；避免引入通用事件总线、过度层级、强制统一所有玩法或为了使用 Resource 而转换所有数据。

## 后续落地及验收门

1. **先登记事实**：进度代理引用本报告，按已确认的当前节点、玩家风险和依赖进行需求评审；本报告本身不创建实现授权、不改已有签收。A01/A05先明确复现范围；A02已有change保留原失败/未验，不因本报告自动续跑，当前顺序见[整改台账](architecture-remediation.md)。
2. **再建独立 change**：获确认的实现按 [协作规则](../AGENTS.md) 建 OpenSpec，标明模块、范围、依赖、验收场景及待决问题；将 A01/A05 的假设变成可观察断言。禁止附带旧库迁移。
3. **按风险测试**：故障恢复使用本轮生成的新数据和独立卷；规则用无界面，账目/权限/幂等用真实服务，Android 生命周期和渲染用对应平台。测试代理提交选集、版本、原始证据及清理结果，主代理独立签收。
4. **更新结论**：发现新问题在原记录下注明源码/构建及证据，区别修复、自测、正式验收和实际试玩版本；本报告不是规范替代品。

## 未完成的审计工作

要达到“全模块深度审计、完整问题清单”，仍需：逐条将所有生效规格 scenario 对应生产入口和当前版本证据；逐条审所有跨服务 RPC/HTTP 的认证、授权、数据校验、幂等及故障恢复；逐玩法核模拟规则共享与有意差异；逐场景检查资源生命周期和平台输入；核真实构建内容与依赖版本，并由 test_lead 独立选择适用测试。报告已覆盖全部模块的代表入口和发现，但未完成以上穷尽工作，不应被视为全模块合规证明或完整缺陷清单。
