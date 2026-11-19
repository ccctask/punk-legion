# Godot 4.6.1 机器人运动技术补充评审

2026-11-18，godot_motion_review。状态：**待root签收的只读技术建议，不是实现准入**。已读docs/README、AGENTS、模块边界、架构评审、原运动研究与design；实际浏览Godot 4.6官方资料并检查当前1084源码。未运行引擎、SDK、ADB、模拟器、Docker、服务或性能测量；未改产品、tasks或specs。

## 1. 结论：已有Godot研究，应进一步落成Godot项目结构

原报告已引用Godot插值与导航资料，但主体仍为分层研究。实施建议固定为现用Godot 4.6.1、GDScript、`.tscn`场景组合、原有服务器权威Sim/Field：客户端以局部运动呈现组件处理网络样本；权威路径与加减速仍归原规则对象。NVIDIA赛车控制和Pure Pursuit只是运动感觉/跟随思路来源，不引入PhysX插件或另一套物理引擎。

这是一套Godot方案，不意味着必须把已有规则搬进CharacterBody3D或NavigationAgent3D。项目是二维平面权威数据配三维呈现：Sim/Field均extends RefCounted，Fighter.pos为Vector2，Unit为Node3D。保留此边界有利于现有headless服务器、同版本检查点及确定的碰撞/费用合同。

## 2. 当前1084实际来源与调用链

基线为已发布1084快照，manifest `4ea595eacfc9452b31d9cdc447e165f5c271e78e20543430f6f119ddbf6c47bd`，542实体。下列17个实际检查文件逐SHA均与该快照相同；不把1084客户端包源等同仍运行的R2后端镜像。

| 关键文件 | SHA256 |
|---|---|
| game/battle/field.gd | b74a2ecac9e2793c379ccdf049e7e20c408b0e8451c2f187c14eeda0dd790757 |
| game/battle/simulation.gd | 6b956894aee08ba564d654e3d7b45252460552ef216b5dea4e38dba292419c01 |
| game/battle/unit.gd | f2523af7f7b3aa1fb72359635b6faa00275c7ae8de74ed601c67b2e5153f69b9 |
| game/battle/unit.tscn | 838bdf762f4dcebed1ba9eb2c409480f40fe4cfa9902805542c063d3f74f8b70 |
| game/expedition/expedition.gd | 289a046b96ad3fcdaa20aa03ce2c059ec57c9a22e36831b45c24dc043a6ae111 |
| game/camp/camp.gd | cae149e4e6f58e8c67fb549676e64573724376167c8b4e75f600778a6a4bdf7b |
| game/treasure/treasure.gd | 13a84da33e7c92bd6b809e6a4c2af7f9a05ab3053ec461a98db9acd0f6b70170 |
| game/assets/steam_crawler/robot.gd | b0f50a4aaecd81865937944d00057b09a033b2550cf32dc8f75801232fcfb1ab |

另核project.godot、net/solo.gd、net/party.gd、net/camp.gd、net/treasure.gd、client/exercise.gd、battle/battle.gd、client/unit_view.gd、deploy/server.godot，完整已签SHA可由1084 manifest查询。

当前Godot调用链与本次判断：

- 服务器net/solo、party、camp的`_physics_process`驱动权威Sim；server.godot明确20TPS。普通快照发布另有0.12/0.15/0.2秒门限，不能当20Hz到包。treasure由Python250ms规则步推进，Godot桥接定期取frame，另属M24。
- Solo `_delta`在seat/id/stage/elapsed与stride检查后更新state并发changed；`_ack`也发changed但未必有新elapsed。因此采样不能把每个changed当新的运动时刻。party继承Solo接收链，factory/pump/armory outing继承expedition页面；改父类必须核这些消费者。
- 当前expedition `_sync`约880行起建立actors/views并更新targets；`_process`约1086行以`delta*16`追最新pos，再调用Unit.sync。camp约636行相同；treasure约405行以`delta*12`追点并用差距判walking。
- Unit.sync在约79行写自身position、约115行直接写Robot朝向。**不能再挂一个独立_process/Tween同时写这些属性**。网络样本组件、宿主派生Fighter及Unit应只有一个最终呈现写入链。
- unit.tscn也被本地battle/battle.gd、client/exercise.gd和battle/tests/orders_comparison.gd使用。网络插值必须显式启用；不能令本地模拟/演练默认增加网络显示延迟。
- robot.gd的set_motion仅在Move/Idle变化时切动画；已有Attack/Death优先与屏外姿态冻结/补时间。第一版优先复用，不加AnimationTree或每帧重播Walk。

## 3. Godot原生能力的采用与不采用

| Godot能力 | 本项目决定建议 | 原因/官方依据 |
|---|---|---|
| `_physics_process`和引擎physics interpolation | 权威规则仍固定步；网络呈现先手动有界采样，不能只打开全局插值开关 | 原生插值连接引擎相邻physics transform；网络到包有另一时间轴。当前页面在_process写显示，直接启用还可能与现逻辑叠加。[插值基础](https://docs.godotengine.org/en/4.6/tutorials/physics/interpolation/physics_interpolation_introduction.html) |
| `Node.physics_interpolation_mode` | 若运动分支采用手动网络插值，显式OFF/避免继承额外插值；不全局改变其它场景 | Godot允许对子场景单独关闭自动插值。[高级插值](https://docs.godotengine.org/en/4.6/tutorials/physics/interpolation/advanced_physics_interpolation.html) |
| `reset_physics_interpolation()` | 只在采用引擎自动插值的对象首次放置/瞬移时按正确顺序使用；不能代替清网络队列 | 原生reset处理引擎前后transform，不清项目的样本缓存。[使用插值](https://docs.godotengine.org/en/4.6/tutorials/physics/interpolation/using_physics_interpolation.html) |
| Vector2.lerp、lerp_angle、rotate_toward、move_toward / Vector2.move_toward | 已知时间端点位置用clamp后的alpha；角度最短弧；后续权威速度/转速使用每秒速率乘delta并有界趋近 | 这些是GDScript内置工具，不自动赋予权威惯性。2D平面朝向用yaw即可，不为此引四元数系统。约180度反向需明确稳定转向策略。[GlobalScope](https://docs.godotengine.org/en/4.6/classes/class_@globalscope.html)、[Vector2](https://docs.godotengine.org/en/4.6/classes/class_vector2.html#class-vector2-method-move-toward) |
| 指数趋近`1-exp(-k*delta)` | 可用于受限的显示朝向/恢复过渡；不把它当网络样本时间插值或惯性状态 | 官方指出`lerp(current,target,k*delta)`仍受帧率影响。现试车台unit_view已有指数方式，可参考公式而非复制试车台控制器。[插值数学](https://docs.godotengine.org/en/4.6/tutorials/math/interpolation.html) |
| AStarGrid2D | 保留已有对象/地图，不用“换成AStar”重复造功能 | Field已创建AStarGrid2D且禁止对角，但真实动态运动主要用自有walk_region/region_path。仅改grid.diagonal_mode不会改变那条四邻搜索链。[AStarGrid2D](https://docs.godotengine.org/en/4.6/classes/class_astargrid2d.html) |
| NavigationAgent3D / NavigationServer3D | 本轮不强迁移；只有独立证明需要NavMesh走廊时再评审 | NavigationAgent并不移动父节点；自身有路径进度、地图同步和避让生命周期。当前地图/检查点/脚本几何没有这些所有者。[NavigationAgents](https://docs.godotengine.org/en/4.6/tutorials/navigation/navigation_using_navigationagents.html) |
| funnel / simplify_path | 只适用于相应导航路径合同，不给现有PackedVector2Array“开一个属性”就完成圆角 | funnel需要导航多边形走廊，仍可能有网格人工转角；它不是机体半径/动态扫段安全保证。[PathQuery参数](https://docs.godotengine.org/en/4.6/classes/class_navigationpathqueryparameters3d.html) |
| VehicleBody3D | 不采用 | 这是带轮/接地力的车辆刚体模型，官方也说明存在已知限制。本项目只借轻惯性，不能让赛车刚体取代已签Sim位置/碰撞权威。[VehicleBody3D](https://docs.godotengine.org/en/4.6/classes/class_vehiclebody3d.html) |

## 4. 建议实现落位：先一个探索消费者，再按共同合同扩展

以下为待root选择和签准的最小候选范围，不是已授权文件清单。

| 职责 | 建议文件/场景 | 为什么应放这里/明确不承担 | 生命周期所有者 |
|---|---|---|---|
| 有界网络pose样本与呈现取样 | 新局部`game/battle/motion_track.gd/.tscn`，作为unit.tscn显式子场景，默认不启用 | 只持时间/pos/heading/walking的派生呈现历史；不读Autoload、发RPC、寻路、判伤害/胜负或保存。三个网络宿主有当前共同样本语义，独立验证价值成立；若首试点不需要三者共用，也可先局部给expedition而不预造全局API | 宿主启用并传入上下文/接受样本，Unit拥有子场景释放；不另建全局Manager |
| 探索接受新样本与上下文门 | expedition/expedition.gd及原场景组合入口 | 它拥有场次、阶段、席位和actor/view创建/清理。读取net已接受的结果，仅拷贝Vector2/布尔等值；不保留会被后续_delta原地更新的row字典引用，不新增权威状态 | 页面_sync入样，_process取样，_continue_party/_release/阶段和席位改变清缓存 |
| 唯一视觉应用、yaw及动画调用 | battle/unit.gd/.tscn；必要时显式新呈现入口或由宿主先派生u再原sync | Unit拥有Robot、位置、朝向/动画适配。必须选定一种唯一写入方案；默认本地消费者仍直接同步，不隐式等待网络样本。不改变角色最大速度、盾减伤或武器冷却 | Unit和宿主协作，模型动画合同不改 |
| 其余网络模式接入 | camp/camp.gd、treasure/treasure.gd | 等探索试点证实共同采样合同后接入；camp炮塔仍固定底座且aim有自己的权威朝向；treasure tick×0.25必须单独适配 | 各模式页面持自己的场次/席位/时钟，不在组件中按页面名分支 |
| 路点几何裁剪与有限前视 | 原battle/field.gd纯几何、simulation.gd路线安装/消费 | Field可检查候选段，Sim有半径/动态身体/原子路径和精确到达；几何函数不能自己改变指令状态。现有Field.segment_clear/safe_fraction优先复用 | Sim安装路径时处理，同步步进消费；不在渲染_process每帧重规划 |
| 轻加减速与急弯限速 | simulation.gd Fighter实例/推进；必要的共享目录参数及实际checkpoint owners | 速度影响到达/接敌，属于权威规则，不用Tween补一个假的滑行。新增会影响后续决策的字段必须进入同版本严格存取；不迁移旧档 | Sim创建/运行/阻挡/停止，场次checkpoint owner保存恢复，退出释放 |

建议第一轮先锁**探索网络呈现**，不同时改全部模式/导航/惯性。样本缓冲取服务elapsed作排序时间，Time.get_ticks_usec作本地单调推进；收到新有效elapsed才入样，身份/阶段变更不拼接两轮。只有在真实测量后确定缓冲时长与上限，不先拍定所有模式同一个100ms。

## 5. 必须明确的成功、暂停、失败和销毁

1. **创建**：网络宿主拿到有效frame后创建Unit并设置首个姿态，缓存从此样本开始；不从原点缓动飞到出生点。本地battle/exercise默认无网络轨迹组件行为。
2. **配置**：上层显式传场次/阶段/席位代次、服务时间、原生坐标、可选已签安全段判定；组件不访问父页面内部NodePath或Autoload。参数是每个运行实例自己的状态。
3. **运行**：每份新快照值拷贝入有界队列，渲染只采样，不自造权威位置。相同elapsed的ACK/重复frame不制造零时长样本。Unit只有一个最终position/yaw写入者，禁叠加Tween/第二个_process。
4. **显示缺后样本/网络停顿**：不无限外推、不用永久lerp掩盖真正服务器停顿；有界保持或按获准策略snap，并保原断线/重连提示。缓冲年龄、饥饿和snap次数可观测。
5. **后台/隐藏/恢复**：停止不必要显示推进；恢复后不要把后台积压样本从旧时间慢放追上，清/重锚到当前已确认frame。M01请求调度/原经济意图合同不变，不把运动恢复顺手变成重发业务。
6. **死亡/出局/终局**：不能为平滑延迟权威死亡或复活机体；终局、teleport、不同stage/mission/seat代次清队列。HP/收费/收据/胜负保持原所有者，不能整份业务state滞后播放。
7. **销毁/再次出征**：原_release/_exit_tree/continue-party与Unit queue_free释放队列和回调；无Timer/后台Autoload遗留。网络晚包先过宿主原身份门，不复活退出页面。

## 6. 不能略过的转角安全缺口

两份稀疏位置之间作线性插值，也可能把真实L形绕柱画成穿柱对角线；lerp_angle/Bezier/funnel都不自动解决该问题。当前普通delta没有完整每step转角历史，不能宣称客户端凭端点便知道安全绕行。

首试点必须由root选清下列之一：只对可证明合法的直段插值，未知转角保守fallback；或由原M05发布可信中间转角/轨迹片段，并按有界合同采样。前者需上层提供和权威同源的纯几何/半径信息，不能复用随意视觉Mesh AABB当碰撞；后者改变快照内容/来源，必须扩到网络所有者并单独评审成本。两者都不允许客户端复制一套寻路和决定“应该到哪里”。

权威阶段的圆角/前视要经原_static_walk_segment、Field.safe_fraction、_escape_improves、机体/目标身体与已接受扫段检查；净空不足则减速/保原折点，不能缩半径、放大射程/出口范围。盾板朝向用于_hit正面减伤，显示平滑必须限制偏差或在该装配保更贴近权威的显示，不能让画面盾向和判定方向长期相反。

## 7. 最小测量与退出条件建议（未运行）

- 一组真实Godot固定步/ENet接受样本的直线和90度绕障对照，记server elapsed、到包monotonic、显示pos/yaw/walking及frame time；区分服务器停步、网络空窗、帧时和低通追赶，不以旧P95断言新连续性。
- 同一确定样本在30/60渲染采样下检查稳态速度波动、停止抖动、角差与额外延迟；加入重复/迟到/短缺样本及场次重置，不只测一个lerp函数。
- 新呈现组件默认关闭时，本地battle/exercise行为保持；探索父场景和factory/pump/armory继承不被新状态门打断。
- 窄门/门柱/钻头近距离、短距反向点选、盾板视向；如果没有安全中间样本，该例要证明保守fallback而非展示漂亮曲线。
- 先headless规则/场景，再必要的Godot debug多窗口，Android只保新增平台风险；不重跑全部玩法，不操作用户手机/R2、不迁移数据。测试框架/脚本若需要新职责，和产品同样先AR。

这些条件未获参数根签、未执行，不报告“已顺滑”、新P95或实际资源收益。当前1084仍是自动同步包，运动实现需主代理根据本报告签具体准入。
