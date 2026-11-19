# 测试协作与文档索引

当前图视觉操作约束（2026-11-18，test_lead）：活跃45秒票内只读该请求及其当前PNG，及时发布或拒绝；源码、历史、账目和原因调查放到票外。目标必须匹配请求的具体控件文字/身份，不能因业务目的相同而替换另一入口。目标不在当前图内时，只提供该图可见的真实scroll区域且不提供tap，让既有Flow.target最多两次有界滚动找目标；不猜屏外bounds。非预期页面立即reject、无anchors/动作，不等过期，不续票或重发。每次决策仍经原visual_publish文件CLI，发布成功不代Owner接受。来源：[native a2根审纠正](../../openspec/changes/m23-motion-android-beta/verification/root-native-a2-failure-review.md)、[本case](cases.md#m23-motion-native)。

运动发行工具：[独立纯资格a1](../../openspec/changes/m23-motion-android-beta/verification/test-independent-tool-a1-report.md)54控制/28锁通过、1实际Python Job与协调器强身份已清，root待签；仅合成工具资格，无C源/实际镜像/APK/设备通过，开发原CRLF首错保留。

B安全转弯：[独立正式a1报告](../../openspec/changes/m04-authoritative-safe-turning/verification/test-independent-b-a1-report.md)已交root待签，真实10/10/18,202断言；规则子段/同版恢复与guard夹具分账，未跑自然宏步/C/Android。2实际Job及本轮SDK/端口已清，旧R2保手机1083；B/C最终自然场按后续C准确门一次整合。

后续[B出口根签](../../openspec/changes/m04-authoritative-safe-turning/verification/root-b-exit-review.md)已实际通过；上段原待签保执行历史。C正式选集从[轻惯性独立选集](../../openspec/changes/m04-authoritative-light-inertia/verification/c-independent-test-selection.md)进入，源/工具未签与准确门未到位前不运行。

M04本轮标准Solo网络呈现：[正式独立报告](../../openspec/changes/m04-smooth-robot-motion/verification/test-presentation-independent-a1-report.md)、[4.2组件/场景根签](../../openspec/changes/m04-smooth-robot-motion/verification/root-presentation-a1-result-review.md)、[4.3网络出口根签](../../openspec/changes/m04-smooth-robot-motion/verification/root-network-presentation-exit-review.md)。原逐postdraw CV门失败保留，后按预先固定50ms计时补证限项签网络出口，不是原逐帧/FPS/Android通过；16正式Job/SDK/24618已清，无新运行或新包，B/C权威转弯/惯性未实施。

M01当前Android：[F a2逐断言报告](../../openspec/changes/archive/2026-11-18-m01-automatic-session-refresh/verification/test-android-f-run-a2-report.md)保原false，实际HOME后台停读、同PID恢复自动新GET与完整新UUID可见已留原证，末尾工坊原生导航未运行；本轮205Job与SDK/监听最终全清。[root已签task2.3必要平台切片](../../openspec/changes/archive/2026-11-18-m01-automatic-session-refresh/verification/root-android-f-a2-result-review.md)，不外推F全流程。已有P1–P5/G仍按原签范围复用，未重跑。

指定USB手机1083已安装且当前私人基地/实际手机HTTP连接通过：[本轮报告与原件](../../openspec/changes/m23-usb-phone-lan-install/verification/test-phone-install-result.md)、[root手机签收](../../openspec/changes/m23-usb-phone-lan-install/root-phone-install-result-review.md)、[LAN六服签收](../../openspec/changes/m23-usb-phone-lan-install/root-lan-result-review.md)。1083使用192.168.31.170固定LAN，现R2六服同时保留回环供1082模拟器；不再将“1082仅模拟器端点”外推1083。原LAN a1/a2工具失败与恢复保原，未重验手机UDP战斗、实体性能或听感，不代负责人终验或创建个人账号。

状态：协作规则生效，GUT隔离试点已运行，统一入口已由主代理采纳。适用：M00–M24 的回归选择、测试执行与验收交接。维护角色：`test_lead`；主代理审查签收。更新：2026-11-13。

当前阶段：1082/ACK1本机Android模拟器内测交付已获[root最终签收](../../openspec/changes/m23-architecture-release-integration/verification/root-final-delivery-result-review.md)，M23本change 6/6；主入口为[当前可玩版交付](../current-playable-delivery.md)，[稳定索引](../../build/private-beta/current-playable.json)链接原签名APK与实际R2六服。六业务服务由root正式接管；临时probe/47内Job与outer已清。真实20Hz、可靠ACK及[完整安卓合作/三账/双P95](../../openspec/changes/m06-normal-candidate-frame-capture/verification/root-current-pump1082-a3-result-review.md)按依赖组合签收，原a1/a2失败保持。两次118.0593/1066.0949ms长帧因果未知，不承诺零卡顿；包端点10.0.2.2仅同机模拟器，负责人真机/听感终验未执行，未组织的真人自主游玩不填通过，不外推全模块或商业发行。历史原件从运行索引按限项读取，不重跑。

专职测试代理负责设计、执行和维护测试，主代理负责范围、风险与结果签收。默认采用一次独立执行加证据审查；不再由主代理另开相同账号矩阵亲手重跑。权威分工及新数据、资源清理要求见[研发协作规则](../../AGENTS.md#专职测试代理与自动化回归)。

2026-11-14负责人决定：真机检测与声音系统最终验收在完整可玩版交付后由负责人执行，当前继续Godot/联机/Android模拟器验证，不能以未取得真机或人耳结果阻塞开发交付。两项始终标“负责人交付后终验，未执行”，不代签通过；详见[负责人终验安排](../../AGENTS.md#负责人终验安排)。

| 需要做什么 | 入口 |
|---|---|
| 选框架、核兼容和明确试点边界 | [框架评估](framework-evaluation.md) |
| 按改动选择回归、查生产对象和证据失效条件 | [用例与回归选集](cases.md) |
| 查最近运行、继承证据和平台缺口 | [运行索引](runs/README.md) |
| 组织本机首次试玩、给安装帮助或记录真人反馈 | [玩家入口](playtest/player-start.md)、[主持人已知限制](playtest/known-limitations.md)、[独立观察模板](playtest/observer-template.md)；玩家不预读观察提纲，无人参与不填结果 |
| 提交一次运行与主代理签收 | [运行报告模板](templates/run.md) |
| 查本轮规划与任务范围 | [测试自动化基线](../../openspec/changes/archive/2026-11-12-m00-test-agent-automation-baseline/proposal.md) |

历史维修证据见[Repair UI1081 a1实际根签](../../openspec/changes/m23-architecture-release-integration/verification/root-repair-ui1081-a1-result-review.md)：本轮新库四正常写＋生产damage合成前置后，真实安卓一次收费、自然等待30.75秒并恢复待命已签；合成前置不冒本场战斗。旧Solo1081 a1真实战损及[Pump1081终局/双P95](../../openspec/changes/m06-normal-candidate-frame-capture/verification/root-current-pump1081-a2-result-review.md)只按未变断言复用，当前整合出口以上述1082最终签为准。

M06历史1081切片的P95 20.4207/32.3327ms与资源收尾保持；当前1082全场/满编P95为19.8101/20.1632ms、coverage1.0，来源及限制见[正式报告](../../openspec/changes/m06-normal-candidate-frame-capture/verification/test-current-pump1082-a3-report.md)。独立服务端成本与当前Android证据分别留证，不用单份性能报告代替所有模块结论。

## 分工与交接

| 角色 | 交付与责任 |
|---|---|
| 功能开发代理 | 提供实际差异、依赖、必要自测与复现步骤，修复产品缺陷；不自行宣布正式验收通过 |
| 测试代理 | 独立选择用例，提交复用与省略理由，执行获派范围，保存原始证据并清理资源，维护本目录 |
| 主代理 | 规划范围，审查需求映射、夹具、断言、原始证据和清理结论，签收或派发具体补验；不执行测试命令或操作模拟器 |
| 进度代理 | 引用测试运行与主代理签收，同步阶段缺口，不维护另一套测试结论 |

测试代理是职责，不是必须常驻的进程。换代理时，由主代理指定接任者；接任者先读本索引、当前运行报告、候选版本和资源台账，确认哪些实际句柄仍存活。进程已结束时不凭旧PID或状态文件重启测试。交接记录须列出仍缺的断言、可复用证据及资源接手人。

有45秒图义许可热路径的实际场，由主代理指定新开、无长历史继承且仅携当前精确执行包的专职测试接任者；准备与预读在运行前完成。单一操作方持有实际执行句柄和资源责任，当前可能产生UI请求时每次监督等待不超过5秒，亲看本轮原图并先写严格绑定的create-only许可，再汇报进度，不等主代理判图。未知、过期或缺锚时不操作、不续窗、不重发；按原finally收尾。交接明确当前资源、唯一句柄、操作方及离线文档维护者，禁止双方同时写许可。该流程来自[Solo a2许可过期与清理签收](../../openspec/changes/m23-architecture-release-integration/verification/root-solo-fixture-a2-result-review.md)，不引入新平台或延长原时限。

M23当前Windows视觉票据 `m23-player-visual-request-v1` → `m23-player-visual-decision-v1` 的文件交付固定使用 [visual_publish.py CLI](../../openspec/changes/m23-architecture-release-integration/verification/native-qualification/visual_publish.py)，依据[源码限定签收](../../openspec/changes/m23-architecture-release-integration/verification/root-visual-publication-source-review.md)与[18场独立资格](../../openspec/changes/m23-architecture-release-integration/verification/root-visual-publication-independent-result-review.md)。唯一operator先看当前PNG，再提供且仅提供 `decision/page/facts/anchors` 四键typed payload，以UTF8 JSON的ASCII URL-safe base64传 `--plan/--request/--payload-b64`；anchors只给bounds（scroll另direction），semantic及绑定元数据由同一请求复制。用标准argv参数列表启动固定文件CLI及准确运行命令，禁止默认stdin文本、临场Node/Python发布闭包和Windows多行`-c`的os.execv交付。该资格只证明当前schema的编码/原子文件发布，不识图或授动作，published与Owner接受分账；失败先核同final/Owner原回执，不覆盖/重发/延45秒。旧协议/失败原件保留，按精确门和适用schema使用；归档时同步这些链接，不泛化为全项目视觉协议。

## 按改动选择回归

1. 列明模块、OpenSpec要求、实际源码与资源差异、候选包及服务镜像。先查[用例目录](cases.md)，不要从全仓库通配执行开始。
2. 规则、场景组合及生命周期优先采用快速无界面测试；服务权限、费用、幂等和个人结算使用新库集成；安装、原生输入、HOME/返回及渲染性能保留相应平台验证。
3. 标出本次执行、复用、失效、未覆盖四类。公共网络、数据协议或经济边界变化时扩大相关选集；增加范围要说明捕获哪种玩家风险。
4. 对失败只重跑修复涉及的用例和依赖。保留首次失败及修订，不自动重试直到绿。观察异常先核原句柄、回执和已发生动作，不能重放可能完成的提交。
5. 由测试代理提交一次完整报告；主代理审证据。缺少某条证据时补该缺口，不默认重复整套矩阵。

有时限的多客户端入场由同一段有界编排衔接，截图留存后统一检查；不要让模型逐图往返消耗集合窗口。Godot场景输入的目标从实际节点布局取得；安卓则根据当前截图定位，布局变化后不能沿用旧坐标。

泵房下一场的45秒视觉许可发布按[短交接v2](../../openspec/changes/m06-normal-candidate-frame-capture/verification/pump-live-operator-handoff-v2.md)：同目录唯一temp完整UTF8写入、Flush/Dispose后，以不覆盖rename发布final，再保真实时序；禁止直接独占写final。本文是操作协议，须另有准确新source/packet/root运行门；[a1限定根签](../../openspec/changes/m06-normal-candidate-frame-capture/verification/root-current-pump1079-a1-result-review.md)保首错与后核延迟偏差，不冒玩家链/性能通过。

## 证据复用与失效

复用的是某项断言及其依赖，不是整份绿灯。记录来源运行、需求、生产源与场景及依赖哈希、APK、引擎、服务镜像/协议、配置/系统镜像、测试实现和夹具。原始日志、截图、账目与资源终态必须可追溯。

依赖未变且断言充分时可复用。改日志位置不自动作废产品证据；改请求控制须重验相关恢复场景；改Android原生插件/导出条件须重验对应原生边界；改模型须评估视觉与性能。平台不同、夹具缺陷影响结论、关键断言缺失或依赖关系无法确定时，标明待补证并执行相关用例。旧结果不能证明新实现。

## 文档与运行记录维护

长期规则在本目录维护，原始运行证据仍放所属OpenSpec change的 `verification/<run-id>/`，运行索引链接它，不复制长日志。新增用例时在 `cases.md` 登记要求、真实入口、依赖和失效条件；未实现的入口只写“计划”，不能给出假装可运行的命令。移动或废弃文档同步更新[项目索引](../README.md)。

报告分开记录准备/导入、执行、清理耗时，模型介入次数及用途、实例数、重跑原因和框架测试/断言/跳过数量。源码检查、工具测试、原生测试分别陈述，零用例或全部跳过不算通过。没有可比基线前不承诺节省百分比。主代理签收单独列出，测试代理不代签。

Godot4.6.1的JSON与native载荷比较须保留类型边界：[Solo旧回包a1工具匹配失败根签](../../openspec/changes/m04-unit-movement-clearance/verification/root-network-stale-solo-a1-result-review.md)已确认，现marker reader只缓存JSON、不恢复数字类型；[JSON官方文档](https://docs.godotengine.org/en/4.6/classes/class_json.html)说明数字按float解析，而[4.6.1 Dictionary源码](https://github.com/godotengine/godot/blob/4.6.1-stable/core/variant/dictionary.cpp#L249)的recursive_equal对值调用[Variant.hash_compare](https://github.com/godotengine/godot/blob/4.6.1-stable/core/variant/variant.cpp#L3033)，类型不同即false。因此JSON中的attempt=1与原RPC native int1不能直接整Dictionary相等判定。跨此边界按具体载荷校验精确schema与字段类型；数字仅在已验证int/float、finite、正整数等合法域内按真实cursor数值匹配，String/Bool/null/小数/非有限不能靠任意str/int强转通过，原payload与marker保持不变，不推广整包深度规范化或新增解析框架。组合断言先保存各检查布尔、实际类型和完整前后证据，再判失败；已知一个子条件必失败不能倒补未留证的原子/盘条件通过。此为已证测试工具比较限制，非产品缺陷，原a1失败及未运行项保留。

GUT9.6.1已在隔离工作区完成三组试点，入口见[快速回归命令](../../tests/godot/README.md)，实际通过与失败门槛见[试点报告](runs/2026-11-12-gut-pilot.md)。框架未进入正式工程/包，主代理已采纳，后续按变化逐步扩大；不搬运全部旧脚本或建立新CI平台。

新增独立Godot主脚本时，目录`--import`成功不能证明该非class入口已解析。对本次实际新增/改动且不依赖Autoload全局名的入口，在业务资源前用固定引擎`--headless --path <隔离工程> --check-only --script <入口>`取原始解析/退出/Job证据；依赖缓存可按哈希复用，不批量扫全工程或重跑未变用例。来源为[A01实际入口Parse Error及根审](../../openspec/changes/archive/2026-11-14-m14-solo-commit-boundary/verification/root-restart-a1-review.md)；check-only只证明解析，不冒称业务执行通过。

新增或改动的每个实际GD入口（包括peer与覆盖件，而非仅测试driver）须在启容器、Android或真实业务写入前，用锁定真实引擎按实际加载路径及依赖闭包逐入口取得check-only证据；旧入口资格不能覆盖新文件。无改源码不重复解析，不另建框架；依赖Autoload者按下述真实生命周期合同核验。经验见[Party实际peer解析失败](../../openspec/changes/m06-party-runtime-profile/verification/root-runtime-a1-result-review.md)及[单入口补验](../../openspec/changes/m06-party-runtime-profile/verification/test-peer-parse-a1-report.md)。

Autoload消费者另核入口生命周期：[Exercise UI a2已签入口失败](../../openspec/changes/m04-unit-movement-clearance/verification/root-network-room-ui-a2-result-review.md)中，原Exercise独立check报`Identifier not found: Room`。固定Godot4.6.1的[官方main.cpp](https://github.com/godotengine/godot/blob/4.6.1-stable/main/main.cpp#L3939)在3939–3944先load/check脚本并返回，Autoload全局名注册位于4061–4120之后。因此不能把该入口错误当产品正常场景启动失败，也不能以import exit0替代编译有效性。依赖Autoload的原场景须在正常SceneTree启动、真实Autoload就绪后实际load/change_scene并核返回、ready及所需节点，保完整原日志，严格检查`SCRIPT ERROR`、`Parse Error`与`ERROR:`；不伪造Autoload常量、不忽略错误。普通不依赖Autoload的driver继续适用上面的check-only；本条不授权新增bootstrap或扩大框架。

旧默认路径环境阻断见[2026-11-13历史审计](runs/2026-11-13-automation-audit.md)。显式--engine入口已完成三拒绝及一次rules定向执行，见[实际报告](../../openspec/changes/archive/2026-11-13-m00-gut-explicit-engine-path/verification/test-report.md)，主代理已独立签收；须使用README中的LocalCache实际路径，省略参数的旧默认仍不可用。

新增或修改Godot测试、运维握手入口时，显式传入引擎或继承本轮已核的ENGINE；启动前核文件存在与固定SHA，记录实际绝对路径/argv。不要根据LOCALAPPDATA重新拼接另一条默认路径。本机路径从[快速回归前置说明](../../tests/godot/README.md)取得；换宿主时重新核实，不自动扫描换版。路径错误发生在启动前时保留首因，修订后只补受影响步骤，不机械重建服务或重跑玩法。历史脚本按使用需要逐项调整，不批量翻修。来源为本轮[交接路径失败与修订](../../build/private-beta/operations/1076-delivery-r2/handoff/transport-host-preflight-failure.json)，不影响已签框架和三席功能证据。

Docker挂载身份先保存实际inspect，再核Type、目标、只读、源文件身份和实际容器内容SHA。Docker Desktop的守护进程位于Linux VM，会映射宿主路径（[官方说明](https://docs.docker.com/engine/storage/bind-mounts/)）；不要直接以Windows的Path.resolve解释daemon的Linux路径。只接受本机证据和定向验证支持的表示转换，未知前缀或不一致即拒绝，保留raw及转换过程；不能以文件名后缀或吞掉异常替代源检查。本轮[正式重建误拒证据](../../build/private-beta/operations/1076-delivery-r2/handoff/formal-bind-failure.json)只证明该次映射问题，未留原字段的历史失败不能倒推根因。

发行工具纯资格后续[root实际签收](../../openspec/changes/m23-motion-android-beta/verification/root-tool-qualification-review.md)已通过；原待签句保历史。仅纯工具资格，未验真实候选/镜像/APK/HOME。

C轻惯性：[独立正式a1](../../openspec/changes/m04-authoritative-light-inertia/verification/test-independent-c-a1-report.md)一次GUT16/16、20,939断言；唯一自然v2真启用、265宏步无歧义/预算与严格净空通过、400ms及预签50ms/10全周期门通过。原postdraw CV.20807>.20保留，补证非FPS/Android；16Job与本轮进程/端口全清，root待签。

C后续[root实际共同出口签收](../../openspec/changes/m04-authoritative-light-inertia/verification/root-c-exit-review.md)已通过；保上段执行时pending和原逐postdraw失败，网络补证非FPS/Android。准交共同冻结，真实镜像/APK/Android仍另门。

运动真实镜像：[独立审计a1报告](../../openspec/changes/m23-motion-android-beta/verification/test-independent-image-audit-a1-report.md)原汇总false保留，42COPY/正常加载通过；9CID仅两Ports排列反转，语义补证与1/1删除、Job/网络终态已获[root限项签收](../../openspec/changes/m23-motion-android-beta/verification/root-image-audit-result-review.md)。原额外PowerShell观察124保未完成，不重跑；APK/Android仍另门。

1085 APK独立审计：[a1首错报告](../../openspec/changes/m23-motion-android-beta/verification/test-independent-artifact-audit-a1-report.md)保原false，旧auditor有效端口仍333xx而冻结候选334xx，SDK未启动；不是产品包失败结论，待root工具差异AR，无重签/重跑/native。原Job及三强身份已清。

1085 APK后续[a2真实审核](../../openspec/changes/m23-motion-android-beta/verification/test-independent-artifact-a2-report.md)已获[root实际签收](../../openspec/changes/m23-motion-android-beta/verification/root-artifact-a2-result-review.md)：同字节包、200必需资源/407sparse/六端点/五SDK与两负控通过，586锁同，七强身份gone。原a1失败不改；native未启动。

运动镜像后续[真实a2审核](../../openspec/changes/m23-motion-android-beta/verification/test-independent-image-a2-report.md)已获[root实际签收](../../openspec/changes/m23-motion-android-beta/verification/root-image-a2-result-review.md)：同4c5f/42COPY/545源、正常加载与finally passed，21实际Job双空/43唯一强身份gone、临时CID删1/1、owner空/网络同/585锁同。原a1false保；native最终615锁false门已准备，未运行。

运动native正式[a1原首错与清理报告](../../openspec/changes/m23-motion-android-beta/verification/test-independent-native-a1-report.md)：平台TCP echo Network is unreachable，未首启/未四写/无视觉请求，运动/HOME未运行，不判产品失败或通过。615锁同；220Job双空、466唯一强身份gone、两CID删2/专网与选端口空，保卷/已停AVD/原件。无重跑，待root审后定下一步。

Native a1后续[root实际失败与清理签收](../../openspec/changes/m23-motion-android-beta/verification/root-native-a1-failure-review.md)已落；DNAT零明确为发送前initial，失败后未采。运动/HOME仍未运行。新a2仅按已签只读网络观测AR准备，全新数据/同包同镜像，不重试echo或改网络，未启动。

Native有目的a2：[正式报告](../../openspec/changes/m23-motion-android-beta/verification/test-independent-native-a2-report.md)原整体false；三网络快照/真实echo与UID route/四API/UI登录完成，但入口后仍base，operator未及时在45秒内拒绝导致过期。运动/HOME/撤退未运行；不称a1根因修复。625锁同，354Job双空/734唯一强身份gone，容器删2/网络端口空；无第三场，待root审入口/坐标/等待原件。

Native a2[root实际分项审查](../../openspec/changes/m23-motion-android-beta/verification/root-native-a2-failure-review.md)已落：仅平台/四API/登录和清理接受，整体false/运动HOME未验保持。Guide误锚与迟拒绝已写入本索引顶部协作约束/[case](cases.md#m23-motion-native)/[a3 handoff](../../openspec/changes/m23-motion-android-beta/verification/native-a3-operator-handoff.md)，新a3仅草案，等readiness源/compile/准确门。

活票拒绝模板已在[a3 handoff票前核对](../../openspec/changes/m23-motion-android-beta/verification/native-a3-operator-handoff.md#票前已核的立即reject模板)明确：reject/page=request.expected_page/facts全required键为null/anchors空。拒绝page仅原schema词汇标签，不声称实际页匹配，Owner在accept准入前拒绝且不发输入；不改publisher或续票。a3预算160为进入最低剩余门，非平台deadline，新guard要求原work余量≥45。

封门输入协作补充：flat文件锁与plan内部ref须双向一致。最终封门及执行前，逐plan.inputs核实际path/SHA、flat lock对应值；root AR追加预算更正等变化后不能只刷新flat lock而保草案ref。原[a3准入前错误](../../openspec/changes/m23-motion-android-beta/verification/test-independent-native-a3-prelaunch-report.md)保留，未启动资源/玩家场，运动HOME未验；下一执行须新准确门。

Native a3b: [independent report](../../openspec/changes/m23-motion-android-beta/verification/test-independent-native-a3b-report.md) preserves overall false. Unique delegated publisher scrolled once to the exact constant Explore button, sent one tap, then timely rejected the next actual base frame. Platform/API fixture/UI login completed; movement/HOME/retreat remain unrun. 634 inputs unchanged; 365 Jobs double-empty, 756 original identities gone; 2 CIDs removed/private network and selected ports empty/shared services unchanged. Root acceptance pending; no rerun.

Native a3b [actual root failure/resource review](../../openspec/changes/m23-motion-android-beta/verification/root-native-a3b-failure-review.md) is now signed; original false/pending history remains. Complete Android reruns stopped. [Quick Base-scroll test selection draft](../../openspec/changes/m23-motion-android-beta/verification/base-scroll-quick-test-selection-draft.md) identifies existing real GUI probe and its refresh/navigation limits; no engine/tool implementation or runtime authorized by this draft.

Base GUI a1 [independent report](../../openspec/changes/m23-motion-android-beta/verification/test-independent-base-stability-a1-report.md): single original Owner exited1 at fixture Stats Dictionary equality before either GUI case. Immediate/delayed unrun, zero PNG/trajectory; product_scroll_passed/delayed_stable null. One Job double-empty, three original identities gone, held_input=false/live roots0, 1296 hashes unchanged. Preparation wrong inventory-function name retained separately; no GUI retry or source change. Root review pending.

Base GUI a2 [independent report](../../openspec/changes/m23-motion-android-beta/verification/test-independent-base-stability-a2-report.md): first same-instance tap during unfinished scroll failed; 5PNG/51 samples/188 events retained, delayed21s unrun. Anchor scroll279 versus dispatch-near scroll300 explains the narrow target miss observation; not Android or automatic refresh cause. One Job/3 original identities clear, heldfalse/live roots0/1304 unchanged. No repeat; await root source/gate for any settle-window test.

Base GUI a3 [independent report](../../openspec/changes/m23-motion-android-beta/verification/test-independent-base-stability-a3-report.md): fixed0.9+observed scroll_ended ordinary control and saved-point21s case complete; each actual Explore pressed once, delayed1262 rows preserve scroll425/rect. diagnostic_complete/delayed_stable true, product_scroll_passed null; no automatic refresh/HTTP/business/Android cause verdict. Ten PNG,107+1368 rows preserved; one Job/3 identities gone,1312 hashes unchanged. Original a1/a2 failures/root cleanup reviews retained; root a3 acceptance pending.

Base GUI a3 [actual limited root acceptance](../../openspec/changes/m23-motion-android-beta/verification/root-base-stability-a3-result-review.md) signs the static GUI observations and resource cleanup; no automatic refresh/Android claim. [M17 stable Guide background read design](../../openspec/changes/m17-stable-guide-background-read/design.md) now authorizes a separate six-GET presentation test implementation; source/exact execution gate still pending, no runtime started.

M17 Guide background read [independent report](../../openspec/changes/m17-stable-guide-background-read/verification/test-independent-a1-report.md): one real six-GET GUI scene joint gate passed, initial/same-content/queue/failure feedback covered;274 samples/7PNG and18 HTTP begin/attempt/sent records retained. One Job/4 original identities clear, dynamic62146 closed/thread+handlers joined,1338 hashes same. Root acceptance pending; no Base10s scheduling/business/Android/historical-cause verdict or native rerun.

M17 [actual root independent acceptance](../../openspec/changes/m17-stable-guide-background-read/verification/root-independent-result-review.md) now signs the six-GET Guide presentation and cleanup. Original pending history and limited coverage remain; new candidate freeze/image identity/APK/native delivery are separate gates, with no image rebuild or B/C rerun inferred.

1086 candidate image [actual independent report](../../openspec/changes/m23-motion-android-beta/verification/test-independent-image1086-a1-report.md): new4878/545 manifest and unchanged42COPY/4c5f real image contents/load passed. One network-none CID removed1/1, nine protected containers/seven networks retained,21 Jobs/43 original identities clear,593 post-lock inputs same. Root acceptance pending; no image rebuild/B-C/SDK/AVD/native run.

1086 image [actual root acceptance](../../openspec/changes/m23-motion-android-beta/verification/root-image1086-result-review.md) now signs source identity/content/runtime/cleanup. Independent same-byte1086 APK audit packet is prepared with false gate; no SDK/installation/native execution implied.

1086 APK [independent report](../../openspec/changes/m23-motion-android-beta/verification/test-independent-artifact1086-a1-report.md): original passed/unrun[]/runtime_validated=false;200source/407sparse/180remap/20import, correct sixLAN334 endpoints,5SDK stages and2actual negative controls. One Job/8 original identities clear,590 hashes/APK same. Root acceptance pending; no install/AVD/native run.

1086 artifact [actual root acceptance](../../openspec/changes/m23-motion-android-beta/verification/root-artifact1086-result-review.md) is signed. New native1086 static packet has28 nested=flat=actual and resource-free original validate_plan pass; actual gate remains false, no Owner/SDK/AVD/services started.

Native1086 a1 [environment failure report](../../openspec/changes/m23-motion-android-beta/verification/test-independent-native1086-a1-report.md): emulator userdata allocation needed7372.8MB but5979.132812MB available, before device/install/UI/motion. Original cooperative cancel/finally preserved2cleanup diagnostics;2CID deleted/private net and ports empty,484Job/899 original identities gone,644 hashes same. Zero visual tickets/decisions, operator stopped. No restart/deletion/history move; root acceptance pending.
