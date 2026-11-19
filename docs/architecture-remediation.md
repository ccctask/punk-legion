# 架构整改台账与阶段出口

状态：当前研发主干；2026-11-17；维护：主代理，进度代理同步资料空间，test_lead维护独立验证。事实来源：[2026-11-13审计](architecture-audit-2026-11-13.md)。实施依据：[评审门](architecture-review.md)、[模块表](module-boundaries.md)。完整可玩游戏目标已恢复，架构整改优先级保持；本页不表示全部问题已修复。

当前本轮出口（2026-11-17）：[root最终交付签收](../openspec/changes/m23-architecture-release-integration/verification/root-final-delivery-result-review.md)已闭环“界面/联机→性能→完整可玩本机安卓模拟器内测交付”，M23本change6/6，当前1082原签名客户端+ACK1/R2六业务服务由root accepted接管；安装维护见[当前交付](current-playable-delivery.md)。1077旧索引仅history、旧r2/health已退役。M04本change7/7、M06当前5/5、M15本change4/4不是全部模块或全部A01–A12风险关闭；既有有限例外/审计事实仍按下文保留。真实代表场双P95通过但长帧/未知因果保，10.0.2.2仅同机模拟器、真机需另端点包；真机/听感交付后负责人终验未执行。相关change已验收、路径待归档收口，活动QA依赖暂保原位，例外owner=root，下次入口维护或真正归档复审，不伪称已归档；后续想法回候选池，不自动开新研发。

## 阶段与恢复条件

| 阶段 | 当前工作与出口 | 状态 |
|---|---|---|
| G0 评审准入 | 规则/模板/模块定位、反例及A01/A05试用经独立文档审查与主代理签收，入口互链 | 已限定签收/5项完成并归档；[根签](../openspec/changes/archive/2026-11-14-m00-architecture-review-gate/verification/root-review.md)、[治理任务](../openspec/changes/archive/2026-11-14-m00-architecture-review-gate/tasks.md) |
| G1 提交与操作意图 | A01检查点/终局/确认合同及失败恢复；A05新鲜视图与意图有效性，失败/离页不发幽灵写 | 已源码限定签收：A05[6/6归档](../openspec/changes/archive/2026-11-14-m24-lobby-intent-boundary/verification/root-review.md)，A01[8/8归档](../openspec/changes/archive/2026-11-14-m14-solo-commit-boundary/verification/root-review.md)，含真实文件/账务/ENet、实际双进程及保存未完成换席补证；两项均未进1077 |
| G2 领域与规则合同 | A03/A10列明状态/事务所有者、推进顺序和允许入口；A04建能力共同不变量/有意差异矩阵，并按具体缺口实施可核验的契约或边界修订 | [维护应用入口提案](../openspec/changes/archive/2026-11-14-m07-profile-maintenance-boundary/proposal.md)/[设计复审](../openspec/changes/archive/2026-11-14-m07-profile-maintenance-boundary/design.md)与[6/6任务](../openspec/changes/archive/2026-11-14-m07-profile-maintenance-boundary/tasks.md)已备；源码合同及独立五例已[根签](../openspec/changes/archive/2026-11-14-m07-profile-maintenance-boundary/verification/root-review.md)，6/6已归档；纯守恒重构skip_specs，不代表A03扫描/锁或A10领域环已解决；A04[目录合同提案](../openspec/changes/archive/2026-11-14-m03-catalog-contract-check/proposal.md)6/6已签收归档；实际目录/四例及控制通过，[当前动作补证](../openspec/changes/archive/2026-11-14-m04-current-action-contract/tasks.md)两端五组已[限定根签](../openspec/changes/archive/2026-11-14-m04-current-action-contract/verification/root-review.md)，GD/Python移动pending各修原入口，无新字段/抽象；G2已按下文限定出口签收，准进入G3评审 |
| G3 场景组合切片 | A06/A07/A11选择一个真实高耦合流程，拆清大厅/编队/战场/请求生命周期及组合根，独立场景和离页/恢复合同验收后再推广 | [探索组合切片](../openspec/changes/archive/2026-11-14-m14-expedition-scene-composition/tasks.md)7/7，最终AR已签，[a3六组已限定根签](../openspec/changes/archive/2026-11-14-m14-expedition-scene-composition/verification/root-review.md)，已归档并签归档静审、未集成1077/r2；不按脚本行数搬目录 |
| G4 资产与发行门 | A08挂点/包装重导合同、A09资源隔离、A12实际包内容/暴露与权限核验；按资产修改/发行触发执行 | 本轮实际包/玩家链/有效性能及稳定交付已[root最终签收](../openspec/changes/m23-architecture-release-integration/verification/root-final-delivery-result-review.md)，当前1082+R2；非全部资产或A08/A09/A12风险关闭。以下原只读观察属当时历史，未触及资产风险仍保留： [发行只读输入](../build/architecture-review/g4-delivery-input.md)已交：实际1077仍含旧net/probe、低面资产未标game_ready；仅事实/门建议，实际验证未完成 |

当前不派无关新功能。恢复功能扩张前，G0/G1需签收，G2/G3需完成当前受影响边界的整改出口；A01–A12均须有明确归属、状态和处理依据。未触及的结构风险可登记有限历史例外，但必须有约束、负责人及复审触发点，不能将“延后”写成“修复”。相关资产/发行门仍在触发时验证。阶段出口可按新证据细化，主代理记录理由，不能为了推进百分比缩减必要合同。

### 历史整合前阻塞（2026-11-15，当前以本页最新出口为准）

[M14站点整改](../openspec/changes/archive/2026-11-15-m14-rail-objective-clearance/tasks.md)本change已5/5完成规格同步并归档，见[永久归档根签](../openspec/changes/archive/2026-11-15-m14-rail-objective-clearance/verification/root-archive-review.md)（非整个M14模块/完整版通过；门柱任务1.3已获[源码限定签收](../openspec/changes/archive/2026-11-15-m14-rail-objective-clearance/verification/root-exit-post-source-review.md)，原3/4为新增门柱项前的范围）：真实六图曾暴露机体叠合，须由[M04共享移动](../openspec/changes/m04-unit-movement-clearance/tasks.md)修正后重验，不能靠标签或隐藏模型代签。精度末段真实开火及M1–M6规则/恢复/几何已[a6限定签收](../openspec/changes/m04-unit-movement-clearance/verification/root-rules-a6-result-review.md)：该9baf/b74源的24机步进中位41.345ms、峰值61.474ms。[单扫描a8](../openspec/changes/m04-unit-movement-clearance/verification/root-rules-a8-result-review.md)支持保留当前8162/b74，1/6/12机规划13.505/82.680/208.706ms、非计时结果等值和五固定边界例通过；12机末步246.922ms、整体808.761ms仍有风险，不推定普遍净收益或最终性能。a5退化边表已撤回，a7仅工具解析失败且游戏未运行。首批[Solo真实ENet](../openspec/changes/m04-unit-movement-clearance/verification/root-network-solo-a3-result-review.md)已限定签，其余宿主/UI未覆盖。正常三站/COVER及Party限定签收见下；本轮六图及[SOLO_FUEL/COVER_ARRIVAL](../openspec/changes/m04-unit-movement-clearance/verification/root-exit-post-natural-b1-result-review.md)已签，继续Room/Armory/真实UI与完整边界，才进入新源候选整合。它是已发现的共享正确性/成本阻塞，不是扩充玩法。M04当前2/7（选中信息与3.3已签），1077/r2不变，旧1078产物不得当这些新源通过；M06原平台帧预算和完整玩家链出口保留。

正常动态路线已有新证据：[自然A](../openspec/changes/m04-unit-movement-clearance/verification/root-natural-a1-result-review.md)限定通过两Solo分支覆盖三站战斗/到达/采集；[自然B](../openspec/changes/m04-unit-movement-clearance/verification/root-natural-b1-result-review.md)限定通过普通双owner一站两锁和固定COVER绕行/首伤害/arrival恢复等值。均非整局胜利，急修未触发；[Party N a1](../openspec/changes/m04-unit-movement-clearance/verification/root-network-party-a1-result-review.md)另签标准活动完整限定通过，Pump同步marker读取工具失败/部分完成，Factory未运行；原错与清理保留，读取工具和明确剩余活动选择正在修订，不是已证产品故障。后续[Party a2](../openspec/changes/m04-unit-movement-clearance/verification/root-network-party-a2-result-review.md)已用新数据完整通过Pump/Factory限定矩阵；52次读取成功不追认a1根因。[C1](../openspec/changes/m04-unit-movement-clearance/verification/root-consumer-c1-a1-result-review.md)另签资格/占位与原出生近战至真实死亡、同实例负控。[C2–C6十组](../openspec/changes/m04-unit-movement-clearance/verification/root-consumer-c2-c6-result-review.md)已限定签收正常战术、合成受阻取消、Factory自动follow及Camp角色/固定炮台命令，五批30个Job全清；不签炮台实弹伤害。Camp已获[a2两场限定根签](../openspec/changes/m04-unit-movement-clearance/verification/root-network-camp-a2-result-review.md)，原a1工具前置失败保留；真实normal tick发布RAM ACK高于旧盘已有样本，M19耐久/RPO语义仍待独立评审，不授例外。原六图已获[V a3采证/清理签](../openspec/changes/archive/2026-11-15-m14-rail-objective-clearance/verification/root-readability-v-a3-result-review.md)，同落点改善但标题/吊架仍遮机体信息；已按[M04选中信息补审](../openspec/changes/m04-unit-movement-clearance/verification/root-selected-information-development-review.md)只派Unit.gd现有信息层与Sites三标题高度实现，两源已获[V a4实际信息项签收](../openspec/changes/archive/2026-11-15-m14-rail-objective-clearance/verification/root-readability-v-a4-result-review.md)，M04新增项2.2通过后为1/7；M14当时仅scrap-multi后排身体未通过；已证底盘/锅炉侵入Exit实体门柱，按[门柱实现补审](../openspec/changes/archive/2026-11-15-m14-rail-objective-clearance/verification/root-exit-post-development-review.md)正式派单文件Sites物理足迹修复，门洞/4m/模型/采证条件保持，接受真实路线及LOS变化。任务1.3实现已获[源码限定签收](../openspec/changes/archive/2026-11-15-m14-rail-objective-clearance/verification/root-exit-post-source-review.md)；现[POST](../openspec/changes/archive/2026-11-15-m14-rail-objective-clearance/verification/root-exit-post-a1-result-review.md)、[新地图正常Scrap/Party](../openspec/changes/m04-unit-movement-clearance/verification/root-exit-post-natural-a1-result-review.md)及[V a5六图](../openspec/changes/archive/2026-11-15-m14-rail-objective-clearance/verification/root-readability-v-a5-result-review.md)均限定签收，原Rust03主体遮挡解除；562输入/437stage/六PNG已核，Job及SDK/5037/两key元数据终态全清，无运行实例留存。M14本change5/5已同步规格并归档，见[永久归档根签](../openspec/changes/archive/2026-11-15-m14-rail-objective-clearance/verification/root-archive-review.md)，不新增玩法、不代完整版交付。[当前地图Fuel/COVER补证](../openspec/changes/m04-unit-movement-clearance/verification/root-exit-post-natural-b1-result-review.md)已签任务3.3，M04当前2/7；四批资源均清理，不重跑已签Scrap/Party/六图；Armory三工具已获[限定源码签收](../openspec/changes/m04-unit-movement-clearance/verification/root-armory-network-tool-source-review.md)，[Armory a1真实结果](../openspec/changes/m04-unit-movement-clearance/verification/root-network-armory-a1-result-review.md)已限定验收派生选择/route/保存反馈及savefalse分离，548输入/36stage/8Job/UDP24618全清；不签自然终局/UI。Room N-core正待root精确工具评审，未实现；Room/UI仅只读提案，完整边界及最终性能出口保持。

## 全部审计项登记

| 项 | 主责/关联模块 | 当前事实/风险与下一具体合同 | 状态/出口 |
|---|---|---|---|
| A01 | M14；M05/M07/M08，实际继承涉M15/M19 | 保存失败保同RAM/原期限且暂停推进及受影响发布；原终局优先、冲突停车及迟鉴权合同已按范围修复 | [8/8总签归档](../openspec/changes/archive/2026-11-14-m14-solo-commit-boundary/verification/root-review.md)，[10场景覆盖](../openspec/changes/archive/2026-11-14-m14-solo-commit-boundary/verification/root-coverage.md)；原工具失败及组合证据限制保留，资源已清；未进入1077 |
| A02 | M06/M23；M01前置 | 原模拟器整场/满编P95 77.455/80.811ms不达33.333ms；无新CPU样本，旧采样准备失败保留 | 仍未达；[M06任务](../openspec/changes/m06-current-release-native-profile/tasks.md)保normal-a5真实连接失败；M01既有诊断a2已[限定签实际33480/协议就绪/返回未认证表单与资源闭环](../openspec/changes/m01-startup-connection-observation/verification/root-run-a2-result-review.md)，不签旧间歇错误治愈或空日志无ERROR。仅恢复M06 a6正常场文件准备，实际采样另门；不盲改产品参数 |
| A03 | M07–M08/M11–M16/M18–M20/M24，M22 | 多数请求先独立提交全域维护，再在第二笔BEGIN IMMEDIATE鉴权/执行业务；拒绝不回滚前段，经济时间有重入排序 | [只读边界评审](../build/architecture-review/a03-a10-readonly.md)及[三请求切片](../build/architecture-review/a03-g2-slice-input.md)已交：跨域占用/结果与arrival摘要依赖已核，不能按路由名删维护；G2[维护应用切片](../openspec/changes/archive/2026-11-14-m07-profile-maintenance-boundary/tasks.md)6/6归档，五例一次通过/资源已清，源码守恒合同已根签，不称扫描/锁成本或领域环已解决 |
| A04 | M03/M04/M16/M24 | 多份定义/模拟；先建立装配、武器、维修、干扰等共同不变量/差异及数据权威 | [只读规则矩阵](../build/architecture-review/a04-readonly.md)已交：实际Godot/JSON的4底盘12部件一致及四可比样例已验证；执行量化/空间/平台气炮保有限历史差异，不能混称同效；[目录合同规划](../openspec/changes/archive/2026-11-14-m03-catalog-contract-check/tasks.md)6/6已签收归档，实际目录/四例工程合同已[根签](../openspec/changes/archive/2026-11-14-m03-catalog-contract-check/verification/root-review.md)，[能力依据矩阵](../build/architecture-review/a04-capability-evidence-input.md)已交；[当前动作补证](../openspec/changes/archive/2026-11-14-m04-current-action-contract/tasks.md)两端五组已[限定根签](../openspec/changes/archive/2026-11-14-m04-current-action-contract/verification/root-review.md)，真实移动pending/恢复/有效配对/武器职责通过、原失败保留，全阶段出口仍待核；当前不改平台数值或强迫运行时合并 |
| A05 | M24；M05/M15关联 | GET失败后仍可排队写；逐create/select/confirm/cancel与单/双人确认定意图有效性 | [6/6源码合同签收](../openspec/changes/archive/2026-11-14-m24-lobby-intent-boundary/verification/root-review.md)：15项场景/HTTP＋真实新库1连续case/150断言/7POST/11RO快照通过，原工具失败保留，资源/凭据已清；已归档，1077尚未包含 |
| A06 | M14/M15，派生探索 | 探索基类混合界面/HTTP/恢复/战场；先定一条纵向组合切片及父类变更影响 | G3[只读切片输入](../build/architecture-review/g3-composition-slice-input.md)已交，复用现有子场景；[组合切片AR](../openspec/changes/archive/2026-11-14-m14-expedition-scene-composition/design.md)三源与a3六组已限定根签，未集成试玩，不按长度判缺陷 |
| A07 | M01/M05/M11/M14/M15/M19/M24 | 显式依赖与会话生命周期；登记保留Autoload理由，组合上层协调 | G3父根注入现有Solo/Party及幂等关闭已获a3六组限定根签；保留Autoload权威，不要求删全部全局 |
| A08 | M02/M03/M06 | 宿主/挂点/模块包装与重导身份/姿态；现消费低面版继续保留 | G4资产触发验收，未证资产损坏 |
| A09 | M02/M04 | 定义与实例材质状态隔离，保留已有独立材质模式 | G4按可变资源修改触发，未证串色 |
| A10 | M07–M24跨领域服务 | 路由编排和领域所有者入口，先明确同事务不变量 | [维护应用合同6/6根签](../openspec/changes/archive/2026-11-14-m07-profile-maintenance-boundary/verification/root-review.md)及归档静态签收已完成；应用持编排、server持事务、领域持规则，保经济环有限例外；不以提函数宣称环消除 |
| A11 | M09/M11/M14/M15/M18–M21/M24 | 请求机制与业务意图/收据分开，核取消、旧回调、未知写 | G3只准宿主局部HTTP失效/关闭生命周期，不提通用HTTP层；A05已局部签收 |
| A12 | M01/M07/M21/M22/M23 | 实际APK/PCK内容、凭据、传输与公开暴露边界 | G4发行前独立核，当前本机HTTP不据此判泄露 |

每项新增实现链接自己的change/评审/测试报告；现审计标“待核”的风险不会因规范落地自动升级成已复现或已修复。G1的A01/A05源码限定完成，G2已有限出口签收；后续新切片仍须各自最终AR及选集准入，其余须按阶段评审定案，不提前派代码。

## 证据和范围管理

### G2限定出口签收（2026-11-14，root）

允许进入G3场景组合整改，仍不恢复无关功能扩张。依据M07维护入口6/6、M03目录合同6/6、M04动作合同8/8的独立验证与主代理签收：维护编排/事务/领域所有者明确，原八域顺序及两次提交被真实新库验证；当前目录与合法装配有可执行差异检查；当前两端自然锁定、移动pending、共享保护、模型恢复、有效施修和武器职责有分模型证据，两个已复现冷却缺陷已修。不是按归档数量自动判阶段通过。

保留边界须继续受限：M07负责人持有全库扫描/写锁成本及经济时间重入历史例外，新增维护参与域、变更事务/到期时效或优化扫描前必须重审完整参与者闭包与到达摘要，不能直接删维护；M03/M04/M16/M24负责人持有步长/空间/平台6与移动9及当前野怪无可干扰动作的有限差异，新武器/平台行为/参数变化触发原目录和对应动作回归，不把历史差异豁免有效维修或共享保护。记录入口分别为已归档M07设计、M03根签及[A04能力矩阵](../build/architecture-review/a04-capability-evidence-input.md)。这些成本/差异未消除，本次不声称性能改善或统一战斗引擎。

G3已按下文完成当前切片独立验收；最终输入见[只读复核](../build/architecture-review/g3-final-review-input.md)。G4仍按资产修改和发行触发，1077/r2仍不包含G1/G2/G3源码修订。整体完成还需对应发行整合及必要验证，不以此出口关闭全部A01–A12。

### G3限定出口签收（2026-11-14，root）

当前探索组合与关闭切片已按[a3六组总签](../openspec/changes/archive/2026-11-14-m14-expedition-scene-composition/verification/root-review.md)满足出口：三个生产脚本显式传入既有会话，缺配置可诊断/返回，closed前失效本页请求/解绑/只释放一次，直接移除与同帧重开安全。真实base/world五入口、三派生与非探索路径均已独立核验；保既有场景/钩子而不添加通用管理器。真实Handler新库证明提交后本地关闭不重复费用/任务；会话观察替身不冒充真实ENet。两次工具失败及其原证据保留，GUT最终零错与资源终态已签。

仍由M14/M15持有大宿主协调、派生_request/_api_path、net._lost和Party专用suggest动态角色扩展，理由与触发见design；新增会话、玩法、第二相同请求消费者或修改状态机时先重新评审。Camp/Treasure自身全局依赖未在本案改造，不能称所有页面已注入。A06/A07/A11的当前切片可进入下一阶段，不等于所有耦合已消除。

**以下为2026-11-15阶段推进历史；其中“当前/下一/待验”仅指当时状态，不覆盖本页2026-11-17最新交付出口。原审计、失败与限制保留。**

下一主干为G4/M23完整新源整合及实际包门、M06已知性能问题的模拟器定位/复验；不派无关功能扩展。1077/r2尚未包含这些修订，不能以源码签收代发行验证。真机检测和声音系统终验按[负责人安排](../AGENTS.md#负责人终验安排)在完整可玩版交付后由负责人进行，不作为当前必须等待的开发阻塞；模拟器/软件必要验收继续。

G4当前以[发行整合change](../openspec/changes/m23-architecture-release-integration/tasks.md)为执行入口（2026-11-15，4/6；不是整款完成比例）。539文件冻结源、1078原签名APK与两个服务镜像已完成[实际产物限定签收](../openspec/changes/m23-architecture-release-integration/verification/root-image-internals-result-review.md)。[原生a3](../openspec/changes/m23-architecture-release-integration/verification/root-native-a3-result-review.md)已核七平台控制、六路隔离及精确清理；系统全屏提示遮挡原图，无遮挡UI与正常玩家链未签。正在按[玩家链系统评审](../openspec/changes/m23-architecture-release-integration/verification/root-player-chain-development-review.md)实现必要测试侧组合，尚未授权正式player运行。M06原P95失败仍有效，当前试玩仍1077/r2；新产物不等于整合通过或部署交付。

2026-11-15后续：M23已进行正常玩家链分场，实际结果沿其tasks原签追溯，前段签收不等于完整出口。受控正常路由A/B进一步证明采集道具可遮机体/HP，已建立[M14采集实体修复](../openspec/changes/archive/2026-11-15-m14-rail-objective-clearance/tasks.md)并签[实现前边界评审](../openspec/changes/archive/2026-11-15-m14-rail-objective-clearance/design.md)。该必要修复仍属G4整合主干：三站共享纯定义、物理占地及局部标签，保留派生地图和原玩法规则；开发与独立验收分门，目前未签功能通过。修订后需新候选，不将1078历史包证据外推新源；M23仍4/6，M06帧预算失败、完整玩家链与交付余项保持，官方1077/r2不变。

用工作树/冻结源SHA及实际版本登记，保留原审计、失败与签收。正确性故障先headless/真实服务的最小选集；触控/渲染不相关时不启动安卓。所有数据从本轮新库/目录/账号生成，禁止旧库迁移。阶段交付包含改动范围复核、正式测试与清理，开发自测不能代签。资料空间只链接本页及具体任务，避免两套互相矛盾的结论。
