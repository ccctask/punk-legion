# B 权威安全转弯实施前勘查

motion_dev，2026-11-18。**只读事实与接口草案，非实现准入**；后续由 `m04-authoritative-safe-turning` 的 root design/AR 定案。本轮未改代码、测试或参数，未运行引擎/服务/设备。已读 docs 索引、模块边界、架构评审，本 change design/Godot 技术报告/网络出口最终根签，以及 unit-movement-clearance 的初始净空、自动重规划 AR/源审/规则与消费者根签。

## 真实所有者及共同消费者

`battle/simulation.gd` extends RefCounted，`Field` 亦然，没有 Node/继承运动控制器。`Fighter` 持有 pos、last_heading、walking、movement_goal、route_goal、route_requested_goal、next_auto_replan_at、path:PackedVector2Array、route_index。Sim.step 独占权威推进，按完整 side/slot/id 顺序消费距离，_walk_segments/_walk_regions 只存单步并在伤害前清空。

显式 command_move→_plan_group_move→Field.walk_region/region_path，整组成功后才一次提交目标/路径/索引/期限，失败不得改任何单位。自动 _walk/_approach/_separate/guard→_walk_region→_install_walk_path，保留每机每步一次树、0.5sim 相位、pending 不冒不可达、真实 source 一致性。当前 _walk 逐段静态中心线检查，再 safe_fraction（包括真实目标、友敌身体和已接纳扫段）及 escape_improves；只扣实际距离。非盾朝向目前瞬转，盾沿原限速转向；B 不改盾伤害/朝向、最大速度或战斗距离。

生产调用链：

- net/solo.gd → SoloMission.create/restore/step → Sim；ArmoryMission extends SoloMission，覆盖 create/step/checkpoint/restore。
- net/party.gd extends solo.gd，但有独立 PartyMission 工厂、持久化与推进；PartyMission extends SoloMission，create_party 最后调用继承 create，step 在集合完成后 super.step。Pump/Factory extends PartyMission，各覆盖 create/step/restore_party；因此 **在 SoloMission.create 默认启用会漏到普通合作**。
- net/camp.gd → CampMission extends SoloMission，覆盖 create/step/checkpoint/restore。营地地图可镜像并在恢复时核布局。
- net/room.gd → net/exercise.gd 自有 Simulation 实例；battle/battle.gd 本地 Simulation；二者默认地图/原规则。
- net/treasure.gd 桥接 Python treasure_combat，不调用这一 Sim 路径；Python raids 亦不共用该路径树。
- 现游戏测试另直接构造 Sim/Field/Mission（battle/loadout/owned/camp/expedition 等）；新策略应默认 off，不能靠改所有测试夹具模拟兼容。

Field 当前只保存 bounds/grid，构造障碍数组用后即弃；walk_region 已有 query-local exclusion 桶，region_path 返回实际 pos 起点和四邻中心链。AStarGrid.route 不是当前动态实际规划入口。A 阶段新 static segment_has_static_clearance 已按实际矩形中心边界/全半径查询；不应另抄一套矩形算法。

## 必须先解决的静态事实

仅圆角旧中心线不够：.6 半径在相邻障碍格中心只有 .5 米净空；原 NPC (27,-17) 到 scrap footprint 边也只有 .5，fuel/coil 的 open_cell 可能同样只留 .5。新 B 标准场必须把静态全半径纳入规划/提交/推进，并让本轮 create 的非法 NPC 出生点确定性选最近合法点。原点已合法则保持，友军编队/地标不改；动态出生占位沿旧合同，不在 B 顺手编排重排或推人。

Profile public() 才默认返回 location=rustrail；实际 internal/open 只回 deployment/expires，普通 deployment 没有 location，old_armory 才写该字段。因此服务端应由已有实际 Solo Mission 工厂/任务选择显式注入，不能把客户端 active.location 硬套到 internal 数据。未知显式 location 不启新策略。

## 四文件最小可签接口草案

| 文件/职责 | 拟新增或调整的具体接口 | 不承担 |
|---|---|---|
| battle/field.gd | 构造时复制原 obstacles 并保存静态边界；`static_capsule_exclusions(radius)->Array` 生成矩形四边及外框的几何形状，接原桶；`map_segment_clear(a,b,radius)->bool` 委托已有严格 static helper；`nearest_body_cell(wanted,radius)->Vector2i` 返回确定性最近合法格，找不到返回 bounds.end（明确在界外）；`rounded_path(path,radius,exclusions)->PackedVector2Array` 纯值加工，保起终点。 | 不持单位/任务、不改费用/状态机，不引 Manager/NavMesh/Node。 |
| battle/simulation.gd | 实例策略默认 off；`configure_safe_turning(enabled:bool)` 仅创建阶段调用。opt-in 时 `_exclusions` 合入同源静态边界；两路径安装口调用 Field.rounded_path，先得到完整候选再提交；`_walk_segment_clear(u,a,b)` 在原静态检查之外严格证明全半径。 | 不认 rustrail/Profile，不更改旧模式默认行为、0.5sim 节制、目标体/扫段/逃离安全门，不加 velocity。 |
| net/solo_mission.gd | 实例 `safe_turning` 默认 false，`configure_safe_turning(enabled:bool)->bool` 仅 create/restore 前配置；标准 create 将策略传 Sim，按实际身体半径修正本轮非法 NPC 出生点；checkpoint/restore 严格保存/校验策略标识及全部决策 path/index。 | 不由父 create 推断继承实例身份；不把新策略套旧档、不修复旧位置。 |
| net/solo.gd | 新建/加载使用同一个明确工厂选择；仅实际标准 Solo Mission 注入 rail-safe-turn-v1，Armory/Party/Camp 不注。保存身份与创建身份一致，未知/缺策略的标准新版本 checkpoint 拒绝。 | 不改 RPC/发布频率/鉴权/提交前保存合同，无迁移/服务执行许可。 |

Field 内不堆一个大型 planner：`rounded_path` 只协调三个细分纯数值过程——去同向共线、单角二次曲线离散、完整段验证。它们共享同一几何证明且只被此加工入口使用，留为局部小函数；当前无第二个独立调用者，不新建公共导航框架或泛化曲线插件。若实际实现膨胀到独立职责，先回 root 复审，而非按行数自行拆新层。

### 纯曲线候选与上限（按 root 最新方向，数值待具体 AR 锁定）

采用去共线后的合法折线与局部二次 Bezier，不做逐帧追逐前视点。第一门仅删除同向共线中点并严格证明替代连接段；不作任意跨八点裁剪，以减小偏离原动态绕行路线的机会。若之后确需更强可见段裁剪，再按本轮收益与范围复审。

每角取 entry→原 corner→exit 的二次 Bezier 控制点，建议裁剪距离上限 .60m，且各不超过相邻段长度45%，避免两角互侵。实际身体半径来自 Catalog/Sim.stats，与裁剪距离或曲率半径分列，不缩身体半径。二次曲线不是恒定半径圆弧，不宣称固定最小转弯半径；实际权威消费的是其离散折线，更不声称数学连续曲率。采样检查相邻非零弦的角差，建议≤15°且弦长≤.12m，按 n=2/4/8/16 逐级试验，**每角最多16段**，超限保原合法角；接入/接出原直线的角差也检查。折返、极短段或零长度跳过圆角。上述几何界用于防止粗大视觉折角，B 不限制单位每秒速率或承诺 C 的车辆转弯半径。

建议总输出最多1024点（包括所有原端点）：加工即将超限时，返回已证明的原安全折线而不是截断丢终点；若原路径本身超过该上限，明确拒绝本次候选，不能默默截断。root 可在准入中另定最终上限，开发不能观察结果追绿修改。

Field.rounded_path 先证明原路径所有段在严格静态半径与本次 region.exclusions 下合法；每新弦及接入/接出连接同时证明，两端安全不能替代中段证明。动态 exclusions 沿当前规划合同，避免切过原绕行的身体。某角失败→保该合法折线角；连原 B 路径也证明不了→返回空，command_move 整组不提交，自动安装保意图/旧合法前缀及原等待门，绝不退回旧中心线非法路径。每实际消费的短弦再次严格静态证明，大 delta 跨点也逐段检查、动态 safe_fraction/escape 并扣实际距离。

静态 capsule 构造须考虑现 segment_clear 内会减 GEOMETRY_EPS：建议传 radius+2*GEOMETRY_EPS，让该原查询保守而非缩实际半径。矩形内点/外界点由 grid/严格 query 拒绝，所有规划与实际段最后仍过已有 strict helper，不拿宽相/桶命中冒精确证明。

### 检查点与生命周期

Bezier 预离散后直接存既有 Fighter.path/index，无新曲线游标/中途控制器/缓存恢复框架。Sim 实例配置在 create 前由 Mission 提供，Field 几何来自原 Sites 新实例；step 暂停即不推进。路径被新令、focus、重规划、死亡或场次释放时，仍沿既有 owner 路径处理，无第二套运动状态。

标准新版 checkpoint 必须有精确 path_policy="rail-safe-turn-v1"；参数常量由该固定版本定义，未知/缺失/类型不符立即拒绝，不能默认开启或按源码当前值补旧 checkpoint。工厂在 restore 前配置预期策略，restore 比较保存 path_policy与预期一致，create-first 只构造新对象，所有行校验完成前不应用 saved 字段。检查所有 saved pos、有限 PackedVector2Array/path/index/原 goals/deadline，以及实际身体半径下的路径段和当前位置→当前 waypoint 净空。非法数据拒绝该新 Mission，不重排/清洗/回填。

Party/Camp/Armory 等默认 off 的 checkpoint 合同保持原样，不因 B 全局新增必填字段；它们的 create/restore 不注入 B。标准历史无策略档在新标准加载入口明确拒绝，测试从新数据生成同版档，不安排迁移。若 root 希望参数可变或热切策略，则将新增决策配置与严格身份合同另审，本最小接口不提供运行时切换。

### C 仅依赖点

C 后续在相同 Sim/Fighter owner 引入权威速度/转速、制动距离与到达；必须独立签参数和 checkpoint 字段，复用 B 的安全折线与每段 proof、动态 clipping/原距离预算，不用客户端 Tween 滑行。B 的离散方向变化/短弦上限可给 C 曲率限速提供输入；C 若要求真正最小曲率半径必须另审，但 B 本轮不实现加速度、车体漂移或重写盾向。

以上是可签设计建议。严格几何、路径失败原子、全半径出生、同版本恢复、其它消费者 off 与查询成本须后续独立实际测试，不能用这份勘查或 A 的网络平滑证据推通过。
