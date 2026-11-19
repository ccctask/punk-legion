# Design

## Context

主责M23，关联M05/M06/M14/M22。用户授权B先于C、两者通过后更新安卓包。1084最新可用但用户手机1083/default模拟器1082与旧R2六服仍在；新权威规则不能接旧R2。源码冻结/唯一APK builder/独立artifact auditor已有真实通用能力；旧镜像和Android Owner工具则硬锁1082及333xx地址，不能只换JSON冒支持。

## Goals / Non-Goals

最终A+B+C共同冻结、新服务器与安卓同源、必要真实模拟器切片及可试玩稳定交付；不迁移旧数据、不扩玩法或重跑泵站经济整矩阵，不替负责人真机/声音终验。预计code1085，签前须在唯一账本锁再次核未分配，失败不自动重签。

## Decisions — 工具实现架构评审（2026-11-18，root通过）

依据[B/C测试预审](../m04-smooth-robot-motion/verification/bc-android-test-preflight.md)、[准确硬锁预审](../m04-authoritative-safe-turning/verification/release1085-tool-preflight.md)及root读取实际工具入口，准以下必要实现，不准提前冻结/构建/部署/SDK运行：

| 实际职责/明确不承担 | 准许文件/落位理由 | 所有者/依赖/生命周期 |
|---|---|---|
| 新共同冻结源的唯一镜像构建/映像文件审核；不创建业务容器或数据库 | `openspec/changes/m23-architecture-release-integration/verification/image_build_stage.py`，复用现有固定argv/Owner/daemon终态，窄增加新候选锁模式，旧1082模式保合同 | 从root批准不可变snapshot/work/tag/精确docker argv、manifest/COPY映射与受保护CID输入验证→原owned_run构建→digest/文件映射回读→检查共享资源不变。漏COPY/异常标签/目录/源拒绝；不把全机容器等同退役1076/1077旧集合 |
| 新候选身份统一验证、服务/设备/安装/恢复/资源收尾；不重造资源Owner | 同目录`native-qualification/owner_adapter.py`，候选身份用于准入/create/install/post-inspect/session所有实际边界，应同处单轮Owner不可变值，局部纯函数验证/MappingProxy即可 | 仅明确candidate+scope=player_chain+player_mode=solo_fixture+player_scenario=motion启用新绑定。APK/meta/manifest、原签名、真实artifact/image根签、实际Profile/Godot digest、host/六端口/route SHA同锁。旧模式沿原常量，不全局改常量放宽。原AVD/私ADB/Job/UID/期限/清理不改 |
| 精确单UID六规则候选路由；不更改主机全局网络 | 同目录`route/uid_route.py`，实际源IP/端口必须随同字节LAN APK绑定 | 从已审candidate传规范IPv4 /32与固定六键tcp/udp源端口、真实app UID/nonce；目标仍原10.0.2.2私有targets。跳链/六规则/计数读回/负控/finally精确清理保持；禁止通配地址、其它UID或未审JSON自声明 |
| 单次正常UI运动切片；不创建服务/进程/账户Owner或另抄Flow | 新同目录`player-chain/motion_steps.py`，由owner_adapter新scenario dispatch；base player_steps.py以额外inputs.player_steps_base锁定后显式注入run(base=...)，复用其Flow/Ports/native_confirmation | 原CLI不改，只准正常新号/本轮fixture→标准Solo真实触控起停/绕障→HOME/同PID恢复及必要重连。动作由原当前图/nonce许可及Owner执行，未知结果先核不重发。HTTP仅既有fixture能力，不替代实际UDP/触控 |
| 候选配置及稳定交付记录；不改旧R2配置/卷 | `deploy/private-beta.env`仅六HOST_PORT键、`build/private-beta/operations/1085-motion-beta/`新overlay/env/OPERATIONS/runtime/根签 | 预计HTTP33480、UDP33471/33472/33473/33474/33476；实际空闲、LAN地址及配置在运行前核。冻结前改配置并保前像，freeze后不改manifest实体。运行文件必须稳定存operations，不指活动change路径 |
| 最小纯负控/说明；不引第二框架/进程管理 | 本change `verification/tool_contract_checks.py`与工具交接说明 | 仅调用上述真实纯验证/路由计划函数，正反候选/源/host/端口/签根/旧模式拒绝合同；不伪装实际镜像/安装通过。不得实现另一套候选业务或虚假ADB/容器成功 |

root核dispatch无需第五既有入口：owner_adapter只在motion加载新steps+锁定base，原native_confirmation仍base；不修改旧Ports dataclass或player_steps完整经济矩阵。真实HOME能力必须由同Owner局部一次性resume callback传给motion步骤：真实HOME→保原UID/PID/route/期限→正常am start→核同PID。原reopen_once是force-stop，不能冒HOME；该重启仅作独立重登事实。任何实际调用需新增权限、Owner边界或文件先复审。

工具差异复审追加（2026-11-18 root通过）：实际镜像内部审计并非通用APK auditor，`openspec/changes/m23-architecture-release-integration/verification/image-audit/audit_images.py::validate_current_config/validate_image_gate`仍硬锁3cea/41/root旧action。root已读实际检查，批准该第五个既有工具仅增明确candidate_normal模式：批准digest/冻结manifest及实际COPY映射/count/独立root action同锁；原normal/M3模式不变，新模式仍固定Godot4.6.1与精确无bind/network-none读取/加载argv，实际临时CID与原Owner/finally清理不变。未知/缺COPY/源/映像/根签拒绝，不因参数化放宽日志错误或旧M3验证。纯正反控可覆盖该入口。此追加不授权运行Docker或签发，APK artifact auditor仍无需改。

首稿源审窄修准入：Owner应消费validate_plan同次校验返回的唯一不可变candidate，不再第二次重读构造；保旧调用签名默认返回值。image audit的COPY count/expected不能仅相互自声明，准共享image_build_stage真实纯COPY oracle作为准确锁定依赖，严格核全部目标集合/源映射；C新增path_motion.gd/Dockerfile COPY后实际应42项，不能改常量冒覆盖。审计原件需明确manifest SHA/COPY摘要并与candidate比对，防串用其它来源。motion近距离移动增加停稳的第二实际观察/PNG/事实，不只moved冒起停。均在已签实际文件和职责内，无新增资源Owner。

预算事实更正：root核实际image-audit.main为工作120秒、cleanup绝对160秒（清理40秒），后续外层含原13秒尾为173；早先预审/本节下文120+20/153属误记，不作为执行能力。保真实既有清理生命周期，不为文案缩窗，后续准确门按120/160/173锁定。

原player_chain工作/清理绝对/外层为1200/1300/1320秒，保持真实限制并扣各OwnedJob 8+5尾；motion步骤内部动作≤360秒，不把420秒写成旧Owner支持的新上限。单AVD/私ADB、USB0/EMU1，实际创建前核内存/已有实例。所有成功/失败/超时均原finally清理：精确UID route、app、AVD、私ADB、临时容器/网络/端口，保卷/镜像/证据。记录强身份及本轮实际容器删除数，不动其它资源。开发源/准确自检计划先交root源审，未获运行门不启动任何引擎/SDK/Docker/服务。

## 共同源与真实发布（此节运行门待C出口后另签）

复用deploy/build_private_beta.py freeze与既有build_integration_candidate.py、artifact/audit_artifact.py，不改签库/密码处理。Profile当前81个文件与已签源相同可按依赖复用b0镜像，最终需把冻结源和实际image审计重新绑定；实际Godot镜像须包含B/C最终批准源。签发、image build、artifact audit分别源锁/准确argv/预算/原件，不能先签包再找来源或无变化重试。预计构建300+60/outer373、审计120+20/outer153，使用真实旧入口能力。

候选服务使用独立新卷/新key/新账号/新场。先Profile+Solo必要切片，新六服稳定交付必须逐服务核实际源/image/env/端口/健康与协议，并由root明确接管。新APK指实际新LAN端点，同字节在模拟器用UID-DNAT映射到独立测试服务，不修改APK。用户旧R2保手机1083入口，尚未退役；旧实例确有接替并核无活动/在途才可按原配置down，默认保卷，禁止全局清理。

## 验收与限制

工具先纯源/真实正反控，独立test_lead复核；B/C出口后唯一共同源、实际新image与APK审计通过才正式Android门。Android只一次必要Solo触控与HOME/重登切片，不声称全地图/新P95/实体听感；复用其它消费者未变证据按断言列来源。真实C规则/自然Godot指标与Android实操分开，不以UI动画或纯工具控制冒服务器行为通过。

## Risks / Trade-offs

旧工具常量散布所有创建/安装/后核，必须同一不可变绑定贯穿而非只改validate。包的源LAN地址与route /32须一致。新卷意味着新号开始，明确不保用户旧档。当前手机旧包仍需R2服务，新六服接管不自动把R2当闲置；保留用途/负责人清楚登记。

## 实际APK首错后的窄工具AR（2026-11-18 root签通过，先审后委派）

真实1085包已唯一签发（563ffa6d…a274915），独立a1因auditor payload_audit第270–271行旧333xx硬锁而false，原件与零SDK/清理保留。此前“artifact auditor通用无需改”的预审不完整，本次修正该判断；不改包/源/端口或重签，不无变化重跑。

主责仍M23只读产物审核工具。准原开发方仅修改 `openspec/changes/m23-architecture-release-integration/verification/artifact/audit_artifact.py` 的端点期望/比较及其既有纯控制入口；必要的小型纯控制调用原件存本change verification，不新增框架/Owner/候选业务。实际生产、冻结snapshot、签发器、image/native工具均不准改。

纯调用落位细化（root准）：本change已有`verification/tool_contract_checks.py`可新增明确隔离的`--artifact-endpoints`切片，调用上述真实纯函数；原54模式合同保持，不为本切片重跑54或扩同包生产范围。两实际文件及各自前像/diff都要交源审。

## Native准入前的端口集合比较窄AR（2026-11-18 root签通过）

实际native Owner要求原image audit passed与content_runtime_passed均true；先前image a1内容通过而汇总因Ports数组顺序false，root资源补证不会改变原raw。不得伪造passed=true结果、添加根签替代资格协议或放宽Owner。这个阻塞属于既有发行测试工具正确性，与玩家玩法无关；必要最小收口后才完成安卓交付，不进入新功能池。

准原开发方仅改`m23-architecture-release-integration/verification/image-audit/audit_images.py`最终inventory比较及本change已有`verification/tool_contract_checks.py`隔离`--image-inventory`纯切片。现inventory按CID排序、保存before/after真实数据，最终直接after==baseline会误将同一Ports数组排列当变更。新增局部纯比较/规范值函数应保原件不变，**只把每Ports键的绑定数组视为无序多重集**；完整比较每绑定对象所有字段、保重复计数、None与空数组的区别，其余CID/名称/镜像/Running/Status/Labels等字段精确相同。未知字段不得丢弃，不扩大为任意列表无序，也不得忽略真实端口/IP/状态差异。函数属于现最终资源核对职责，不持资源状态/不更Owner。

容器归属/隔离/COPY/4.6.1运行/原120工作160清理173外层/精确stop-rm/网络集/输入后核判据保持。禁止生产/冻结源/APK/native Owner或其它工具修改。原a1false/额外PowerShell超时/根补证保留。

先交前像/diff/纯控false计划供root源审，再原Owner一次短纯控：原真实双地址顺序反转等值；IP/hostport/protocol/privateport/绑定重复数/null-vs-empty/其它字段/增删CID不同都拒绝且不修改入参。只跑新切片，不重跑54/60无关控制。正式test_lead随后按新工具/准确新a2门一次真实同4c5f镜像审核，验证改动后的最终资源生命周期；不复建镜像/不重签APK、不引新资格格式。其23秒级真实执行是工具已修后的必要验证，不是无变化重试；原内容证明保留。root签实际a2后Owner消费真实成功原件。

main已经先核manifest SHA/集合/每实体，随后才payload审核：六角色端口应由该已锁snapshot `deploy/private-beta.env` 数据派生，而不是333常量或新的自由JSON自声明。该派生属于独立审计期望，保持“不import release/build/signing”的工具合同，不为几个声明值执行builder。复用本auditor现有ConfigParser/need等纯能力，在函数局部生成六角色整数映射，拒缺项/重复键/非整数/1..65535外/重复端口；明确profile与room/solo/party/camp/treasure逐键，不按列表位置猜Compose名称。公开host仍来自原严格candidate，profile URL及每UDP host/port必须全部比较。输出实际期望六角色以便复核。

状态/生命周期不变：锁定source与APK→只读局部端点期望→PCK真实有效端点校验→原SDK/负控→原finally/输入后核。无可变全局缓存、无新进程/资源/重试/网络。源码完整性/映射/编译格式/ABI/签者/权限/模板/预算等判据不得放宽。源env与有效PCK应分离，不能以包中值反推自身期望；这是本工具当前独立验证价值，不复制游戏业务规则。

源交后root先审，再准开发必要纯控制：沿真实端点派生/比较函数验证旧333与新334两组正例；分别错profile、每UDP、host、漏项及非法源端口等负例，确认准确原因，保不相关旧完整性控制。纯控制不启动SDK/Godot/Docker，不再跑54项其它工具。独立测试代理按修改后的源码封新a2输入/准确门，用**同一个**已签1085字节包完成此前未执行的真实payload/SDK/controls；保原a1，不重复构建/签发。功能结果与结构源审分别由root签收。
