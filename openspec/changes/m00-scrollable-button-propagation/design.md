# Design

## Context

动机见[proposal](proposal.md)。权威证据为[M06 a2真实机制根签](../m06-normal-candidate-frame-capture/verification/root-touch-scroll-probe-a2-result-review.md)：原STOP不滚，原非按钮/PASS可滚、拖动不误触，真实短click和checkbox选机保持。此为Windows真实GUI子树证据，Android a3四滑未动已证但没有其运行时hit链，不宣称Android唯一原因已确证。

主责M00输入工程约束；代码归M11 Base、M17 Guide和M15 Party，消费方M06/M23。依据[模块边界](../../../docs/module-boundaries.md)及[架构评审](../../../docs/architecture-review.md)。

## Goals / Non-Goals

只修已复现机制所阻断的当前主干滚动入口。复用Godot原生鼠标/触摸仿真、ScrollContainer的deadzone/惯性/scroll通知及BaseButton的RELEASE行为。静态控件在原场景配置，动态项在其已有创建点配置。

不新增状态机、全局输入监听、handler、递归控件遍历、坐标绕过或生产trace；不改action_mode、Scroll的STOP边界、OptionButton/LineEdit、弹窗、网络/API、选择规则、费用和存档。其他表面保持候选池，不把此change扩成全项目UI重构。

## Decisions

### 精确落位与生命周期

状态：**通过（2026-11-16 root，准以下有限实现）**。用户已明确持续推进并委派开发/测试，本提案不重复索要启动许可；主代理只规划/源审/验收，开发由子代理实现。正式运行仍由专职测试方交准确新包后另门。

| 职责/所有者 | 唯一落位与白名单 | 创建→运行→释放 | 依赖/提交边界 |
|---|---|---|---|
| M11 Base普通操作控件 | `game/base/base.tscn`：EconomyToggle、PlaqueOrders、Explore、WorldMap、Raids、Confirm、Refresh、Freeze、Snapshot、Back（10）各原节点加`mouse_filter=1` | 原PackedScene实例创建/释放，运行由原Scroll处理拖动 | 原base.gd信号/业务入口不动，父Scroll仍阻止UI指针泄露到地图 |
| M17 Guide控件 | `game/onboarding/guide.tscn`：Fold及Content的Go、Recovery、Solo、Party、Return（6），各静态PASS | 原Guide实例配置/信号/销毁，不添连接或处理周期 | chosen及原上层协调不动，短click仍原意图，拖动由Scroll取消press attempt |
| M15合作大厅操作 | `game/party/lobby.tscn`：Invite/Create、Invite/Join、Members/Ready、Launch、Depart、CodeCopy（6），各静态PASS | 继续随真实大厅场景创建/销毁 | 原read_available/disabled/请求意图不动，未就绪不能因PASS获得操作权 |
| M15动态机器人选项 | `game/party/lobby.gd`中`refresh()`的`CheckButton.new()`分支仅加一次`b.mouse_filter=Control.MOUSE_FILTER_PASS` | 已有robot_buttons持有；refresh复用；旧项remove_child+queue_free；换room/owner已有清理 | `_toggle`/selected/quote/ready gate不动，不在每帧或每次刷新重设其他状态 |

四文件22个静态节点和一个动态创建点是完整本轮范围；不改Factory/Armory条件入口、Match/CancelMatch/Stay/Finish、嵌套生产研究/设施维修其他控件或工坊。它们如需后续整改，必须用玩家证据与当前节点关系另审，不能附带批改。

### 状态、失败与组合

指针按压、deadzone与惯性归Godot控件；选机仍归PartyPanel实例；请求和权威/持久状态仍归现用例/服务。没有新可变状态/事务或跨域写。禁用按钮保持禁用，原读取/离页/队伍刷新/销毁仍决定可用性；普通click不等于服务成功，未知写不重发。四处保持独立场景组合，不因同一原生属性抽出新管理器。

备选：只让操作者换到文字区域会绕过按钮机制而留下玩家问题；递归PASS会误改PRESS型OptionButton与弹窗；复制拖动handler会新建输入生命周期。均不采用。原生逐节点属性是所需最小实现。

### 验证与候选承接

开发交四源before/diff/新SHA，必要自测结果与未运行项分明。测试方最小新源选集核真实Base/Guide/Party按钮拖动与短click/选机/disabled门；机制probe的旧源负例依赖仍有效，不机械重跑其工具矩阵。由于新源原按钮已PASS，不能直接运行要求STOP负例的旧probe冒产品通过：测试入口的预期变化/新源绑定须先静审。

源码签收与独立本机结果后，M23冻结新客户端候选、实际APK内容审计，再于新账号/新卷/新场做最小Android真实Base滚动→WorldMap→Coop→选六/Ready，尽量与原三人性能场合并；不连旧数据冒新源通过。服务源/20导入资源未变可按实际依赖复用已签来源；服务镜像是否复用由M23核实际41源而非仅凭UI判断。

新Android场仍保正常三席/30秒集合/300秒、全部global/个人收据/终账及有效SF双P95，不因为本UI修复降低性能门。完整经营/Solo余项按已有路由分场，不重开无关全矩阵；真机/听感交付后负责人终验。

## Risks / Trade-offs

- PASS传播到父节点 → 保原Scroll STOP，不改非滚动菜单或地图输入。
- 拖动误点/选机 → 真实Input链验证drag零意图、普通click同目标一次，保原RELEASE与读门。
- 源修改导致旧负例失效 → 明确旧机制与新产品选集预期，独立报告/根签不混写。
- 桌面对照不足以证明原生 → 新候选另做最小Android入口及原性能场，不提前发布。

## Delivery

没有数据结构变化或迁移任务。新客户端独立数据验收，原1077/r2保持至M23完整出口签收；失败保源/证据并回原开发方，不擅自替换当前试玩。实现超四源、改生命周期或发现需新处理器时先回评审。
