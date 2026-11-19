# Design

## Context

见proposal。当前运行是1076-r5六服，稳定台账在operations/1076-r5/world/runtime.json；候选接受入口为已归档M15 accepted-inputs.json，唯一server覆盖SHA c88f75…b82f，APK066479…9b70和515冻结源不变。旧M06一次未创建mission，工具已有13项离散检查/输入与Job控验及peer/reader解析证据，不机械再跑。

已只读核实际pump_mission/party与M06工具：个人collect-exit只置departures，全部成员离场才global outcome，Party随后settle/award。因此旧peer在withdrawn后仍观察直到global receipt；无需加观察员或强行保活。现有end用两个global receipt接收UTC作保守上界可继续使用，但必须断言同一room及global终局、三人正常结果映射；capture收到停止后须有末次poll覆盖尾部。手机战报UI属于端到端证据，不延长战斗分母。

## Goals / Non-Goals

交付可追溯的1076服务修订并用一场完成真实三席功能验证与M06记录。无客户端重编译/重签、业务规则/画质/模型/人数/计时修改，无数据迁移、旧战报重放、保档升级或回退演练。M23功能接替与M06性能分开签，未测或未达帧预算不转成达标。

## Decisions

### 1. 稳定服务输入

开发代理只生成build/private-beta/operations/1076-delivery-r1：原rc1076基底与manifest SHA、原正式APK/元数据SHA、唯一server只读副本与接受来源、固定profile/room镜像ID、Compose覆盖/候选与正式env模板、bundle说明。服务修订标识为1076-delivery-r1，客户端仍1076；不改原APK/json或rc1076，不伪称新APK/新镜像。运行时是既有固定image加显式只读server覆盖，实际28份profile源（仅server差异）与22份各room源均核对。

配置只引用rc1076及稳定operations路径，cwd/base config保原冻结目录，不能依赖待归档change。project固定punk-private-beta-1076-delivery-r1，六新命名卷，网段10.244.126.0/27。候选33480/33471/72/73/74/76匹配既有无插桩端点APK489e9…0ad；正式333xx匹配原签名APK。epoch在启动前一次生成并记录两份实际env/hash，保PERIOD1800/DURATION1200及生产300秒，不在场内刷新日程。其他原env字段不得随意改。实际env、config_files/cwd、image+bind/源、ID/网络/卷/端口在稳定台账完整登记。

### 2. 最小测试复用

test_lead只补本轮上下文适配：优先加载已签M06 common/owner/supervisor/phase/peers/flow/capture/analyze/finalize和GDScript，不复制整套实现或建新追踪平台。上下文换新project/W/V/稳定配置/唯一server覆盖，source/包/工具锁绑定；新peer工程来自原冻结源、使用本轮独立user目录，不导入旧user数据。原GD逻辑/帧对去重/Clock/分位统计不变时复用已有检查；必要新参数/时间守卫只定向验证。

入场观察覆盖生产30秒集合及最多5秒传递余量，以实际三席participating/online及phase为准，不把两人先开战当三席通过。collector预算370秒、拥有进程385秒，peer自身/外层370/385秒（允许以相同总界限简化），包含30秒集合+300秒战斗+有限结算余量；设备总20分钟，原work1100+cleanup100不延长。只改工具截止，不改生产计时。

### 3. 一场实际玩法及记录

候选先只启动profile+party、六新卷，避免把额外四个房间的启动负载混入性能采样；旧1076仍运行并记录实际宿主负载。三新号正常注册/命名，声明initial_fit各补成6机12点，随后正常准备验证。手机普通地图/好友大厅/选机/准备，两正常ENet陪测通过正式准入协议，一段有界编排启动并确认三人到场，不让模型往返耗集合窗口。

手机战中真实触控沿西阀→东阀→箱子→出口，陪测仅正常route，按原生产规则协作。两peer先正常collect-exit，手机最后正常退出触发global outcome；不注入状态/票据恢复、改敌人/血量、强制胜利或为了帧样本延迟游戏。三人每人至少一个权威接受的有效指令，手机以终局前稳定save的只读副本解析，绝不回写；三人mission/entry/结果/room映射、一次费用/释放/累计与实际手机战报分别核。

### 4. 帧边界及独立结论

保留既有SF BOOTTIME同poll相邻间隔/去重/矛盾粗对剔除，UTC只关联，原Clock漂移与RTT限制不变。开始取原assembling→started括界/更宽launch回退，结束取同room两global receipt接收UTC最大值+pad；显式核末次权威ended、三presence正常撤离、三个人结果win/participated及手机最后实际结果。成功停止补一次有界末次latency poll和最终校准，覆盖结束上界；失败仍留journal/原异常并即时收尾。不能用首末已采帧缩分母或用战报UI补战斗时间。

全战斗有效区间并集/保守时长≥95%，满编18友+6敌且近期交火的双观察员交集≥4秒/80间隔；存活24不写同屏24。报全场/主要交火P50/P95/P99/max、>33.333/>50/>100ms、阶段/缺口/对齐与截图干扰，慢帧不剔除。只有有效覆盖且全场与主要交火P95均≤33.333ms才能记本场预算通过；否则M06相应项保持未通过，真机/热态/真人仍另列。测试实现与统计以真实数据为据，不自动补场凑绿。

### 5. 功能通过后的服务接替

三席功能结果足够后，root分别签功能与帧结论；本轮服务修订不改变渲染，所以M06超预算可作为原有内部试玩限制记录，不冒充性能通过。若功能未过不接替，先留证并清候选。

接替前先结束AVD/peer/采集与离线读save任务；候选其余四服务可在采样结束后启动核源与5路握手。查旧1076真实active场次/在途文件及外部使用，不能仅凭版本旧停止。实际切换先正常停止旧六实例但暂不删除，候选按稳定正式env同project/本轮卷正常重建为333xx六服务，核28/22源、绑定/协议/5路握手和本轮数据摘要一致，再按旧原config精确down删除退役六容器/专网。候选原334xx实例同次删除，无闲置测试副本；两个环境命名卷保留，不复制/回填旧数据。

如实际切换意外失败，删除本轮失败实例并恢复仍保留的同版本原实例提供原入口，只是实际运维恢复、不安排或执行数据回退演练。若旧方有活动/归属不明先停止交接，不强退玩家；无交接用途的候选及时down。交接结束由root明确接管新的六服及稳定台账，运行配置必须归档后仍存在。

## Risks / Trade-offs

整场自然玩法可能失败、采集不足或超预算；全部按实际记录，不改变阈值或补轮。Global receipt与个人withdrawn不同的生产语义须以实际字段断言，而非文件命名猜测。无插桩APK可能native日志空，不能伪称无错误；截图与现场触控仍按当轮实际布局。旧服务/共享服务是测量时宿主负载的一部分，不能把模拟器结果当真机保证。源与冻结输入若漂移，停止并交root核；不把工作区其他未验改动捎带发布。

## 首次启动失败后的有界诊断

r1实际服务启动在server只读bind整项断言失败，工具未先存inspect；两容器/专网已清，无账号或战斗。首错/清理见verification/root-failed-start-review.md。只读compose-config-diagnosis-a1证明配置推导字段可通过原谓词，仍不能推断已删实例的实际字段，不放宽断言或自动续r1数据。

允许准备一次最小挂载诊断输入：独立project punk-m23-bind-diagnostic-a1，仅固定profile image，network_mode=none，无端口及命名/数据卷，唯一原server只读bind。Python入口只读该文件类型/字节SHA，不import业务、不serve/建库。test_lead先交配置/有界命令/精确ID清理方案供root审查，未审前不create/start。实际诊断先create保存完整原inspect和分项谓词，再限时start读取SHA，成功/失败/超时精确删除该ID；无网络/命名卷可遗留，旧服务不变。此诊断不能提升功能/性能结论；后续实战使用新project/新卷/新启动记录，由root按诊断结果另审修订及输入锁。

诊断已签，本次原守卫全部成立但未复现r1。复验输入改为operations/1076-delivery-r2、project punk-private-beta-1076-delivery-r2、网段10.244.127.0/27及六新卷；r1文件/记录/卷全保留且不复用数据。源/APK/image/端口与玩法参数均沿已签原输入。新工具放verification/runtime-r2，独立build/m23-lobby-delivery-service-bundle-r2工作区和root-runtime-r2-release锁；不修改r1已执行工具。

仅新增gate断言前持久化实际inspect和挂载各子条件（唯一调用ID，不覆盖首证据），原Type/Destination/RW/规范化Source要求不变，不增加错误容忍或自动重试。差异与新hash由root另审；复验仍只允许一次同场功能/SF，原预算与清理规则不变。此调整补证据而非已证明根因修复，若再失败保原字段及时清理交审。

## 正式接替的宿主路径身份修订

首次接替已定位formal重建后Source表示为/run/desktop/mnt/host/c/…，Windows Path.resolve误判；候选138源及五握手通过，formal失败后新12容器/网已清、原六ID恢复，见root-handoff-failure-review。玩法/源/镜像/数据不改，3.1继续未通过。

新工具位于稳定operations/1076-delivery-r2/handoff-v2，不覆盖首次handoff或已锁runtime。对本机只支持Windows绝对驱动器路径与此次实际观察的Docker Desktop /run/desktop/mnt/host/<drive>/…表示，转换到同一Windows文件身份再精确比较；未知前缀/不同drive/不同文件/相对或穿越路径拒绝。Type、只读、精确目标及实际容器server SHA/138源仍必验，保存raw及转换过程。不作任意后缀匹配或通过异常吞掉身份错误。

开发代理提供小型共享身份函数及audit-v2和最小纯边界自测（实际两类路径、错误源/drive/前缀、目标/读写等）；test_lead按新工具manifest/新输出目录准备同任务r2卷的独立操作复验，继承已核显式Godot路径及退出/Job门槛，不重建账户/场次、不重跑245秒功能或SF。root审后再放行一次候选→formal必要检查与接替。所有首次失败及恢复证据留存，当前试玩仍r5。
