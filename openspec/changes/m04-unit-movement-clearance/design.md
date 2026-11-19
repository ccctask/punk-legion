当前性能实现门（2026-11-16）：[自动重规划系统根审](verification/root-auto-replan-development-review.md)仅准Sim与Solo父checkpoint两生产文件，现路线消费、0.5sim确定性错峰和两决策字段严格恢复；明确覆盖前序“无跨step决策字段/不加timer”的限制。显式指令/身体/战斗参数保持，自动timeline允许改变。200步大图P95/均值≤50ms及实际两窗持续20Hz另验；下列旧候选均已撤销，不叠加。

2026-11-16前序候选：[Field局部紧凑BFS实施评审](verification/root-region-index-development-review.md)当时批准一个候选及两文件工具；实际收益未过、已撤销，历史许可不延续。

2026-11-16性能阶段：[当前M1/M3成本分账工具评审](verification/root-cost-attribution-tool-development-review.md)仅授权现测试工具一文件；暂不改生产，原UI/联机阶段5/7已签。

# Design / 系统性架构评审

2026-11-15剩余原规格补审：[旧回包/真实换场七测试工具职责门](verification/root-stale-feedback-tool-development-review.md)。六页反馈已签后仅补两接收合同原残项，原生产/页面/已签矩阵不重跑；仅开发，源码/正式运行另门。

2026-11-15当前补审：[非Room六页反馈测试工具职责门](verification/root-non-room-ui-tool-development-review.md)。只补既有M04反馈/生命周期证据，六测试文件内开发，原场景/生产/规则不变；源码与正式运行分门，未获实际验收。

状态：**带约束通过下述实现；正式工具及执行另审**。2026-11-15，主代理root。依据[提案](proposal.md)、[规格](specs/squad-battle/spec.md)、[真实移动/算法输入](../../../build/architecture-review/m04-command-arrival-clearance-input.md)、[拒绝/反馈/选集输入](../../../build/architecture-review/m04-movement-failure-and-test-input.md)。不得从本签推定功能通过、构建或运行许可。

## Context / 归属

主责M04，M05拥有传输/席位，M14/M15/M19拥有玩法、鉴权、提交，M02消费呈现，M23整合，M06测量。真实失败见[M14 V a2根签](../archive/2026-11-15-m14-rail-objective-clearance/verification/root-readability-v-a2-result-review.md)。root已独立读六图和状态、Sim.command_move/_walk及六直接调用者、四网络_order/原_ack、Exercise累计seq推断与反馈消费者；两个输入仅用于精确定位，不代源码/实际验收。

Simulation拥有单位选择/半径/战术与目标、path、pos等可变状态，负责规划后提交及step推进。Field拥有静态网格与纯几何查询，不懂id/side/owner、奖励或战术。网络只解释本次领域结果与现提交门，UI只显示真实状态/本次拒绝，不偏移模型掩盖叠合。两者职责已足够，不新增movement manager/Autoload/物理或导航服务器，不按脚本长度拆类。

源基线：Simulation `dcfbf508672c5f5c2cb2f082cc5aed910e630024773a5a23aac86cbe5698c351`、Field `c08359a1f6f0ce4a4048a32ecb35f54e9ec021c63c009c667b7f9cc477be47f4`；M14 Mission `1ff24ca2c37a4caf75b159e10a8c654b71e3f059693ddfeefcb3d02504aa9584`、Sites `db736237ef75a9b14d6ce4903115029456827978026749191380096c61cbafa3`、yard `2595914312339c3e1158b33ba691f76f17d650da905d5428d748509287b175c9`。实现先补所改文件前像/摘要，未知生产漂移先回审。

## Goals / Non-Goals

修命令同落点、经过已到达同伴及敌我接近叠合，保正常移动/追敌、当前射程/伤害/速度与恢复。原六图要逐机可辨，不能改采证时机/停火/隐藏道具追绿。受阻算法有界，可继续指挥；不承诺无侧向空间的单人宽走廊永远能自动交换所有单位，不引入全局最优多智能体求解。无模型/目录/新HUD/经济/存档格式/迁移改动，Python秘宝模型不在本共享Godot路径中，不顺手统一。

## Decisions

### 1. 整组到达规划与无位语义

`command_move`改为bool。保持原直接API筛除不存在/错side/阵亡/重复id的语义，但先得到稳定有效输入顺序，再按有效N排formation；网络上层原严格鉴权照旧，不因底层过滤放宽。终局/非有限或界外目标/空有效组返回false，选入零移速固定单位整组false。

间距仅使用现stats.body_radius（crawler0.6、轻型0.48），形成步长ceil(2*组内最大半径)的整格formation。候选按距本机理想点平方距离、距请求点平方距离、x/y稳定排序；组内新终点及未受令活机身体/进行中move目标都要半径和足距。死机不占空间。本组当前身体/旧目标不是命令规划的硬障碍，允许共同腾挪，实际推进仍守身体规则。

每机一次有限可达查询后从候选取合法目标；明确采用确定性贪心，不承诺找到所有数学上可能的匹配。全组可放置才一次写目标/清旧target/提交所需路径缓存；一台无法放置则全部原目标、target、path/index及原notice保留，仅本次诊断原因可变，不逐机写后回滚。空间失败用固定代码`movement_no_space`，其它无效请求不能复用旧错误；command_move入口先清现last_error，失败准确设置。领域将其映射为本次`no_space`，用户文案“附近无法容纳当前队形，请换个落点”。不声称整张地图全局无解。

### 2. Field几何与自动接近

按输入第5节的walk_region方向实现一次有限四邻域可达树/父链接，临时排除只接受圆/线段等几何值；原默认route/静态grid和can_see保语义。原grid永不为占用写solid，也不靠update重置它；临时树/排除在调用结束释放。避免每个候选重做全图AStar。不允许Field接Fighter/Callable反查业务。

Simulation._approach保原射程/LOS/guard/retreat/standoff含义，优先可达的安全射击/接近点。短武器允许真实小数接近：明确追击目标仅在路径规划中可作为目标例外，实际身体推进仍不得侵入它；不能把1.8米武器强制停在2米整数格心而永远不能攻击。static障碍和LOS没有例外，不改现攻击条件/伤害/冷却。普通move不能把占用的敌中心当可停目标。

### 3. 推进、等待与确定性

step内用固定(side,slot,id)顺序、当前活机体及已接受扫过段处理每段位移，整段而非仅终点验间距；没有额外一方的碰撞豁免。该明确顺序延续当前按side/slot建立的推进，不宣称同时物理解算或无饥饿保证。可用几何解析或固定次数保守求解裁出最大安全前缀，实际走多少才消耗多少move_speed*delta预算/更新heading；不能整段拒绝令本可进入射程的短武器卡死。

若本版本正常出生/本轮合法恢复已有近叠，新段不能恶化任一旧重叠，且需增加至少一个重叠对的分离度；原本足距的对象仍严格足距。允许自然腾挪，不投影/推开停止单位、不挪恢复坐标。小数起点按真实pos接出路径，不强迫退回已被动态占据的round格心；所有新段仍验间距。

每机每step最多一次新可达查询，零安全前缀则不写pos/heading或walking=true，也不能越过未抵达的waypoint；已在原0.005容差内的零长源样本可正常消费，不因此宣称抵达另一个点。已走安全前段不倒退。无路保目标等待，用户可下新合法move/focus，不能递归/while搜索到成功。空path或index==size但未实际抵达不返回“到达”，不得误清movement_goal。Factory自动follow每正常tick最多每escort一次尝试，失败保原资格/目标，不忙循环；现move/focus成功可取消跟随，现退场仍可用，不新增stop协议。

局部占用/扫过段每step返回即释放，命令候选每次返回释放；只现Fighter pos/goals/path等进入checkpoint，无额外持久预约、随机优先级、重试timer。恢复按原值加载，后续同输入/delta与原实例等值。O(N*C*U)命令、坏例O(U²*C)仅有界，不代表性能可接受；开发交查询次数/单步耗时，正式代表24机定向观察及M06最终预算仍独立。

### 4. 领域提交与原因所有者

Solo两move/非战斗route、Pump独立route、Camp move、Exercise move必须在成功附带seq/commanded/issued_orders前处理false；标准Party/Armory/Factory经父类传播，不能遗漏覆盖入口。Factory显式route只父成功才变escorts。无位失败只保本次运动提交，Camp原resolve_deadlines独立到期不回滚。

采用领域的瞬时`last_move_rejection`固定代码（空或no_space），不入checkpoint。**每个order/party_order/command覆盖入口最先清本次代码**，包含Armory/Factory/Party等早退路径；仅确切command_move空间失败设置，防旧错误污染其它false。成功notice用局部值在接受时赋回，no_space不清旧notice/目标缓存。Simulation last_error是本次规划诊断，领域持其对玩家意义，网络不复制规划规则。

### 5. 可靠结果与可读反馈

root核现Solo/Party/Camp失败无回执、Room忽略bool，不能假称已有负ack。保持原成功_ack/full、durable提交和unsaved/pending/terminal门；只对已鉴权、本场、新合法move/route的确定no_space发非致命拒绝。`_save`或未知写失败绝不发拒绝，不据此宣称原状态未变。

允许Solo新增一个authority/reliable `_move_rejected(id, attempt, reason)`，由Party/Camp继承；不借成功_ack推进被拒attempt，不改state.seq。服务端从本次领域错误发限定no_space；客户端只接受当前active场次、最新本地发送attempt、尚未由成功state覆盖的反馈。旧场/旧尝试/重连前迟到消息忽略。本地尝试序号不回退/复用。网络节点持最多3秒的瞬时拒绝反馈和读取方法；新指令、离开/失联/换场/终局清理，原全量快照不不断刷新它；无跨场缓存。

Exercise为消除“拒绝n→Repair n+1使n被累计seq误判成功”，仅新增拒绝通知仍不充分。允许Room新增authority/reliable `_exercise_move_result(id, attempt, accepted, reason)`：对实际接受的move发true，对已资格校验且确定no_space发false，其余非法/陌生请求不扩大反馈。Room发本地move-result信号；client/exercise对pending move只用本场**匹配尝试的准确结果**确认，不能用累计state.seq>=pending确认move。较晚Repair快照先到也不能将被拒move标执行；较旧结果不清新pending。拒绝不生成draw_receipt/“已执行”；其它原动作机制不在此顺手重做。Room握手_denied会脱房，禁止复用它作本次失败。

现有Expedition/Pump/Armory/Factory Hint及Camp Status显示瞬时拒绝，优先于建议/干扰/侧闸提示，连接/终局生命周期提示仍优先；不新建面板或挤占指挥区。Exercise用原Hint及已有请求状态显示，不另造通用反馈框架。注入会话接口的新增反馈读取方法须在组合验证中明确，现替身相应核对，不能靠可选反射吞掉缺依赖。

新增RPC只签同源新客户端/服务，M23实际ENet/来源/打包门检查；本change不顺手更改现协议常量或承担旧客户端兼容，不迁移旧数据。当前1077/r2仍原配套，不能与本修订混接冒通过。

### 6. 精确允许范围、派单与验收

既有生产允许：`game/battle/{simulation.gd,field.gd,battle.gd}`；`game/net/{solo_mission.gd,party_mission.gd,pump_mission.gd,armory_mission.gd,factory_mission.gd,camp_mission.gd,exercise.gd,solo.gd,party.gd,camp.gd,room.gd}`；`game/expedition/expedition.gd`、`game/pump/outing.gd`、`game/armory/outing.gd`、`game/factory/outing.gd`、`game/camp/camp.gd`、`game/client/exercise.gd`。大括号只是文档简写，执行工具必须展开真实路径。每文件仅本职责必要改动，未需要者不为凑清单改动。V a3后仅按下述信息补审新增两个明确文件，不重开其它生产修订；yard、模型、profile服务、收费/库存、JSON目录、既有owner/导出器和旧证据禁止附带修改。

实现可拆共享几何/运动与网络/反馈两开发片；先冻结bool/诊断/API再协调写入，主代理维护提案/规格/任务签收。无正式引擎或资源执行许可；必要开发自测先交最小真实入口/预算，优先与test_lead共享入口而非重复编排。工具新增另签，正式执行由test_lead独立选集/准确锁/root门后进行。

验收至少：1/6/12机障碍/边界/占用、无位全组原子、初始近叠逃离/短射程/追敌越过同伴/停等再指挥/新checkpoint双实例等值、双方/固定炮台/全消费者代表；实际ENet确定拒绝与旧场/迟到/未知保存门，UI真实节点优先级与Exercise n/n+1；原三站正常采集/COVER动态重验及原六图全Mesh逐机判读。静态格式/地图定义/未变owner证据逐断言复用，不重跑无关经济矩阵，不以假信号代ENet或JSON代像素。无位合成夹具与自然正常战斗分别报告。

## QA依据与风险

2026-11-16性能剩余项按[单query几何预计算系统评审](verification/root-prepared-shapes-development-review.md)准有限候选开发；仅Field query局部shape不变量，不重开撤销BFS/边mask、不改Sim或公开几何合同。先源审、独立双序/typed/几何保留门，再实际安卓，不提前签成本或最终性能。

### V a3后的选中信息补审

[V a3实际根签](../archive/2026-11-15-m14-rail-objective-clearance/verification/root-readability-v-a3-result-review.md)与[源码/投影输入](../../../build/architecture-review/m14-v-a3-label-occlusion-input.md)区分了身体叠合、标题投影重合与吊架深度遮挡。root带约束签[最小信息实现门](verification/root-selected-information-development-review.md)：当前只准`game/battle/unit.gd`中的现有OwnedName/Health选中绘制策略，以及`game/expedition/rail_sites.gd`三个采集点label_height；不改Unit.tscn、yard、Mesh/Robot、Field/Simulation、网络或原六图条件。

M04 Unit拥有逐实例信息材质及setup/sync/死亡/释放；Health须与当前共用team_mat的Shot分离，只在setup创建一次独立override，不能每帧复制或修改共享BoxMesh/PAINT。仅存活、可见、选中时使用信息覆盖；取消选择/死亡恢复普通策略，原名字显示资格和HP缩放不变。Health透明pass/禁深度写测试与有限priority、OwnedName文字/描边层次须一起定义，不把旗标本身当渲染通过。Sites纯静态配置仍由M14消费，三站标题高度候选7.0m，按原投影约上移66.7px，给最高后排名字留布局余量；不新建布局管理器或改到达点。

[SC2官方控制指南](https://news.blizzard.com/en-us/article/4552955/game-guide-special-control)支持战术状态可独立显示的交互取舍，不证明其深度实现。[Godot4.6 Label3D](https://docs.godotengine.org/en/4.6/classes/class_label3d.html)与[BaseMaterial3D](https://docs.godotengine.org/en/4.6/classes/class_basematerial3d.html)说明禁深度测试仍依绘制次序；具体策略是本项目判断，必须实际GL画面验证。信息层不会恢复被遮身体像素，原六图身体/名字/HP逐台可辨标准不变，模型仍全部可见。必要源/生命周期验证由test_lead按实际diff选最小集，不机械重跑未变运动/网络/经济矩阵，实际工具与运行门另审。

a4成本仍未达要求。[Field局部边表试验](verification/root-field-edge-mask-review.md)已完成[a5真实差分](verification/root-rules-a5-result-review.md)，行为等价但24机成本退化，已撤回至a4的Sim9baf/Fieldac42；原实施许可不再生效，不能自动重新加入。当前再按实际证据评审单query成本方案，不改变Sim、选择/重规划时机或已确认战斗参数。

当前下一实现仅按[空间候选桶评审](verification/root-field-candidate-buckets-review.md)：保守登记候选引用，实际访问边才调用原精确函数，避免已失败方案的未访问边精算；仍需独立等价/成本运行，不预告收益。

候选桶已由[a6限定签收](verification/root-rules-a6-result-review.md)保留，整体性能仍待。下一仅按[整组规划单扫描评审](verification/root-group-single-scan-review.md)消除确定性选点的全量排序，保同序合法结果与source路径特例；不并改Field/AI。

R a2实测24机单步成本不合格，已按[成本差异评审](verification/root-movement-cost-review.md)批准等价几何减费、严格条件路径复用及本step新绕路安装；只限原Simulation/Field，不放宽身体/射程或减规模。精度v2的M4限定行为已[独立签收](verification/root-rules-a3-result-review.md)，自然流程、全消费者、网络/像素及最终性能仍未签，不能以窄例代整体验收。

[Warcraft III官方指令](https://classic.battle.net/war3/basics/unitcommands.shtml)区分移动与停止后的交战；采用保留正常自动战斗的原则，不为测图改成Hold。[AoE II官方教程](https://www.ageofempires.com/learn-to-play/control-resources-aoe2/)的多选图标/耐久说明支持信息面板的另一职责，但面板不能代世界机体分开，当前不添加它。[Godot4.6 AStarGrid2D](https://docs.godotengine.org/en/4.6/classes/class_astargrid2d.html)提供静态网格路径；本项目动态占用是规则层新增责任，不假定AStar已解决避人。具体半径/原子失败/等待策略是本项目的可复验判断，非类比游戏数值。

主要风险是窄路等待、贪心保守拒绝、每步可达查询成本、短射程/护送受影响与新反馈旧场串扰；以受影响选集及实际帧/流程验证，不预言六图或性能会通过。关键权威/生命周期已定；若实现需要额外持久状态、异步规划、改射程/采集/协议常量或新产品文件，先提交差异复审，再继续相关部分。

### 新地图闭环后的Armory工具落位补审

2026-11-15 root通过[Armory具体工具门](verification/root-armory-network-tool-development-review.md)。这是现有1.2/2.1/3.2合同的派生消费者补证，原proposal/spec行为与生产范围不变；仅准新armory_peer继承现N四个夹具入口及runner/README固定活动集成，复用Solo生命周期/owner/观察器，不造新宿主或反馈替身。保存故障、合成无位及本轮_load分别标识，正式执行另门；Room/UI、性能和其它生产仍不授许可。

### Room N-core工具落位与生命周期补审

2026-11-15 root签[Room核心工具方案](verification/root-room-core-tool-development-review.md)，任务卡回读后才派四工具实现；原proposal/spec的准确反馈行为不变。Room仅内存权威，禁止套Solo存盘ACK；唯一Room Autoload、真实_order及结果只读观察，局部until去掉不适用oracle条件，原owner和三future复用。末尾用B断线宽限下的新连接抑制一次join验证活场未注册sender，维持三引擎，不冒两已注册在线加第三身份。合成无位/恢复、实际结果及模型状态断言与UI/逆序/离席终局分别验，正式执行另门。

### Room核心实证后的真实Exercise UI补审

2026-11-15 root已签[训练UI工具开发门](verification/root-exercise-ui-tool-development-review.md)，原UI任务卡seq310已回读。原proposal/spec的准确回执和生命周期行为不变；仅五个测试工具（两GD、一个无进程所有权的UI专属纯support模块、runner/README），原生产/core/owner不改。三角色同Room Autoload，A以真实current_scene加载原Exercise并经原输入/按钮；三个单消息有界应用门保原RPC来源与一次super，UI双门、旧拒绝与Repair、断线重连及leave/ack返回释放分别验。仅UI预算20/22/27含40替代原只读10秒提案，core与全局预算不变；固定SDK导入合同另签运行，不授开发执行。

UI工具实现前纠正：原单格BOUNDS与固定地面点击不相容，command_move会先判invalid。root复读后改为保原BOUNDS、四Rect仅留0格开放及六pos0，固定点击/产品规则/预算不变；实际no_space及恢复前不step按UI精确根签执行，core原请求0的已签夹具不受影响。
