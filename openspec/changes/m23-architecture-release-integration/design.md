2026-11-16当前新源性能基线前置：[Godot镜像Sites显式依赖补审](verification/root-current-sites-image-dependency-development-review.md)仅准根Dockerfile一行COPY。旧1078不含本轮M04/M14；新性能候选须重新范围/冻结/产物及实际测量门，不冒正式交付。

# Design

## Context

见[proposal](proposal.md)、[完整任务卡](../../../build/architecture-review/g4-release-task-input.md)及[架构阶段出口](../../../docs/architecture-remediation.md)。本次把既有修复带入发行，不改变其业务合同。主责M23，M07/M04/M14/M24持各自业务语义；M06提供最终性能依赖。root已静读实际Dockerfile、新server的profile_maintenance导入、三个export preset、构建器的preset.1派生与全树probe引用；probe只由自己的测试场景引用，不能把net整目录排除。

## Goals / Non-Goals

完整交付范围复核入口为[进度代理34行出口依据](../../../build/architecture-review/complete-playable-exit-evidence-input.md)，它引用25模块/98路线出口及原五点/23决定矩阵。该输入未发现另一项已确证完全缺实现的必需主玩法，但不是整款通过；最终test_lead须逐断言核历史H/U的依赖继承或补证，root按实际最终候选签收，不能只用本次受改文件测试或归档数推整款完成。真机/声音负责人交付后终验继续单列未执行。

M01既有诊断a2已[限定签本轮有效URL/协议就绪/返回未认证表单及资源闭环](../m01-startup-connection-observation/verification/root-run-a2-result-review.md)，用于恢复M06正常场归因准备；无产品/新包变更，不证明原间歇连接错治愈，空prelog不签无原生ERROR。M06仍无CPU样本、原帧预算失败；本案最终源/包门不因此提前通过。

交付完整可核的新源/新候选，保原签名和玩家菜单，覆盖实际镜像依赖和实际APK内容。当前先批准必要的两个打包配置修订，后续冻结/构建/运行单独门；不为等待性能盲签包。不改玩法、模型、网络协议、数据结构或原维护/战斗实现，不做迁移或旧档回退。

## Decisions

### 实现前架构评审：root带约束通过（2026-11-14，仅1.1范围）

模块归属：Dockerfile定义镜像运行依赖，export preset定义客户端发行资源，构建器消费它们；业务模块不反向依赖发布脚本。缺少COPY应在Dockerfile补齐，不能改server为可选import来掩盖缺依赖；Probe排除应落Android Release preset，不能删除测试源或在运行时判断“发行版不执行”而仍打入包。两项分别属于服务和客户端产物，不抽公共发布管理器，也不混改业务。

允许仅修改`services/profile/Dockerfile`和`game/export_presets.cfg`：前者在现有显式COPY中加入`profile_maintenance.py`，后者仅preset.1的exclude_filter追加确切`net/probe.gd,net/probe.tscn`。保其他过滤、Debug/Windows预设和玩家`beta/diagnostics`/`beta/entry`入口；不排整个net或所有gd。开发交前像、精确diff和必要配置自检，不写镜像实现的测试，不构建/签名/运行。配置含义由test_lead独立静审，实际发行效果等候选验证，分开登记。

本项无新增运行状态/事务。现有发布生命周期为：审源→create-only完整快照→锁定版号/有效构建转换→构建客户端/镜像→独立候选验证→root签收→稳定运行配置接管→核活场/在途→退役旧实例。每阶段失败保原件并停该阶段，不能覆盖旧候选/试玩索引或以临时试包替换当前版本。暂停/恢复按同快照、工具、版号、Job及容器创建身份核定；重建只用本轮新数据，不恢复旧库。临时构建/测试所有者负责成功、失败、超时清理，证据/镜像/命名卷按规则保留。

### 稳定端点配置AR：root通过（2026-11-15，仅1.2源码）

依据[完整源初审](verification/root-full-source-initial-review.md)，root已核当前deploy/private-beta.env六HOST_PORT为251xx，稳定formal.env为333xx，构建器private_network实际消费前者，不会自动纠正。允许开发只把该文件PROFILE/ROOM/SOLO/PARTY/CAMP/TREASURE_HOST_PORT分别设为33380/33371/33372/33373/33374/33376，保其它键和值原字节（包括127.0.0.1绑定），不展示认证内容。

M23发行配置拥有未来正式包与稳定服务的端点合同；业务模块不持端口策略。构建层读版本化env并生成客户端端点，部署层在交接时按稳定配置接管，客户端只消费结果；不能把本次源修订当现服务已切换。独立候选测试端口由其本轮overlay/诊断派生另定，不改正式发行合同。不为六个值引入配置管理器/第二份全局默认。

生命周期为读源配置→冻结→生成有效包配置→独立候选验证→实际交接，各执行门仍分开；本门只修源。出现非六键差异、重复或缺少端口键即返回评审，不顺手修签名/主机/Secrets。保前像和精确差异（输出仅端口键）；开发必要静态自检，test_lead独立审改动及private_network消费闭包，root签源码。六值可逆的小改动不新增镜像实现的测试或运行服务；实际APK有效端点/稳定配置仍由2.2/3.2验。当前1077/r2和所有卷/容器不动。

### 完整来源与依赖（后续门）

2026-11-15执行顺序以[首个整合候选根审](verification/root-final-source-scope-review.md)为准：动画候选已撤销、当前无生产性能方案，先冻结全部已签修复+b0f；正常采集工具独立开发，不无限等待研究。最终功能/性能/稳定交付门仍保留，本轮只有一次create-only冻结获准，APK/镜像/运行另签。

已签11文件清单与根签见任务卡，最终须全树比较而非只认11个路径或沿用515数量。工作树新增/删除/变更都要有获准来源，未审差异停止；profile实际镜像必须包含新维护helper，Godot服务镜像必须包含适用的Solo/Simulation修订，不能只更新APK。业务语义仍引用原根签，不在发布层重新实现。

复用`deploy/build_private_beta.py freeze/build`及固定Godot4.6.1，不新建构建框架。M06范围确定后再锁最终源、按实际issued账本取版号，保包名/证书；不预设1078，不重签或覆盖1077。构建转换后的有效payload、端点和实际服务源都登记，名为同版本不构成一致证明。构建器若缺功能，先交具体缺口复审，不顺手重写。

### 验收与保留例外

#### 同字节正式APK隔离工具AR（2026-11-15 root，仅实现/纯自检）

core及独立纯资格后，新owner的安装/首启分离、真实平台/echo与条件许可按[原生资格小组件AR](verification/root-native-owner-plan.md)准备；仅此小组件源码获准，真实资源仍另签，完整场lease未获准。

实际输入核查后，现PlayStore映像debuggable0且无userdata初始文件，不能按原模板启动。后续独立AOSP映像文件仅按[条件准备门](verification/root-aosp-image-preparation-review.md)处理；测试owner改为显式工厂data及全部新可变路径，按[最小源码AR](verification/root-native-factory-data-source-review.md)实现。原工具纯子门保持历史有效，不能替新源或新平台实测；未满足许可条件不下载，不运行时换映像兜底。

最新[a3限定根签](verification/root-native-a3-result-review.md)已通过平台/六路/清理，HTTP/UI组合因系统全屏模态未签，原断言并入正常玩家链。下一源码按[玩家链系统评审](verification/root-player-chain-development-review.md)及[视觉观察补审](verification/root-player-visual-observation-review.md)实现：唯一资源owner组合独立步骤/局部relay，显式player 1200/1300/1320 scope，计入有限test_lead图义决定时间；不复制整套owner、不重放旧common。Room精确延迟与Party/24机性能分门；当前只源码/必要纯自检获准，实际运行另签。

据[最小计划B](verification/test-artifact-and-route-plan.md)，允许开发在本change verification/route写最薄的专有AVD出站路由工具及必要定向纯自检，复用既有AVD/私有ADB/OwnedJob生命周期。M23测试owner拥有设备/包/独立端口配置与清理；路由器只拥有该设备的专链/跳转/规则，不拥有游戏会话、共享host防火墙、端点策略或业务数据。不得改APK、源、快照、宿主333xx或当前r2，不为隔离新增游戏Autoload/可配置正式端点。

上下文必须显式绑定新正式APK/签者/原字节SHA、快照、唯一设备创建身份/序列号/AVD、真实package UID、本轮独立profile/五UDP目标和许可。包安装后保持force-stopped，规则资格/安装/读回全部成立才可首启；未建立规则不得让它访问旧333xx。六条规则只匹配实际UID、10.0.2.2、协议及精确六dport；先创建唯一空专链、填规则读回，最后挂精确OUTPUT jump，不用范围/全局重定向。已有同名链/未知前像拒绝，不接管。DNAT计数是连接匹配证据，不能当逐包数、游戏指令数或五UDP已通。

状态生命周期：owner提供独占新实例→只读资格→精确有限规则→首启/观测→采证→停app→删自身jump/链并读回→原owner退出设备/私有ADB及echo、独立服务。每步有共同deadline，失败/取消/超时先保部分结果，finally同样执行精确清理；失联保未知，不以设备退出冒删除命令成功。禁止全局flush、全局ADB kill、删卷、改host网络、换镜像/remount/延时反复试绿。未知当前设备/实例不得运行。

权限资格如确需一次adb root，只能在**后续实际执行根签**明确授权本轮私有AVD后使用，工具默认不升级；本实现AR不授权启动设备或adb root。先核ro.debuggable/id/实际iptables nat与owner/DNAT能力；不凭镜像名或Linux手册推Android能力。[iptables官方发行手册](https://man7.org/linux/man-pages/man8/iptables-extensions.8.html)说明owner适用本地产生的OUTPUT/POSTROUTING、DNAT可用于nat OUTPUT，实际Android/SELinux仍待资格。adb redir方向不能替代此机制。

资格正负控制限本轮专用高端口TCP/UDP echo（固定少量包/超时、最多一个fixture与两个监听）；负控用未匹配专用测试端口，禁止把APK发到旧333xx。shell UID echo只证内核路径，真实app UID TCP需新profile的compat日志/实际CID源锁+链计数+正式客户端反馈；五app UDP/ENet/费用结果仅随后功能链证明。不修改响应/加产品测点，不要求为此另造包或五场战斗。需要更多echo监听/不同控制或新抽象先回审。

实现交付含命令构造/输入拒绝/部分失败清理纯自检、准确旧生命周期依赖/SHA/转换、运行计划及首错保存；纯自检<=30秒，无ADB/Godot/容器/真实网络。拟实际300工作+100清理/外420秒仅留后门预算，工具审/实际包镜像完成及精确锁/执行根签前不运行。开发自检不代正式独立资格；test_lead审选集/执行，root审原件签收。

test_lead按差异提出选集及复用理由：实际APK的签名、AXML权限/组件/debuggable、版本/ABI、ZIP和sparse/PCK有效内容及敏感/测试资源边界；必须核probe脚本编译物/重映射也不在有效包，配置文本不算通过。保留玩家诊断菜单和正常网络资源。新profile镜像实际import依赖/进程源、Godot服务镜像源与冻结集合核对，不能用宿主import代镜像检查。

采用本轮新库/新号/新场，按G1–G3影响核模拟器基地→探索进入/关闭/同步重开、必要组队/前后台恢复及权威结果/费用一次账。原纯规则、真实HTTP/ENet、目录、M07五例和M04分模型结果仅按依赖不变逐项复用，不机械重复全矩阵。实际测试命令、夹具/入口无迁移审查、包/镜像锁、资源预算、断言和清理计划仍待test_lead提出及root另签；当前没有测试执行许可。

低面GLB/robot/assembly未改，不重建资产或强跑A08/A09全套；相关未证风险保有限例外，若模型/挂点/可变资源发生实际修改先复审。M06原P95失败不被结构修改抹除，最终候选需有效模拟器帧预算证据。真机与声音终验由负责人在完整可玩版后执行，不代签/不阻塞。

## 当前玩家验收分场决策（2026-11-15）

实际产物出口与native a3平台/隔离子门已签；真实玩家a1/a2及其原失败保留，不能从早期“尚无测试许可”文字推当前状态。[a2限定签收](verification/root-player-chain-a2-result-review.md)取得注册命名RustOne到基地菜单，因测试代理页面标识抄写错在点击前停，资源已清；[页面词汇合同与独立资格](verification/root-player-page-contract-pure-result-review.md)已将规范值由Flow显式传入request，不自动判断图义。

按a2真实capture约3秒/决定12–19秒，原42个经营前置难稳留Solo Start495。以[分场系统评审](verification/root-player-scenario-split-development-review.md)替代“单场连续五段”的编排：management_ui只profile/一新卷，保全部经营UI/负控断言；solo_fixture另新库以正常API四写生成合法两机、真实UI登录后执行完整Solo弱网/重开/唯一账/实际伤情维修，才用两服务/两卷/relay/密钥。不搬数据、不SQL加料，不把夹具当实际制造UI证明或声称同账号连续整链通过。基础维修工位足够，Solo不生成修理站；经营仍真实建/移/供电。

两个mode必填、准确plan/gate与原scope/started/lease绑定，原64/45/8/三次加载等待、1200/1300/1320与Start495保持；本场目标/未覆盖与全局余项分开。当前只准该测试侧源码实现/必要自检，实际运行仍须test_lead精确输入与root独立门；完整M23/性能/接管未通过。当前事实与下一准确门以[tasks](tasks.md)及所链接根签为准。

## Risks / Trade-offs

a3已达同mission恢复，后续因当前图本机/采集前置不可正认停止；[结果与清理](verification/root-solo-fixture-a3-result-review.md)保留。目标模型和正常route落点同址的风险已[只读核查](../../../build/architecture-review/m04-expedition-feedback-input.md)，先按[有限Godot几何对照AR](verification/root-rail-visibility-diagnostic-development-review.md)开发三文件局部诊断，实际引擎另门；不盲开Android或先改导航/规则/HUD。按动作精确化测试前置与玩家反馈属于不同归属，未因本诊断获产品实现授权。

Solo首场止于首张异步读取图，按[结果限定签收](verification/root-solo-fixture-a1-result-review.md)保留原unknown与未运行；后续测试侧按[初次/恢复大厅就绪评审](verification/root-solo-lobby-readiness-development-review.md)及[当前完整步骤异步补审](verification/root-solo-transition-readiness-development-review.md)共享有界观察，不改生产或放宽完整Solo要求。源码、最终源一次组合独立资格和新实际场分门，不逐边界盲开冷场。

- 全源整合带入未批准内容→每文件差异/来源审查，未知差异停止；源签、开发自测、独立测试、发行分开。
- 仅加过滤仍打入重映射或引用依赖→检查实际有效包；失败交原实现方，不靠目录筛选宣称安全。
- 新helper宿主存在但镜像缺失→补显式COPY并验实际镜像；不做静默可选导入。
- 性能修订未确定就反复冻结→现在先配置与选集，最终构建等依赖确定；若确需临时候选须另说明必要性。
- 当前试玩/共享服务被误退役→稳定操作目录持久化，交接前核实际活场/在途/使用方，精确退役不删卷、不全局清理。旧运行标签是历史证据，不当现状。

原两配置AR不构成任意发行权限；冻结/构建的后续实际子门与仍缺的功能/性能/交接结果以tasks逐项根签为准。关键范围变更先更新对应评审，不从历史规划推运行授权。

2026-11-16：经营a1实到工坊但Save屏外，按[页面导航/动作前提系统评审](verification/root-management-viewport-development-review.md)仅整理现Flow及其pure/说明三工具的职责，保真实全部断言/费用、原预算、Owner和生产。已[源码限定签收](verification/root-management-viewport-source-review.md)及[独立9+default1通过](verification/root-management-viewport-independent-result-review.md)，尚不代实际Android滚动/模式/Confirm；新实际门、经营/Solo缺口和最终性能按tasks另签，不逐个按钮盲开冷场。

原玩家链缺失的制造完全同key重放/三基地拒绝/重登资产及五物理负例按[服务缺口最小测试AR](verification/root-service-gaps-development-review.md)只补两个测试入口，当前准源码实现、运行另门，不扩大生产/Android场次。工坊实际三起点诊断后生产修复归独立[M09 change](../m09-workshop-touch-scroll/design.md)，不能沿M00旧范围附改。

## Solo按动作观察合同补审（2026-11-16 root带约束通过）

玩家问题仍为既有Solo正常出击、弱网同场恢复、胜利唯一账及自然维修；不增加玩法。依据[1081最小选集与真实入口对照](verification/current-1081-solo-minimal-test-selection.md)、旧Solo a3根签、M14归档与M04可读性/移动签源。root只读核了当前Flow.battle_frame/solo及生产expedition._objectives/_send、Solo.command/_ack、SoloMission collect分支：当前按钮并不显示数字距离或指定守卫计数，六事实强加每张Route/Repair图不是玩家实际操作前提；enabled不能推near。生产<=4m/指定守卫、进度和账务均保持。

本次抽象留在现有M23测试consumer，不加入游戏、网络传输或资源Owner。只准修改 `verification/player-chain/player_steps.py` 的Solo battle观察/循环及其直接私有helper、`player_steps_pure.py` 的定向模式、`player-steps-source-notes.md` 对应说明三个文件；保前像/精确差异。复用现Flow.observe/act/Ports/evidence与fake Ports，不复制Owner、协议、发布工具、时钟或业务规则。管理/注册/经营、初连与恢复异步、fixture、relay、尾段维修函数及默认非Solo行为不得附改。原源6f1/e635/7e89以当前文件全摘要为准。开发自测仅新合成纯控，不运行设备/服务。

| 职责/边界 | 落位与依据 | 状态与依赖/生命周期 |
|---|---|---|
| 当前图事实按动作使用；不推断服务器位置/HP/守卫 | Flow现battle_frame及私有校验helper；只有业务步骤知道本场首机/阶段和下一动作 | capture/visual提供当前图绑定，Flow记录本场stage/目标/所选首机；与Owner单向组合，不增Ports |
| 命令后有界观察及真实推进分账；不重发未知写 | Flow.solo内局部状态与直接helper；共享一次Solo生命周期和原deadline | 同一mission创建→Route→Collect等待→已知拒绝或推进→终局；离场/异常/截止终止，不跨场缓存 |
| 可复验边界与文档 | 现pure新增选择性入口及notes；无第二框架 | fakes只测真实Flow调用顺序/零动作/硬上限；正式测试另新目录/锁/根门 |

具体合同：

1. 每个行动图仍须当前battle/可指挥、正确stage-goal、可识别且选中的本轮唯一首机与所需可用按钮锚。普通Route不强求HP/四米/守卫事实；HP可明确unknown，但不得据此维修。Repair保原HP<.68、可辨本人当前HP/实际次数>0/按钮正认、最多2次；每张图最多一次游戏命令，维修后必须新图才可发下一动作，不用一次旧票跨结果。
2. 保每stage Route至多一次、原stage0弱网/重开/同mission恢复以及18/28秒的有界被动等待。Collect仅stage0/2/4，当前目标/按钮可用/本人选择正认后允许一次玩家正常尝试，**不记录near或guard_clear真值**。记录发送前Hint、当前目标、源图和尝试数；tap不计collected成功。
3. Collect待回执期间不得再发Route/Collect/Repair覆盖消息。下一新图只可确认实际合法阶段推进，或相对发送前新出现的精确notice：`请先抵达节点四米内`、`节点还在守卫火力下，先集火守卫`。同文旧Hint不等于新ACK；错误/断线/目标矛盾/unknown/无可辨新结果均安全停止，不重发未知写。必须完整保存原提示，不以字符串包含或enabled推成功。stage1/3自然战斗推进与Collect0→1、2→3分开识别；不许跳阶段冒采集。
4. 已确认的far/guard拒绝各每目标至多一次10秒零输入等待，然后由新图决定一次新尝试；每目标最多3次（exit没有guard分支、至多2次）。这只重试**已知未推进的规则拒绝**；重复同类拒绝或同文无法辨新ACK即失败，不自动刷新Route或续票。等待前后均核原loop/Owner截止，无负数或超额wait；不能把这10秒增加到工作窗口。
5. 成功collected只在真实下阶段图确认后登记；exit必须现有canonical win/receipt/唯一delivery及释放、career、报表一致才记成功。保原scrap/coil/exit完整顺序和nodes权威断言，当前Owner无运行时位置/seq读取权限，禁止新读Save、Pump双peer日志、API位置或添产品trace来造视觉事实。
6. 原64票/45秒/8原子、Start>=495、Solo loop<=min(420,remaining−75)、work1200/cleanup绝对1300/outer1320保持。新增收紧Solo battle图<=30，初连/恢复pending亦计入，不冒称原Solo已有该上限；不能为新分支增加64。静态保守59/64仅可行性，不承诺最坏模型往返可成功。30秒自然维修仍在原尾预算，未自然损伤只记未覆盖，禁止造伤/迁移。

待实现边界如需新增状态/入口/权限或无法识别上述准确结果，原方回报root复审，不临场放宽。management1081下一场的64锁会含现Flow；**开发只能在该实际场结束并完成源后核后开始改这三源**，不得与该锁并行漂移。root可先派只读预读/差异草案。实现后由test_lead仅定向验证按动作事实、Repair未知零输入、三种Collect结果与exit无guard、旧同文/错身份/错目标/跳阶段/未知零重发、10秒前后截止/30及64边界、tap不计成功、原弱网与终局尾合同不变；不重跑18/7/旧十组或设备。源签→独立纯资格→Solo全新实际门分开，当前未授权实际Solo场或完整3.1通过。

计数落位补准：Flow.__init__只加默认None的Solo battle观察状态；solo在原deadline创建后激活count/deadline并用finally释放，保summary实际计数。observe仅在该状态激活且请求page为battle时，于原64检查通过、实际requests增加/capture之前核count<30和原deadline并加一；内部pending continue的新图同计。非Solo/其它page不受影响，不包装Ports/capture、不新造通用计数器。初连/恢复pending仍要求本轮全部业务facts为null，原_solo_transition_state逻辑和五事件限额不改；ready后再做按动作校验。canonical receipt的scrap/coil有序nodes新增断言只放solo消费处，不改共有assert_terminal_once或旧default测试。以上为必要直接调用边界的补准，三个允许文件和经营源锁释放条件保持。

## 基地实际预览与独立前置补审（2026-11-16 root带约束通过）

必要性/当前节点：1081 a3的注册/完整工坊已[独立签收](verification/root-management1081-a3-result-review.md)，基地33因操作方定位超时未输入；不重复已通过工坊或以夹具冒制造UI。按[基地只读方案](verification/current-1081-base-preview-test-plan.md)，root核真实base.gd预览/选中路径、Owner当前gate/roles/prepare/guard及Flow.run：界面无预先格坐标、内部ID标签；正常点击后才显示准确预览坐标，power点击可在设施内部。本修订只让测试按真实玩家流程取证，不改产品/相机/格/网络规则或增加玩法。

实现由原Solo开发在其三工具已交付后顺序追加，不能另agent并发改同源。允许文件仅现 `verification/native-qualification/owner_adapter.py`、`check_pure.py`，`verification/player-chain/player_steps.py`、`player_steps_pure.py`、`player-steps-source-notes.md` 五文件；复用solo_fixture.py原四写函数/算法/命名、原Ports/Owner/路由/资源清理，不修改fixture/relay/bind/publisher/生产/发行绑定或增加框架。开发说明与前像/diff保存在本change verification，root审源后测试代理一次最终冻结选集，不在中间源反复验证。

| 新职责/不承担职责 | 精确落位/复用理由 | 状态、依赖与释放 |
|---|---|---|
| 明确base专场权限，不给其它模式前置写或联机能力 | Owner.scope_action/service_roles/validate_plan/player_guard枚举与最小分支；base_fixture须同mode且gate.allow_fresh_base_fixture is True | Profile-only一新卷/CID/网、原私ADB/AVD/外Job；沿现roles/acquire/cleanup，不创建Solo/Party/key/spool/relay |
| 受控合法前置，不替代UI信用 | qualify_route中进入management同等Profile-only实物守卫；route ready且!launched时调用原prepare_solo_fixture；fixture_post/prepare_solo_fixture只增base显式允许 | 保prelaunch/attempted/active/四写固定顺序、意图先消费、unknown不重投、finally关闭/token清空；不增加任意POST或fixture重试 |
| 只验基地剩余链，不重复工坊/Solo | 原run_player_steps仍经同Ports；Flow.run新增base_fixture需prepared→startup_and_login→base，targets仅login/base | 新库四正常APIaccount/rename/design/build两机，9/5/4、无旧mission；实际UI登录/重登。base无player_reopen/link_mode权限；原management/Solo/Pump路径保留 |
| 当前预览事实与持久结果分别确认，不反推像素 | Flow.base及一个直接私有preview helper，复用原observe/act/两scroll；保已有合法候选计算，只为move排除自身占地 | 当前图选择→服务自然preview→新图读kind/valid/xy→合法成员/footprint校验→同图Confirm一次→正常GET核结果；局部状态本轮用完释放 |

权限合同：validate_plan对base只需management原公共输入+固定路径/hash的solo_fixture.py，不需udp_relay/bind_identity、禁solo_backend_port；scope/gate误配或缺allow即拒绝。qualify_route须无host bind/relay、只有本轮/data RW卷、无ROOM_KEY_FILE/SOLO_SPOOL_DIR，不能进入默认Solo分支。__init__/acquire/cleanup如现roles已满足则不改；不为行数增加空抽象。原scope1200/cleanup绝对1300/outer1320+13+30=1363、64/45/8和每target2scroll保持。准备四写不在手机capture后发生，不搬a3账号或数据库；原Solo门和管理无夹具规则不扩权。

观察合同：build/move意图为当前可辨靠路空地，不给源坐标或前图锚；移动/供电选择本轮唯一新repair的当前标签/形体，不声称看见#ID。私有helper要求当前base ready、准确预览种类（修理/移动/供能）、有效True、当前图两整数preview_xy及实际可用Confirm锚；坐标由该图读取，不能用RO候选反填。build xy须在本轮原合法repair集合；move集合排除本设施旧占地、不同旧位置；power xy须在真实同设施当前footprint内，不强求左上角。只认这些有限合同，不镜像完整服务验证器或新增capability。

仅真正offscreen且当前页面正认时允许原最多2次规定方向scroll/新图；knownFalse、错kind、错类型/范围/集合、未知页/错误/缺锚或预算耗尽零Confirm，不能隐藏false为null或遍历试格。预览不当提交；Confirm唯一一次后保原正常RO后验：新revision、build恰一新repair/该图xy，move同ID/该图xy/无第二设施，power同ID/位置保持/off→on与powered值；未知写不重发。最后真实换指挥官登录、布局revision/buildings/roads相同、旧token401且无资产写全部保留。未完成原步骤仍记unrun。

原a3工坊证据按生产/APK/服务依赖未变复用，base_fixture只计login/base，不能伪称该账号连续经营UI。原summary的not_selected/global_remaining如实保留其它目标，跨场信用仅由root依据签收汇总。此内部测试调整不增spec级产品行为，skip_specs保持。

验收分门：开发只必要新pure自测；test_lead待最终源签后仅新Solo选择入口、新Base preview/模式选择入口与Owner base fixture权限入口，核真实consumer调用/非首候选、move排自身/power内部格、wrongtype/false/错误/过期/2scroll与零Confirm、once/phase/缺gate拒绝、旧模式受改分支保持及无Solo资源。复用未变四写真实Handler/原路由/SDK/工坊证据，不重跑旧18/7/9/十组/全矩阵。不启动设备/网络/服务作纯资格；真实新库base/Solo各另精确门。实际可行图数在实现后逐consumer列出，不先承诺减少后的精确票数；省重复步骤不延租期/降低出口。source审/自测/独立资格/Android与最终性能分账，M23仍4/6，1077/r2保持。

### 基地首屏冷加载直接边界补准

2026-11-16 root带约束通过，仅三工具ENTRY边界和定向新pure/notes。封实际包前root核game/beta/entry.gd::_reply：login成功先Session.store，随后layout→guide→_present；Flow.startup_and_login的session与服务RO不是手机页ready，base_fixture的首个fold-guide可能仍处已知加载。旧management从工坊返回暖页的信用不能覆盖这个首次入口。未为此启动失败场或修改生产。

复用原ENTRY_BOUNDARIES/observe的同一私有基地加载语义，把fold-guide准确纳入入口；仅该step，不能任意page/scroll子step放宽。原三条准确U+2026文案、error/retry false、ready false/anchors空、共享至多3次×2秒和新图新票全部保持，不能添加sleep、重发登录/导航、增加64/45或恢复重试。目标就绪仍loading_text空且page_ready真并有当前按钮锚。无新增状态/Ports/Owner或异步框架；管理暖入口保持正常，Solo不调用此step，现五事件合同不变。

准原实现方只改player_steps.py这一个常量集合、player_steps_pure.py增加仅此入口的显式选择检查及notes。新纯应实际调用Flow.tap/observe/act，含三已知冷文案后新图一次点击、暖入口无等待、精确非法/ASCII省略号/错误/重试/矛盾事实零输入、共享3次原额度耗尽与新图绑定。不要改原Base5/Solo8/Owner5或重跑它们；新入口验证受影响的首次warm/cold行为，其余断言按函数/控制流未变复用，保旧三CLI18组原结果/锁/首错。源码审→仅新入口独立资格→准确实际Base包分别过门，当前无新的设备运行授权。

### 规则拒绝后的有界摆放纠正补审

2026-11-16 root带约束通过，依据[Base a1限定结果](verification/root-base-preview1081-a1-result-review.md)。实际catalog为1×2，首次当前选点得到完整“此处已有建筑或道路。\n请另选靠路的空地。”；原工具安全停但不允许现有产品明确提示的另选动作。root核base.gd::pick/_apply_response/_controls：每个候选生成新pending/action_key后只请求preview；已知规则拒绝清preview/禁Confirm，保move的chosen，当前模式下可直接另点位置。不是生产提交失败，也不能沿用单次定位假设反复开新场。

同类依据：[EA官方SimCity BuildIt入门指南](https://help.ea.com/en/articles/simcity/simcity-buildit/beginner-guide/)将移动位置和最后确认分为两步。只借用预览/确认分离的玩家流程，不把它当本项目拒绝次数/格坐标依据；本项目具体已知错误/不提交语义由上述原场和当前代码复核，最多两次纠正由本机测试预算定案。不改游戏、加按钮/网格/碰撞或扩大玩法。

仅原开发顺序改player-chain的steps/pure/notes三工具；Owner17d8、fixture/权限/网络、publisher、生产、Solo/冷入口不改。落位Flow.base/_base_preview及一个直接私有摆放helper：把build与move共同的“当前选点→新图看preview→已知未提交规则拒绝→RO不变量→下一当前图纠正”留在同一摆放生命周期，power仍原一次预览/Confirm，无通用重试器或遍历坐标。每阶段最多初次+2次纠正；计数在首次候选前创建，阶段结束/失败释放，原64/45/8/2scroll/工作绝对时限全部保持，不追加租期。最低25票不变，有纠正只消耗原剩余票数，最坏分支硬截partial。

允许纠正的完整可见Hint白名单仅：occupied两行原文、outside_grid“占地超出边界”、building_disconnected“建筑必须靠近与入口相连的道路”、entrance_reserved“入口需要保留”；move可另含same_position“机体设施已在此格”。这是有限摆放规则拒绝，不含网络/响应异常/费用不足/stale/session/保存待核或任何unknown。每个拒绝必须是本次候选完成后新图、当前base ready、preview_valid=False、真实preview_error_visible=True、准确完整拒绝字符串，不能用字符串包含/截断、填None或猜值。没有已发Confirm/提交pending，当前图不得给Confirm锚。known拒绝不借offscreen获得scroll或Confirm；健康preview仍原kind/valid/xy/两scroll严格校验。新的提示事实/可选值必须在notes完整声明，不从RO补视觉事实。

在每个摆放阶段首次候选前保存原有权限的本轮RO资产基线；每次已知拒绝后，实际读取同owner新快照并用原assert_no_asset_write核stocks/robots/parts/mounts/designs/bases/receipt IDs不变，再允许下一当前图新候选。生产时钟/production_state/server_now投影不作为全DB字节不变要求；不新读游戏内部pending/Save或新API权限。原a1缺拒绝后账，不能补造该历史证据。RO差异/读取未知或超时立即停，无纠正。

下一候选必须来自新的当前原PNG，人工据道路/占地/红框反馈纠正，当前anchor/点不得复用上次选点，不能循环同点或扫描候选坐标。move第一次仍需当前“已选修理，请点新位置。”正认；之后已知拒绝覆盖Hint，只有本Flow从未改Mode/Type/reset且同一已选择repair操作链仍在时才保留chosen绑定，不伪造该Hint仍可见、不重新点击其它建筑冒换目标。是否真正移动/建造只由合法新preview及唯一Confirm后的同ID/版本结果认定，未知Confirm结果永不重发。每个已知拒绝只允许新候选，不允许重复任何已提交动作。

资格仅重受影响Base选择入口：保原Base5断言并补确定拒绝后新图/RO不变/不同新点→成功、move保留chosen且不伪Hint、上限/重复点/错文案/RO变化/未知Confirm零重投。原Owner5/Solo8/冷4/publisher18按实际未变依赖复用，不机械重跑；开发交前像/精确diff和必要自测，root源签后test_lead一次受影响选择独立资格。再新Base准确门，不重旧a1或带旧数据，不因纠正功能省略实际移动/供电/重登。

## 维修合成新数据前置补审（2026-11-16）

按[root系统评审](verification/root-repair-synthetic-fixture-development-review.md)只准六测试文件的Profile-only repair_fixture。明确使用新库生产damage函数生成QA reference前置，正常四写、资产/战斗表不变与once/token/权限边界详见签审。复用Solo1081 a1已签真实battle→damage，本场只验synthetic damaged→真实UI维修，不冒自然战斗。此取代“每次维修必须重打完整Solo”的额外setup约束，既有游戏与费用/自然30秒不变。源码、独立新库/纯资格、实际Android仍分别签，不从工具完成推交付。
