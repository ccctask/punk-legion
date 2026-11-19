# Design / 实现前系统性架构评审

状态：**带约束通过，仅下述产品实现及必要开发自测**。主代理root，2026-11-15。正式测试工具与实际运行需另审选集/资源许可；不从本签推定新APK、容器或模拟器许可。

## Context

主责M14，关联M15/M02/M04/M23。必要性见[proposal](proposal.md)，行为见[delta](specs/solo-expedition/spec.md)。本切片解除探索通行与可读性缺陷，不扩展主干玩法。实际调用与备选见[调查](../../../../build/architecture-review/m04-expedition-feedback-input.md)；受控图仅证明特定正常路由姿态，不冒充Android a3现场坐标。

评审源SHA256（生产修改前）：

| 文件 | SHA256 |
|---|---|
| game/net/solo_mission.gd | 677aab9ba553615948107387826458fec99efd0c100d429647322cf256469a33 |
| game/assets/salvage/yard.gd | 314edc7036fb02b222e96c4dfbd33bf3b348b8e0f6b4a6d77adba0baa77dccb7 |
| game/battle/field.gd | c08359a1f6f0ce4a4048a32ecb35f54e9ec021c63c009c667b7f9cc477be47f4 |
| game/battle/simulation.gd | dcfbf508672c5f5c2cb2f082cc5aed910e630024773a5a23aac86cbe5698c351 |

## Goals / Non-Goals

在地图本身修正实体边界并复用现有Field；三处均须验证能接近、战斗、采集及辨认机器人。当前不增加HUD、全局事件总线、通用导航管理器或碰撞引擎，不重写Simulation/Field/Unit。若可读性仍不通过，退回同切片评审布局差异，不能宣称占地通过即整个体验通过。

## Decisions

### 1. 功能归属、定义与依赖

新增纯定义 `game/expedition/rail_sites.gd`：承载锈轨AREA、原4个ROCKS、六处LOCATIONS/NAMES、三采集实体占地及其视觉配置（目标模型key/尺度/偏移/标签高度）。它不预载Mission、GLB、场景树或网络，不持机体可变状态。返回可变数组/字典时必须副本，消费者不得修改共享定义。

Mission负责权威地图和出生位置，yard负责资源实例、标签显示和释放；两者依赖Sites，不相互调用。`Solo.AREA/ROCKS/LOCATIONS/NAMES`保留别名供现调用者使用；**ROCKS仍仅原四处岩石**，不能混入采集实体，否则Pump会继承不可见障碍。base Solo.create合并原岩石与三站占地传给现有Field。yard按同一Sites位置/配置组装原模型与Label3D，不另维护第二套尺寸/地点常量。

这是实际双消费者共享关卡语义，并隔离服务端与视觉依赖；不为未来所有地图建立框架。渲染节点保留原yard.tscn/Kit组合，不把所有地形改为动态生成系统。

2026-11-15实现前补审（root通过）：`game/pump/field.gd`继承yard并使用继承常量`Mission.ROCKS`。允许yard保留`const Mission := Sites`纯定义兼容别名，自身使用Sites；不得重新预载网络Mission，也不修改Pump文件。该别名只是已有调用合同，不增加第二份定义或隐含站点障碍。

### 2. 实体占地及行为

scrap/fuel/coil各为地点中心减(1,1)开始的3×3整数格。原模型水平半径约0.92–1.14米，占地外边界为中心±1.5米，最近可达格心距中心2米，在既有4米采集范围内。原位置/模型尺度保留；三处标签高度先统一4.0米，exit仍3.0，其余2.55，偏移仍原值。视觉可读性必须实图验证，4.0是候选布局而非已证结论。

现Field.solid同时约束导航与can_see：**接受站点作为实体掩体阻挡射击视线**，不是只改路由终点。所有点地经现command_move/open_cell自然落合法格；不复制寻路算法。原8个敌机初始位置均经同一Field.cell/open_cell合法化，fuel/coil原站内守卫移到最近可走格；后续_spawn只恢复该合法位置的HP，不再另存出生定义。

保留原守卫分组、HP/伤害、阶段、4米检查、奖励、指挥点、时间与维修。现多机formation可能把多个目标偏移投到同一可走格，本次不承诺友军位置唯一、不附带编队重构；仍验证多机可接近并完成原规则。

QA类比：[Factorio官方EntityPrototype collision_box](https://lua-api.factorio.com/latest/prototypes/EntityPrototype.html#collision_box)区分物理占地和显示/选择边界。采用“可见实体有明确通行边界”的原则；本项目3×3、LOS行为和标签候选来自本地图/Field/实际证据，不由类比决定，也不能用类比代实测。

### 3. 继承范围与恢复合同

标准Party.create_party调用动态create，落到Solo base，故获得同一站点占地。Pump/Factory/Armory/Camp各覆盖create且不super，保留自身地图；生产禁止改其文件。新增实例字段rail_layout默认false，只base create置true，不写入检查点、不信任保存数据自报地图标志。

Solo.restore先动态create→核units数量/ID→仅rail_layout实例在**任何saved unit字段set之前**做几何校验，失败返回false。Solo._load及Party._read_party均构造新实例，失败不返回/发布；不改存盘、会话表、ack、重试、账目或终局流程。

rail校验逐个含未激活敌机的unit：字段字典须有pos/movement_goal/route_goal/path/route_index；pos为有限Vector2，其未clamp的round格须界内且非solid；两个goal为Vector2i，精确Sim.UNSET豁免，其余界内非solid；path为PackedVector2Array，所有点有限且未clamp round格界内非solid；route_index为int且0≤index≤path.size。不得用Field.cell的clamp掩盖越界。

合法移动位置允许小数；空path、UNSET、index==size、改令后尚未重算的旧path均合法。不额外要求双goal相等、路径末点等于当前goal、walking对应状态或位置等于格心。不挪动坐标、不open_cell投影保存值、不重算path/index，不为旧格式写适配；同版本新检查点逐字段恢复不变。非法实例可保留create构造态但调用者丢弃，不能声称对任意已发布对象提供原子restore。派生地图保持原restore语义，无新增rail校验。

### 4. 生命周期与提交所有者

Sites静态定义随脚本资源存活，无任务/网络/资源释放责任。Mission实例由现会话宿主创建、配置和驱动step；Field只属于该模拟实例，暂停/恢复/过期/销毁沿现宿主。rail_layout为实例地图身份，不跨场缓存。yard由既有探索宿主组合，_ready按定义实例化局部视觉/labels，set_goals仅改变可见性，父场景释放一并销毁，无后台回调/Autoload或额外计时器。

Mission只决定本场模拟，不发经济写入；指令持久提交仍由Solo/Party现有合同负责，档案服务仍拥有费用/奖励/累计与唯一收据。此切片不引入新失败重试，也不改变未知写语义。

### 5. 允许范围与派单

开发仅允许新增 `game/expedition/rail_sites.gd`及其Godot自动uid，修改 `game/net/solo_mission.gd`、`game/assets/salvage/yard.gd`。必要开发自测优先复用入口；新增自测只准本change verification下的单个局部Godot脚本与说明，调用真实生产类，不建立另一套owner/框架。运行自测前开发代理提交命令、无服务headless资源预算及成功/失败/超时清理方式；本签不授权editor import、ADB、Android、Docker或网络。实现需额外文件/改变合同先回审。

正式测试由test_lead提出工具/选集，root另签，再执行。开发不能勾主验任务。主代理审实际依赖与本签一致后才开放独立执行门。

## Risks / Trade-offs

### V a4后门柱补审

[V a4根签](verification/root-readability-v-a4-result-review.md)与[门柱实体输入](../../../../build/architecture-review/m14-exit-post-footprint-input.md)确认实际遮挡物是Exit_Surface，且Rust03真实底盘/锅炉顶点在后柱闭合实体内；不是仅Scrap标题或纯前景遮挡。root通过[门柱实现补审](verification/root-exit-post-development-review.md)，当前仅准`game/expedition/rail_sites.gd`追加独立门柱足迹。

以LOCATIONS.exit为单一位置源，新增纯函数返回两根柱脚的世界Rect2i，当前为(28,-22,1,2)与(28,-19,1,2)，通过obstacles的实例副本合入。不得把柱体混进三个collection_footprints或ROCKS别名，也不从服务器加载GLB。前柱已在Scrap3×3内，因此净新增solid只有后柱(28,-22)/(28,-21)；门心(28,-20)及沿x门洞仍开放。粗格保守覆盖柱脚与LOS是明确地图规则变化，接受正常规划因此产生不同合法路径/到达位置；原请求/拍摄判据、Fighter位置、模型、4m和阶段规则均不手改。

base Solo/标准Party动态create消费Sites.obstacles，派生地图仍持自己的create与布局，pump只借ROCKS不受波及。现rail restore先新create再校验pos/goals/path，已自动覆盖新柱格，不加格式/版本/迁移或加载时挪位。仅用本轮新数据验合法等值/明确非法拒绝，不导入V a4旧检查点。门柱yaw/尺度/位置日后变更须同时复审物理足迹，不以“视觉调整”豁免。

此补审不重开通用Field/Simulation或M04信息策略，也不授模型淡化/X-ray/转场、机器人传送、任意角度/offset搜索或测试运行。最小几何/恢复、受影响正常Scrap链和原六图由test_lead按实际diff另审工具与运行；旧不变断言明确复用，像素仍需真实身体可辨。

- 掩体可能改变索敌绕行 → 定向验三站LOS、守卫合法出生、正常交战与采集，不以目标距离静态计算代替。
- 标签抬高仍可能遮挡 → 三站正常相机实图与多选场景检查；不隐藏道具换取通过。
- 父类波及其他玩法 → 四种派生地图各用本轮新数据create/checkpoint/restore检查，禁止旧Camp迁移夹具。
- 过度加严缓存关系会破坏续接 → 仅几何与索引校验，上述合法瞬态逐项覆盖。
- 导入器上轮自动启动ADB → 正式测试运行前明确编辑器设置隔离或SDK子进程许可和清理证据，不重复零ADB承诺。

## Verification / 发布边界

通过条件：真实生产逻辑的三站单/多机点地和route、敌机激活、LOS绕行、守卫/4米采集；标准Party控制/锁语义未变；合法新checkpoint逐字段等值续接及非法几何拒绝；四派生地图不受影响；实际正常视角三站机体/名字/HP可辨。按依赖复用无关目录、账目及owner证据，不能把纯逻辑/桌面图说成Android或ENet通过。

产品验收后纳下一独立源快照/APK/服务镜像，原1078仅历史来源，不覆盖原包。M23完整正常/弱网/恢复/胜利/维修及M06帧预算等出口继续独立，官方1077/r2不变。使用本轮新生成数据，无迁移、旧库导入或历史场次重放。真机和听感仍交付完整可玩版后由负责人终验。
