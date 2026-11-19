# Design

状态：2026-11-14主代理**带约束通过最终AR及a2后最小缺陷修订AR**。早期门保留历史范围，以末段新门为当前允许范围；正式行为执行仍须逐run锁/授权。维护：主代理；准入按[评审模板](../../../../docs/architecture-review.md)。

## Context

必要性见proposal；[既有能力证据](../../../../build/architecture-review/a04-capability-evidence-input.md)与[test_lead最小预选](../../../../build/architecture-review/a04-action-validation-plan-input.md)为当前输入。Godot _jam增加lock截止，Python prepare_weapon/disrupt增加aim截止，旧相位与当前直接相关依赖不同；这不是已复现产品错误。目录/四装配例已另案签收，不代替本案动作行为。

## Goals / Non-Goals

验证各模型自身的自然动作基线、下一动作延后、移动、保护、空闲、同轮恢复及实际施修配对，补当前武器职责依据。比较共同语义，不要求Godot与Python逐帧/首发全等。不重跑账号/制造/地图/营地/HTTP/ENet/安卓/性能或M24三号整场。

## Decisions

### 状态与依赖所有者

M04模拟及M24独立战斗各自持自然锁定/冷却/动作截止、充能、移动与事件；M14持模型checkpoint/restore及combat_reports映射，M10持永久三累计与唯一消费，M03持定义。工具只拥有本轮合成初始状态、观察/报告和有界进程；不写DB/收据/战绩。没有游戏UI场景组合变更，GD精确入口只作SceneTree命令宿主，实际逻辑为生产RefCounted及Python函数。

初步允许新增tests/godot/action_contract/{probe.gd,probe.py,run.py,README.md}和tests/godot README入口，具体实现派单须最终AR确认。复用原jammer_rules/field_repair_rules/compare的真实方法调用组织及既有OwnedJob，保原脚本历史字节；不导入或整跑含HTTP/旧schema的check_*，不新增断言框架/通用模拟器/运行时管理器。生产game/services及发行配置初始禁止改动；若正式发现违反现行合同，保首失败、由root更新AR与允许文件后才修，不能调整预期绕过。

### 精确行为与共同合同

| 组 | 必须观察的真实路径与结果 |
|---|---|
| J1自然锁定 | 相同合法输入的无jam/双jam各自基线，真实step自然建立首次锁定/瞄准；记录原due与首动作，武器/维修各+1秒、单目标保护共享且两个来源仅一次扣费/脉冲。选择一个能区分自然锁定截止的合法装配，不复制18相位。 |
| J2移动pending | 先真实射击及有效维修产生下一冷却，再走正常移动；命中时原两个due仍未来，移动在原due前抵达。位置继续推进，后续实际武器/维修各较自身基线+1，保护不叠加。不能因为armed=false/aim为空就把规范移动pending要求标不适用。 |
| J3空闲及恢复 | 无受修需求时命中，保护/临时惩罚过去后才提供合法受修需求，首个普通可服务tick即执行；Godot按实际Variant检查点、Python按JSON同轮恢复，保原lock/aim、动作due、保护/充能/事件数，平行推进与未恢复分支一致且不重放脉冲。补一个保护到期边界，不升级成真实网络重连。 |
| R1有效输出 | 一次缺血3.25、满足真实触发条件的两施修者争修，仅一份实际恢复/扣充能；生产事件与Mission.combat_reports同actor/target/有效量配对。不声称已永久入账。 |
| W1武器职责 | 当前合法连发/气炮各在3米/4米对相同静止标准目标，真实发射/命中记录；3米连发次数更多且单发更低，4米仅气炮命中。无杀死/回击的测试条件须声明，不改武器定义或换距离求绿。 |

J3用J1/J2本轮状态，R1可复用受修目标；无法安全复用时用独立小型初始fixture，不能为合并案例直接改被测时钟。Godot步长0.05、Python实际STEP0.25按各自基线观测；due应精确+1（浮点容差不超过1e-6），动作落在该模型实际量化tick范围，最多一个自身tick误差，不放大epsilon或强行跨模型同首发。

### 夹具白名单与失败解释

输入从当前Catalog/Rules合法装配与combat.unit/fresh、Sim/Mission.create产生；公开初始ID、部件、位置/目标、初始伤情、逻辑阶段及受控敌方零伤害/固定靶条件。这些是测试状态生成，不是账号持有或实际打过战斗。可用普通动作让发射者首次进射程/命中后离场，不能直接扣充能或改保护来凑一次脉冲。

J2第一枪/维修、移动命中/抵达及下一动作必须有连续真实事件；禁止直接写被测cooldown/last_service/next_shot、lock/aim截止、not_before、protected_until、充能或输出事件来制造通过。J3只使用本轮生产checkpoint与JSON回读，不加载旧档；伤情只用已声明生成步骤，不伪造输出事件。R1确需静态伤情/安静年龄时在原始fixture明示，生产方法决定实际clamp/归属。

每组先判合法装配/几何/真实pending等前置，再看结果，不能见失败后按实现重新定义前置。前置不成立为工具/fixture失败；前置成立而规范断言不满足为产品失败，保原记录并停后续。不能以目录/旧日志绿灯代替当前动作，也不能删移动pending或直接设置期待截止。

### 旧证复用及有限例外

M24真实施修→三累计/公开重复链的26不变业务源及server守恒提取、独立operations非路径变化，按能力输入分列受约束继承，不称今日新HTTP。局部维修helper/映射同源只支撑窄算法依据，不签整个当前网络链。当前新探针只补动作生产者/模型恢复，不重造受控报告入账或战史事件。

平台jammer兼容但当前无对象且已有明示提示，平台6/9与固定步长/空间差异保M03已签有限例外及负责人触发；本案不赋予野怪新动作、不调平衡、不豁免有效施修/延后一次/共享保护/三累计要求。

### 资源与准入

优先无import/旧缓存的最小显式preload闭包，固定Godot4.6.1两exe/Python/所有实际源及11交付保护另锁。正式统一60秒工作、15秒清理/总75，确切GD入口check-only最多15秒、GD逻辑最多20秒、Python最多10秒，均服从公共剩余deadline；一个同时引擎，owner/worker及短命查询分别记账，成功/失败/超时均精确清Job/同创建身份。无HTTP/DB/容器/设备或现行试玩操作。

初始仅准规划。开发必要自检与独立正式执行分门：自检以语法/入口解析、合法fixture构造资格为限，不跑J/R/W完整行为；实际推进及配对结果由test_lead新锁新run执行。精确工具闭包、fixture字段及分组输出身份经最终AR冻结后才派实现；需要import/外资源/额外生产修改时退根审，不临场扩。

## Risks / Trade-offs

- 当前移动分支可能忽略既有冷却：J2保自然来源与原due，不按实现豁免，结果再决定修订。
- 两端模型不同：各自对照/量化范围明确，不以一致目录保证同一轨迹。
- 工具前置错误掩盖产品：声明初始状态/连续事件/分组失败类型，保首错，不自动重试。
- 范围扩张：旧账目窄继承与本轮纯模型结果分开；任何生产修订先root AR，真实网络/安卓另门。

## Delivery

无主规格增量或数据迁移，当前APK1077/后端r2不变。开发、独立正式结果、root签收与实际试玩分别登记；G2全阶段出口由主代理在本案及受约束旧证审完后另定，不按任务数量自动关闭。

## 最终AR签收与实际源核

2026-11-14，主代理：带约束通过1.1。根读当前主规的移动pending、共享保护、空闲与恢复合同及test_lead精确预选，不把“实现未认为armed”改写成规范豁免。自然输入是否同时成立由原始连续记录证明，断言不满足先分类保原，不临场改目标/截止求绿。

根重新核当前simulation=93f81b2d5b8cd3130056745d38a66eb64f164baadb0391f0fdb1f21edbb80738、Field=c08359a1f6f0ce4a4048a32ecb35f54e9ec021c63c009c667b7f9cc477be47f4、Mission=677aab9ba553615948107387826458fec99efd0c100d429647322cf256469a33、treasure_combat=ab95daaac079b888d6278e7aec2b60bd252a103b544b635796f5d608f6498265；GD显式preload闭包仅这三项加Catalog/Rules，无场景/外部资源/全局class依赖，批准最小stage免import/旧缓存方案。

受约束旧证由根独立读M24原case/preterminal/根签并重核28依赖：26项同SHA，仅server/operations变化；server原c88的精确提取及当前正式守恒五例已有M07根签，operations不在原77请求路径。原3.75秒有效施修9、6.75秒末击及终态(1,1,0)/(1,0,9)/(1,0,0)、三份非空digest/snapshot清符合原证。允许沿用该非零真实账目/公开幂等断言，不能称在新Handler重跑；后续若修本案生产须重新审这些断言依赖，不能自动延续。局部Godot维修旧证仅作算法依据，当前producer/恢复由本案补证。

固定允许四文件tests/godot/action_contract/{probe.gd,probe.py,run.py,README.md}及tests/godot/README.md入口；开发证据/资格自检脚本放本change verification/development。原owned/tests及check_*均不改不整跑，生产515集合/源与11交付保护须冻结；docs/testing由test_lead维护。初始fixture可设合法实体/部件、位置、初始伤情/安静年龄、受控敌方零伤害/静止靶与正常移动输入并明确记录，不能改定义或被比较/被延后的目标武器参数；零伤害/静止只适用于不参与该断言的对手控制。J2的冷却/维修等待必须由真实第一动作产生。禁止写被测截止/保护/充能/事件，因实现/装配无法形成夹具时交根审而非删场景。J3必须来自本轮真实checkpoint/JSON，不拼历史头部或回放旧报告。

开发必要自检最多30秒工作+10清理：GD新入口确切check-only、Python静态编译及合法装配/构造资格（若提供fixture-only，必须在任何step/J/R/W推进前返回并标准备），不跑完整行为。使用既有OwnedJob及新目录，保首错/源/原进程终态；不为文档后改重测未变执行源。正式预算按本页60工作/15清理/总75，业务worker硬70给owner最后5秒；实际GD/Python组顺序、不同时多引擎，原分组基线/对照与失败/未运行分别留档。test_lead静审候选与完整执行锁后root另开唯一正式门，目前不批准正式动作或生产修订。

### J3序列化格式澄清

开发静审指出Mission.checkpoint含Vector2/Vector2i/PackedVector2Array；根核solo._save/_load的真实路径为FileAccess.store_var/get_var。故“checkpoint/JSON”按模型分别执行：GD用本轮新临时文件store_var/get_var并显式关文件/核错误，再真实Mission.restore；Python仍JSON回读。不得把GD向量转字符串导致的JSON失败报成产品缺陷，不新增兼容转换/旧格式适配。新检查点文件仅本run证据目录，不触现行spool或数据库，J3动作/恢复断言与预算保持。

### W1定点几何澄清

GD会自动接近射程外目标。为隔离3米/4米武器职责，批准W1双方实例move_speed=0，记录原值/夹具值及实际距离，武器伤害/射程/间隔和定义保持；这不是移动行为验证。该限定优先于前文“静止只作对手控制”的一般描述。J2被测目标不得静止或改速度规避真实移动pending，零伤害控制仍不得用于被比较武器。没有产品或预算变更，不提前运行W1。

### 独立a1后：J2几何修订AR

2026-11-14，root：原[a1审查](verification/root-independent-a1-review.md)为夹具前置失败，未判产品缺陷。批准仅GD setup的moving分支两发射源初始位置改为同一整数Vector2(-7,0)，其余夹具/正常指令/参数/断言不变，Python保持原坐标。GD _nearest以distance>=7排除，原生模型无源间排斥，独立身份/充能不变；整数点避免route首节点取整引入反向行走。默认Python tactics不自动追逐，不能机械照搬GD修订。

静态推导：GD首repair .05、shot .25产生原due6.05/1.25；随后普通移动，.40源-6.46/目标-.54距5.92，既有撤离指令不改变.45的_jam先于_walk顺序；预期目标仍移动且原due未到，.55抵达/.80重锁截止早于1.25。以上是几何依据，实际前置与结果仍由原连续trace/guard判定，不能当成通过证明。无需额外资格轮次；test_lead核最小差异后新锁、新root门执行一次。原a1全部保留，禁止改产品或延后量/容差，后续失败照原分类停。

同次静审发现Python第二源会绕过受保护tech而命中buddy，并非同目标叠加。root与test_lead核disrupt真实选择及几何后补准：仅Python moving分支buddy初始位置由[0,1]改为[0,3]。首正常移动后第二源到buddy为sqrt(5.7²+3²)>6，撤离后距离增加；tech到buddy始终不超过sqrt10<维修范围5，初伤20经首修10仍缺10，满足原下一维修需求。原发射源位置、参数/正常指令及所有结果断言保持。此隔离修订与GD一行一起冻结，不另开资格轮次；静态推导不冒作Python已执行。

## 独立a2后：M04移动冷却缺陷修订AR

2026-11-14，root：带约束通过。[根审](verification/root-independent-a2-review.md)已从连续真实输入确认移动pending失败，不是夹具前置问题。状态所有者仍为M04 Fighter/Sim，调用链仍step→_jam→普通移动/武器；无新依赖、场景、事务、持久字段或组合根。缺陷来自“当刻可瞄准”与“已有未来冷却”混作一个armed条件，修在拥有自然时钟的原模拟入口，不交给UI或网络补偿。

允许原开发代理仅改game/battle/simulation.gd的_jam三处：weapon_due从elapsed+maxf(0,target.cooldown-delta)初始化；armed由该due>elapsed初始化；删除原stationary分支内重复叠加cooldown。保留stationary合法opponent/LOS/range及lock_due的max合并。_jam发生于本tick冷却递减前，故必须保留-delta归一：a2 .45+(.85-.05)=1.25，再延1到2.25；不得延到2.30或重置为1.45。

无未来cooldown且不能瞄准时保持非pending，沿原临时抑制截止，不储存永久惩罚；正常静止锁定、下一动作清weapon_delayed、跨来源保护、维修与事件合同不变。已有事件weapon_pending/原due会自然反映正确状态，不另造日志或战绩。接口/返回/失败/恢复格式不变，不迁移数据。剩余514生产文件及11交付保护必须不变，services/Python仍禁止修改。

开发先保原精确diff/源与a1/a2；只需新stage单入口check-only资格及静态范围自审（30秒工作+10清理、OwnedJob），不重做构造或完整行为自测。test_lead独立锁新515源后按原J1/J2/J3/R1/W1顺序执行、保首错/未运行，预算仍60/70/75；测移动真实原due+1、自然首锁、无闲置银行、checkpoint恢复及维修/武器断言。无需安卓/服务/新框架。若出现不同缺陷，再保原与复审，不能临场改断言或扩文件。

## 独立a3后：M24绝对武器截止修订AR

2026-11-14，root：带约束通过。依据[a3根审](verification/root-independent-a3-review.md)，Python移动清aim后漏认真实next_shot，非GD时钟修订可以替代。允许原实现代理仅改services/profile/treasure_combat.py的disrupt原armed/weapon_due两行：先weapon_due=max(seconds,target['next_shot'])；armed=weapon_due>seconds or bool(target['aim_target'])；仅存在aim_target时再max其aim_due。next_shot由真实fire持有绝对时间，不减STEP、不写next_shot、不纳入失效旧aim_due，不改prepare/fire/移动/维修/保护/事件/字段或配置。

无新模块/抽象；领域模拟持动作判定，HTTP/账目/持久化所有者及接口不变。本次GD候选dcfbf508保持，其他513生产/11交付/工具冻结。开发只做Python内存compile和静态diff/保护检查，不需引擎/构造/行为自测；正式由test_lead新锁新门执行原Python五组，GD五组只在逐依赖不变时沿用a3。后续监督方法先由root核，不为缩短运行新增框架。

旧M24非零账目证据需重新审disrupt修改是否在原无jam case可达；若不能证明依赖隔离，不得继续引用为本次修后已验。原a1/a2/a3及所有未运行范围保留。规格与数值不变，skip_specs仍有效；当前1077/r2不更新，不迁移数据。

root补准test_lead在本change verification新增一次性Python-only监督脚本：复用OwnedJob/identity和现runner的只读verify（无引擎副作用），新锁包含监督脚本；新门后直接运行未改probe.py五组，检查非空完整顺序/remaining/实际imports及源后核，60秒工作/70秒worker/75秒总、行为子进程最多10秒。不得复制行为断言、伪造GD通过或修改通用runner。host预检与所有失败清理照原预算；GD沿a3真实不变证据组合签收，不能把单Python报告命名为全两端通过。监督脚本静审后另门执行，不单独再跑资格。
