# Design

## Context

见proposal。已读原整场根签、native1010、scheduling、SF a3停止结论。原整场7368间隔/覆盖1.0有效，不能因新采样改变分母或预算；旧短首领CPU样本不代表当前24机泵房。SF replay尚未ready即停止，本项不修或复跑该应用。

新静态事实：1077正式包及既有正常诊断包均已profileable enabled/shell=true，其x86_64 native与官方本机release模板逐字节相同，SHA ec9f6d6080ac29a8152ba605d5e82c0b6ed761ef853ea317886605a14e922e41、BuildID 383f9a53682e9f08；debug模板BuildID不同。本机已查缓存未见匹配符号（非全盘穷举）。原正常whole-pump编排仍硬依赖SF ready及1076上下文，不能原样运行。

## Goals / Non-Goals

先建立同构建符号可用性，再取得一段当前正常客户端的有限原生CPU归因。不开新引擎编译、不改native/manifest或正式APK，不调阴影/LOD/缩放/MultiMesh，不恢复SF/ETW/QMP。此任务不测新P95、不承诺零采样扰动或GPU/宿主/off-CPU根因，不把新工具资格写成M06达标。

## Decisions

1. **离线先行。** 固定官方Godot4.6.1 release符号包，766230163字节，SHA c0f2a8afef83562990606612601d8bb49b8a16527672a4a41c669abe5968d90f；先校完整SHA，再仅解x86_64目标成员，核ELF架构/BuildID及实际可用函数表。版本号相同不够，debug模板不得套用release符号。至少用真实native导出符号地址作同构建控制，并证实能解析Godot非导出函数；错误BuildID必须拒绝。优先复用现有ELF/NDK/simpleperf工具，缺口只做最小读取器，不建解析框架或先编译引擎。
2. **缓存及预算。** test_lead获单独门后下载，固定新缓存目录且不覆盖已验文件；核可用空间，预计只保731MiB压缩包及目标ABI符号。单成员上限3GiB、可用空间先至少5GiB，网络/工作总时限600秒、清理60秒；流式落盘与解包，拒越界/符号链接/错误成员，按实际句柄观察，失败不自动重试到绿。无AVD/ADB/服务/数据库。已验官方缓存可长期复用，残缺文件与下载进程终态明确记录。
3. **正常客户端。** 符号门通过再适配现成正常入场、合法三席、peer及清理上下文，优先复用现有1077正常端点诊断包，不使用replay或新增GDScript采集主场景。若现有端点冲突，先交root定范围，不改当前试玩、不杀未知实例。只启动实际需要的新QA服务、新卷/三账号/场次，不能导入旧库或复投旧报。
4. **单次CPU采样。** 正式准备核同一PID、真实Godot兼容渲染线程/TID、API/内置simpleperf与profileable准入，正常battle画面/同场状态和三个合法玩家；然后单次约30秒、79Hz task-clock:u、FP，仅该线程，记录原argv/事件/时间域/样本lost/MMAP BuildID与调用链。实际设备不支持、FP不可用或启动失败则停，不临场换DWARF/频率/新场补轮。记录实际存活规模和取景，初始18友+6守卫可自然阵亡，不假称全程同屏24。
5. **分析边界。** 保样本原件、BuildID匹配与符号覆盖/未知/断栈计数，区分leaf与调用链、Godot与模拟器编码库；编码库按本轮实际身份核，不套1010地址。可以定位该线程用户态CPU集中函数，不能把百分比换算帧时、将缺栈推成GPU等待或由一次采样直接承诺优化收益。新增产品优化须据实际可改热点另定范围，M06仍F直到后续独立帧预算通过。
6. **收尾与分工。** 开发交工具/必要自测，test_lead独立门/执行/文档/清理，root只审原始证据，不重复矩阵。最多一AVD、一Android客户端及必要headless peers，实际运行预算与实例/端口/卷清单在准备后由root另锁；截图仅开始/结束必要证明，不循环dump画面。保证停采样、取证、卸QA/关AVD/私有ADB及精准down新QA项目，复核原试玩/health/operator和共享未变；保AVD、镜像、命名卷与证据。

## Risks / Trade-offs

### 2.1 正常入场的有界人工核定

2026-11-13 root：复用已验正常客户端UI动作，相关1076/1077界面依赖由test_lead逐项核同源。新owner在`before_launch`完成、调用正常`pump/start`之前只留一次最多60秒的test_lead证据核定：检查本轮场景截图及同房手机六机准备状态后，写本轮确认marker。未知状态或超时即保首错并退出，不重发输入、不重新开场。该等待计入owner总预算，不增加逐页人工暂停或图像识别框架。启动集合后，真实三席、战中指令、唯一采样自动衔接，避免模型往返消耗集合窗口；实际PID、同场状态和开始/结束画面仍须最终审查。本决定只限定编排，不构成服务、设备或采样运行许可。

**a1后有界修订。** a1的login-entry是Android启动图，base-loading/base-ready仍是Godot启动图；账号坐标输入早于表单可见，最终prelaunch画面未登录。门正确拒绝，没有launch/record；不能据此判游戏登录失败或FP权限失败。原a1脚本、plan、锁、图与结果留原样，已用授权关闭。下一修订只在任何账号输入前加一次最多60秒的表单就绪门，经原device controller最多3次只读截图供test_lead确认本轮真实可见登录表单，再执行原登录动作；未知/到期停止，不重发输入。它和原prelaunch门都计入600秒工作上界，集合后仍不暂停；不能仅延长sleep、增加CV/包导出或恢复SF路线。新的执行须新数据/新实例及root单独门，本修订不授权重跑a1。

依据：[Android官方测试稳定性说明](https://developer.android.com/training/testing/instrumented-tests/stability)建议按UI具体条件同步，固定sleep不能消除异步加载不确定性。本项目采用有界真实画面核定；没有声称Espresso能直接识别Godot绘制控件，也不为本项接入新框架。已验符号、未变源/peer检查按断言依赖复用，不重跑无关矩阵。

**a2线程字段修订。** a2尚未确认首次表单时，root追加的一次只读`ps -T -p <实际PID> -o PID,TID,NAME`显示所有NAME均为包名，原识别器无候选，按门停止，未手机输入/launch/record。不能由此认定渲染线程不存在、GLThread名称实有空格或FP不可用。[Android15 Toybox主源](https://android.googlesource.com/platform/external/toybox/+/android15-release/toys/posix/ps.c)中NAME是argv[0]、COMM是exe文件名、CMD才是线程stat名称。仅修为明确PID/TID/CMD字段并保留名称内部空格，验证表头语义及同PID唯一GLThread；拒绝包名列、空候选或多候选，不猜TID。新增必要负控制应复用a2真实原输出，正向空格名称控制只算纯解析证明。保持原表单/六机门、采样参数和收尾；下一实际门须在prelaunch安全阶段确认该正确字段有实际唯一目标，不带已知资格问题进入战斗。不重新验证未变符号、peer或MMAP工具，不临场热改锁。

- 符号ZIP并非匹配构建或缺函数 → SHA/BuildID/地址控制门先拒绝，无设备成本。
- 官方release可profileable但实际系统事件权限不同 → 实际准备明确核，不靠manifest宣布可采。
- 正常编排携带旧SF/版本/数据路径 → 仅复用经过调用链检查的部分，源锁与新数据清单隔离。
- 低频采样仍有干扰或只见少量leaf → 原样记录有限结论，不推新P95或自动加轮。

## a3后的启动连接范围评审（2026-11-14）

状态：**2026-11-14 root带约束通过，仅允许下列工具实现；尚不允许正式测试或资源执行。** 已审[文件级设计](../../../build/architecture-review/m06-startup-design-input.md)、[独立预选](../../../build/architecture-review/m06-startup-test-input.md)及原normal_stage/normal_owner、实际派生common/service/device/supervisor和c88 Handler/main调用。最新实际证据是[停止交接签收](verification/root-normal-a3-handoff-review.md)：Android compat失败，无账号输入、现场CMD资格、launch、record或分析。原a1–a3目录、锁和执行结果保持不变；不补建旧实例追造请求证据。

本次玩家/研发问题是无法区分正常客户端启动连接在哪一段失败，直接跑完整采样既不能回答该问题，也消耗设备和服务时间。主责M06诊断工具，关联M00传输/资源生命周期；不修改生产游戏、c88业务逻辑、原APK、端点、HTTP协议、预算或采样参数。1077只支持未变战中渲染链的热点归因，新集成候选仍须另验性能。

### 归属、组合和生命周期

- `normal_stage`拥有create-only独立工作目录、原件锁及明确派生接线，不启动资源。新观测脚本也必须纳入输入/派生锁，禁止在运行中热改。
- `normal_owner`拥有启动流程顺序、首次失败与统一deadline。拟增加限定startup/preflight入口，服务就绪后只启动一个AVD及原诊断客户端，在真实表单门停止；跳过新账号/大厅/peer/开场/录制/离线分析，必须查清device helper隐藏依赖才能签实现。
- QA服务适配只拥有exact `GET /v1/beta/compat` 的最小传输观测，不拥有业务、数据或重试。优先组合现有服务入口与QA Handler子类，保原Handler及所有生产字节。禁止增加代理、换端点或改网络路线以绕过未知错误。父类`do_GET = do_POST = respond`别名须按真实调用处理，不能仅覆写同名`respond`后声称已观测。
- 服务owner负责核真实CID/标签，在自己的down之前保存服务日志/metadata，记录取证错误后仍执行精确清理；不能依赖外层owner在容器删除后取证。device owner负责在卸包/关闭AVD之前保存logcat；统一编排不替代各资源的清理所有权。
- 生命周期为新W/锁→单独运行门→服务新卷→观测注册→Android启动/表单核定→成功或首错→各owner保全证据→清理→资源终态。失败、超时及手动终止都保首错，不自动点重试、不再次启动整场。

### 证据和隐私合同

只允许固定路径、方法、事件ID/实例、时间、状态及处理阶段/异常类型等必要metadata；不记录请求header、body、口令、token或任意URL/query。明确区分请求到达、handler返回/写出以及客户端实际收到；不能由服务端返回推断Android成功。主机健康读和手机读的关联方式须在文件级设计中说明，不能仅凭IP或相近时间强认来源。字段、取证时限、存放和缺证语义由主代理审后锁定。

通过条件分两层：先由开发提交限定工具差异/必要自测；test_lead独立核正常/异常观测、日志失败仍清理及敏感信息边界，再由root签新锁下的Android startup资格。原符号和未变peer证明按依赖复用，不下载符号包或机械重跑。只有手机连接/表单资格充分后，才评审唯一正常场与现场CMD/record门。源码静审或工具通过均不构成M06帧预算通过。

只读输入：[工具边界](../../../build/architecture-review/m06-tool-boundary-input.md)、[恢复测试预选](../../../build/architecture-review/m06-resume-input.md)。真机/声音终验遵循[负责人安排](../../../AGENTS.md#负责人终验安排)，交付完整可玩版后由负责人执行，不增加本项设备要求。

### 主代理实施签收与约束

允许执行源仅本change `verification/tools/normal_stage.py`、`normal_owner.py`，新增`compat_metadata_entry.py`；配套本工具源锁/README、精确差异/开发自测证据和一个有界组件资格入口。不得修改game、services、c88、原ORIGIN/helper、APK、旧run、采样器或符号工具。实现前先保存本轮三个执行源的前像/不存在记录；按实际差异回审，不按文件数断言质量。

采纳固定`normal|startup-preflight`两模式，startup只启一个profile/一个AVD/六个profile原依赖新卷。common.gate/服务集合与数量/端口检查只在startup派生调整为固定单profile，normal派生保持原合同；禁止泛化任意服务注册。startup的device只允许受限截图及原控制通道done，免账号文件依赖，不制造空账号夹具；不调用phase.prepare/lobby/finish、peer、normal_flow或采集/分析。QA子类在独立进程绑定`server.Handler`后复用原serve main获准，业务文件不变；serve参数必须限制到本轮已锁配置，不转发backup/restore。

metadata只记exact compat的arrived/handler_return/exception、状态及有限标识/时间。host专用非认证标识仅作内存相等分类，绝不保存header/标识原值或把缺标识视为mobile身份。host对照完成并关闭后建立串行屏障，之后不发host HTTP；结合真实表单与Android日志，仅签受控启动关联。运行前保存固定image、合成配置及真实CID的Healthcheck事实；发现额外compat探针则停止回审，**不得临场禁用或改探针**。不用代理、改端口/路由、wfile/socket包装或强制flush来取得成功。

服务取证在精确down前、同mutex内完成；supervisor在精确包身份核定后且force-stop/uninstall前保存logcat，解决controller/abort竞争。日志失败单列，仍执行清理；owner最终分别判观测完整性、表单资格和清理结果，不能因资源清理绿或表单出现而掩盖缺证。原始服务日志若含非白名单内容，仅保受限本地证据，公开报告只用白名单metadata/错误类型，不丢弃失败原件。

预算为公共工作300秒＋清理100秒、外层硬420秒；单组件资格≤40秒。**共同截止须实际传至device/supervisor及子命令，不能服务、boot、安装和表单各自从零叠加预算。** supervisor按owner本轮截止计算剩余工作/收尾，取证8/12秒计入清理；outer Job结束后仍须验证同身份子树、AVD/私有ADB、CID/网络及端口终态。任何需要超出上述入口、运行模式或生命周期的实现先回审。

本签收批准开发与必要无资源自测，不批准组件正式执行、AVD/ADB/Docker启动或第四次正常场。开发交差异后，test_lead按改动提交独立资格命令/新锁/root运行门，root审完再执行。原符号/peer准备按断言依赖复用；2.2采样及M06性能仍未通过。

**实施审查补正（同范围，2026-11-14 root）。** 正式执行前修两项已定位的工具缺陷。第一，startup最终只读汇总须核device-cleanup的normal/supervisor退出、host必需字段/无观察错误/设备监听空，以及avd-session清理errors/正常释放/实际AVD核名；缺证单列并拒绝passed，仍先完成既有finally，不用手工终态补绿掩盖自动汇总问题。第二，Windows屏障UTC和Docker事件UTC没有已证误差界，不能跨域作区间比较。采用同一服务journal前缀屏障：最后host健康GET完成并关闭后，仅有界读取日志（≤2秒，计入公共工作截止），确认本instance完整host_control事件对、末次200、无未归属/未完污染；保存前缀行数、规范化语义SHA和末次terminal ID，然后才启动device且禁止后续host HTTP。最终取证验证该前缀/顺序未变，只对其后日志后缀作受控启动关联，拒绝新增host_control；UTC只展示，不声称host结束时刻精确截断VM事件。复用同一日志解析机制，不能提前占用最终create-only取证文件，不新增代理/时钟同步框架。仍只改原批准stage/owner源及必要控制，保本次差异/旧交付证据；最终锁由test_lead统一，正式执行门仍待签。

### Startup采证生命周期复审（2026-11-14 root，仅工具修订）

最新[真实a1交接](verification/root-startup-native-a1-result-review.md)未完成表单资格，且客户端记录超时；不能只因服务返回200认定启动成功。现确认一个工具边界错误：startup没有后续玩家输入，却复用了normal入场的实时人工确认门，导致观察者往返耗尽窗口。**本节取代startup的实时表单marker门；normal账号输入前及开场前门不变。** 不以延长窗口、改产品超时或重试按钮解决。

root带约束批准原开发方仅改`normal_owner.py`的startup分支、配套README和必要纯控制：device-ready后自动取最多三张只读图，按同一owner monotonic的0/20/40秒采证点、共同60秒采证界及原work300界执行；每次截图仍受原命令时限及实际剩余约束。记录实际时刻、PNG路径/SHA和未完成原因，结束后立即按原finally收尾。不读decision、不等待模型、不发触控/账号/重试；固定采证点只用于取得不同阶段的原始证据，**不作为界面就绪判据**。不引入CV/OCR、检测框架、事件总线或新管理器。

资源owner只裁定执行/采证与原journal/清理完整性。startup结果独立给`execution_passed`及`ui_qualification=pending_offline_review`，总体`passed`在待审时必须为null/未定而非true；执行失败为false并保首错。成功采证后可exit0，不能因此称startup资格通过。test_lead在资源收尾后离线审本轮PNG、日志及实际场景，另写UI判定证据/报告，root最终签收，不改原始执行结果。只有真实表单足以核定才算UI通过；黑图/错误页/缺图保持未通过或未完成并说明依据。

normal模式的实时确认/账号输入/战斗序列、stage单profile资源合同、metadata入口/协议/采样器均不改。必要纯控制执行实际采证函数，用受控时间/文件边界验证三次上限、截止拒绝、不等待人工及失败仍清理，不冒充真实Android。test_lead维护相应执行编排与离线判定入口；既有HTTP组件按真实依赖未变复用，不重复五组。旧a1真实失败/门/源码/锁保原，修订交回后再锁新W/门，不在原目录热修或重跑。

### Normal唯一采样恢复AR（2026-11-14 root，工具实现许可）

状态：带约束通过，仅下列工具修订，不授权新W或实际运行。[a2组合根签](verification/root-startup-native-a2-result-review.md)提供真实表单与Job后资源闭环，原失败和客户端超时保留；不再为了startup汇总补跑AVD。已审[normal恢复预选](../../../build/architecture-review/m06-normal-resume-a2-input.md)、原UI plan/device IPC与native_collect实际调用。仍以正常旧1077的有限CPU归因为目的，不改变最终新候选验收要求。

归属与组合：normal_owner拥有候选采证→输入许可→现有UI动作→开场许可→单次采样顺序；native_collect拥有平台/线程识别与采集机制；service/supervisor各自拥有销毁前取证。采图原语可为startup和normal共用，但诊断待审与输入前正向授权分别由模式调用者裁定，不能合并其后续状态机。

1. **候选与许可分离。** normal在device-ready后复用原startup_capture三图0/20/40/共同60秒，不改该原语。完成后仅用最新候选图及其原SHA/PID/窗口/时刻发布一次确认门；保持原三字段accept决策合同和一次create-only门。root选择保留原人工上界60秒（不是预选建议30秒），实际确认就立即继续；近期观察往返曾超过40秒，不能以缩短门增加无效重跑。未知/最新错误页/非表单或到期直接abort，无第四图/自动accept。计时和本次旧图本身均不授权下一轮输入。
2. **不改总预算或动作。** normal仍600工作/100清理，未来outer≤720；两个人工门与候选都计入，record前≥175秒硬储备。before_launch不增加/删减/重排动作、等待或截图，仅在唯一`snap:base-ready`之后切为登录/基地、入房/选机两批现有send；合并回原序列必须逐项完全相等。每批服从现device IPC55及owner调用60秒/剩余界，不单方面放大超时，不添中途人工门。私号/lobby仍用本轮生成器；原lobby3600秒及pump窗口1200秒覆盖600工作，无需改业务期限。
3. **已知资格前置。** native_collect提供一次只读preflight入口，在开场许可之前核实际API/内置simpleperf帮助/事件、APK身份及同PID唯一GLThread的CMD/线程starttime/焦点，保存独立`test/native-preflight`原件；不创建`test/native`、record-attempt、远端perf文件或启动采样。原实际平台/identity读取逻辑可提成共享函数，保唯一CMD解析、不猜TID；normal_owner只调用该入口，不复制线程解析。record仍在真实同房战斗内重新读当时PID/TID/starttime与焦点，前后比较，不能拿preflight的旧TID直接采。单次30秒/79Hz/task-clock:u/FP及原MMAP/BuildID/lost/清理/离线分析机制不变。
4. **normal失败取证闭环。** 原a3删除后logs失败不能沿用。normal派生service在既有mutex内、核实际所属CID后、down之前有界保存两服务原stdout/stderr到本地受限日志和结果；取证失败单列，仍精确down。仅raw日志保存，不给静默c88伪造每请求metadata。normal派生supervisor在核AVD/本轮包SHA后、force-stop/uninstall前借用原collect_log；成功/失败路径都不能只依赖controller先到finally。复用现有startup做法，保持startup派生输出合同，不能修改生产Handler或加代理。

允许执行源仅本change tools的`normal_owner.py`、`native_collect.py`、`normal_stage.py`，配套README/差异/必要纯控制；不改UI plan字节、产品源/数值/资源/native、原ORIGIN、旧run或已归档证据。normal七helper中只准service/supervisor上述取证差异，其余合同保持；不把“全字节不变”的旧结论冒称覆盖新取证hook。SDK退出helper过早快照缺陷保工具限制，normal不调用startup_observation，不为它扩修主干。

开发须保前像，证明原record argv/参数与错误/清理机制不变、实际候选许可前零账号输入、reject/超时不进UI、批次合并同原plan、preflight无record路径及失败仍清理；纯控制不冒充Android/ENet/FP通过。不加通用框架/新manager。符号、未变peer和HTTP组件按真实依赖复用，CLI新增只读资格不触发大矩阵重复。test_lead独立审差异/新锁/新W资源计划后root另签唯一实际正常场；旧批准不复用。

### Normal失败取证与终态汇总补正（2026-11-14 root）

开发交回后，root与test_lead独立静审确认两处缺口；在上述三工具范围内退原实现方修订，不授权stage或运行。service持有容器清理动作及实际删除账目，须先保存deleted_ids/count/remaining/volumes和resource_cleanup_passed，再独立判断日志完整性；日志失败不得跳过已发生删除的记录，也不得因资源已清使整体通过。owner在device Job结束后持有最终汇总责任：仅normal分支核device-cleanup正常退出、avd-session核名/正常释放/无errors和卸包前日志结果及原件存在。supervisor仍负责卸包前采证及失败后继续清理，不以Job退出0替代该合同，也不按final日志文件名推断时序或补绿。

不增加全机emulators为空的判断，不改startup派生、采样参数、生产逻辑或UI plan。保上一交付原件，新修订记录增量差异及必要纯控制：日志失败仍落删除账目且整体失败；Job0但取证缺失/AVD错误拒绝通过；完整终态通过。由test_lead独立审最终源后统一新锁，root再决定stage与实际执行许可。

### Normal单请求回执读取AR（2026-11-14 root，带约束通过）

依据[实际a4失败根签](verification/root-normal-a4-result-review.md)和[28行只读输入](../../../build/architecture-review/m06-device-ipc-read-input.md)。已证第三截图完成后send打开reply.json遇errno13，未证具体拒读方。主责M06测试工具IPC：controller拥有动作执行/回执发布，send拥有一次提交及等待；common提供现有原子发布/读取，上层owner串行组合与截止/清理。job消费即删除不是互斥；当前只保证同一send未完成不发下一批，不能推广为并发或跨请求恢复协议。

允许原开发方仅修改tools/normal_stage.py中normal device.py的send派生读回执段及必要交付/纯控制，保ORIGIN、common、controller、owner、UI plan、native、startup派生不变。依赖方向及生命周期不改：核身份/ready→删除旧reply→仅发布一次job→在原55秒monotonic及更短caller/总截止内等待→消费有效回执或失败abort→原清理。只围绕同一reply的read捕PermissionError/FileNotFoundError；保持原循环sleep及身份核验，允许继续读取同一路径，不能重建job、重发UI、重启app、删新reply、重置期限或把未知结果认作未执行。

有效reply仍先消费，避免done已发布后controller正常退出导致误拒；无有效reply/读失败后须核原PID+创建身份，失活即停止。坏JSON、编码错误、缺ok、negative reply及其他OSError不吞、不重试。保有限读失败诊断（错误类型/次数与时刻，不记账号/请求或回执内容）；不为诊断新增框架或改变业务成功语义。原调用者16/60秒及总界保持，不加等待预算。

开发保前像/精确差异，必要纯控直接执行实际派生send：短暂拒读后成功且仅一次job发布；持续拒读按原界失败/abort；exists后消失；controller/supervisor身份变化；有效done先消费；坏JSON/negative/缺ok立即失败。区分假边界控制与真实进程动作，不把一次发布断言称真实UI只执行一次。startup派生字节不变，normal新device合同单列，其余未变依赖复用。新并发、取消后继续请求或迟到回执恢复须另审request关联与失效；本次不扩协议。

本节仅准实现/必要无资源开发控制，不准修改旧a4、锁/manifest、创建新W、正式组件或Android运行。test_lead独立审实际差异与最小资格后root另门；符号/peer/HTTP资格不机械重跑。M06采样及性能仍未通过。

### a6后的应用进程采样AR（2026-11-14 root，带约束通过，仅工具实现）

依据[a6实际失败交接](verification/root-normal-a6-result-review.md)、[34行目标边界输入](../../../build/architecture-review/m06-process-scope-profile-input.md)、[独立预选](../../../build/architecture-review/m06-process-scope-test-input.md)。本节替代正常场preflight/record/解析的“唯一命名GLThread”目标假设；原单线程授权/失败记录仍是历史，不在旧a6 fallback。主责M06诊断工具，目的仍是已知帧预算失败的CPU归因，非产品或网络修复。

**归属和依赖。** collector持本轮应用/进程身份及一次录制/精确远端清理；native_addresses持实际dump记录/地址映射与严格结构；analyzer消费该结构做归因及分母守恒；check_normal_native是直接调用这些真实边界的控制入口。保原owner/资源生命周期及UI plan，不把目标选择放到游戏、服务器或M01菜单。唯一允许四执行源：tools/native_collect.py、native_addresses.py、native_analyze.py、check_normal_native.py，及必要README/差异/控制。不得改owner/stage/共享process_owner、产品、APK/native/端点或旧run/锁。

**目标及身份生命周期。** 默认目标改为一个实际包进程的全部线程用户态CPU，CMD只是观察标签。preflight读取唯一实际PID、/proc/PID/stat field22进程starttime、完整PID/TID/CMD原表/焦点及已装APK；接受a6两个同名条目，不选首项或猜角色。进入战斗后重新核身份，不能沿用preflight PID；record后核同PID/starttime/实际APK，不认领重启后的新实例。保前后TID表和增减，允许自然线程新生/退出。

每sample保pid/tid/time；分组是**raw(pid,tid)样本桶**，未解析/证明COMM/FORK/EXIT代次时不能称单一连续线程生命。前后CMD只列observed labels，新生/已退出/可能复用标未知，角色不能按名称/末尾数字推。全原dump及生命周期record计数保留；本切片不为命名加逐TID ADB探针或新APK线程埋点。进程总量归因不依赖猜出main/render身份。

**唯一命令。** 将-t TID替换为-p数值实际PID及--include-pid同PID，保--app原包、默认inherit、task-clock:u、79Hz、FP、30秒、单record-attempt/原路径/Job和失败不补轮。不用regex/-a/--no-inherit/root/run-as手工替代、频率或DWARF fallback。a6实际help包含这些参数；AOSP Android15源解释显式PID/线程继承/样本过滤，但不等于本设备profileable权限已实录。首个真实命令失败即停，不另开试录。只读资格核当前API/工具help/版本及实际SHA（a6 ad92cd4a9fac83ee8311b1485cd78df812fdf5072dea41042804f5aad6b353c7）；漂移回审。

**解析与归因合同。** parse_dump使用显式process接口(text,pid)，不加旧capture JSON适配；旧错tid负例改同PID多tid可分桶，错pid样本仍拒绝，不能静默丢掉或混入后假绿。非目标MMAP仅计数，不参与目标地址；同进程所有TID共享按原record顺序更新的MMAP空间，保部分替换双尾/pgoff，不用未来mapping解释过去sample。实际库SHA/BuildID/APK offset/PT_LOAD及真实STT_FUNC区间保持，同文件矛盾BuildID拒绝覆盖。

报告同时给进程总计与各桶samples、leaf/inclusive、library/unknown及FP深度/caller覆盖；线程samples之和等于总量，同函数inclusive每sample去重并可跨桶汇总。某桶有caller不能推全部桶FP完整；全局LOST/未知LOST保原约束，不捏造逐桶lost=0。无样本/无任何caller或无可核Godot映射仍非有效归因。全进程LLVM地址共享去重，累计90秒，不逐桶重置。CPU样本数不是ms/FPS/P95、GPU或墙钟等待；全进程CPU不与不存在的旧单线程样本作数值比较。

**预算、组合与准入。** 原600工作/100清理/outer720、175秒录前储备、录后75秒取证及90秒LLVM不增；多线程开销/样本增加照实，超限保首错/原data后按同远端身份清理，不临场减频补轮。原三席24起始/自然损失、两人工门及未变资源/peer/符号资格按依赖复用；不再做M01菜单观测。

开发保前像/差异，以真实函数直接控制：a6双同名ps可完整接受；多PID/坏表头/进程换代/错误APK拒绝；严格argv/一次record/失败仍清理；双TID及新TID分桶、外PID拒绝、跨TID共享和部分替换MMAP/旧sample时序、冲突BID/未知LOST、总量和分组守恒/无caller与unknown边界。只准实现与必要无资源控制，正式资格、新锁/stage/设备/服务/record均待test_lead选集与root另门；不把控制绿或选项存在当实际采样通过。

**分析有效录制门补正（2026-11-15 root，同四文件范围）。** 独立静审确认仅判断capture.record_job非空不足以证明成功录制。analyzer在读dump/映射前必须核该Job的exit_code=0、timed_out严格false、job_pids_after_cleanup和same_instances_still_alive均为空；缺字段或任一失败即拒绝完整窗口分析。此门归analyzer的输入有效性，不上移到人工root审查替代。不要求capture总体passed/cleanup_errors全绿：原始record有效但后处理失败的情形仍由root另门分开判，raw与原失败不改。保刚交付原件后仅补必要guard正负直接控制，不重跑无关矩阵/做格式整理，不新增资源许可。

### a7后的固定场景夹具AR（2026-11-15 root，带约束通过，仅工具实现）

**问题与归属。** [a7根签](verification/root-normal-a7-result-review.md)已证固定(200,324)没有选中本轮泵站。真实`pump.event()`以PUMP_EPOCH产生窗口start，再以其hash选择三处SITES；normal service每轮设now-1，场景可不同，无需跨日。world按固定节点顺序确定性避让，pump在固定节点后、treasure前加入；后加treasure不反向改pump位置。M06测试场景生成拥有epoch选择与新数据；M18/泵站领域继续拥有事件位置/开放/seed，页面拥有呈现。无需改产品位置、导航或时钟，也不新增通用自动点击/OCR/人工坐标框架。

**允许范围与依赖。** 原开发方仅改tools/normal_stage.py的normal service派生及必要纯控制/交付证据。ORIGIN、生产/冻结源、UIplan、owner、device、native、startup/existing-diagnostics派生保持不变。fixture引用当前已锁rc1077泵站/日历合同，只生成新的合法测试配置；不写旧数据、不迁移、不重用旧场次。若发现固定site/现日历/相同viewport仍不能保证目标点击可用，先返回本AR，不能顺手改布局或追加触控。

**生命周期与合同。** 唯一up在原截止内读取一次参考now；只在过去1..32秒固定候选中按最近优先选择能生成既有雾桥site(.32,.69)的epoch。无解立即失败，不扩大搜索、换site或等待未来epoch。保PERIOD1800/DURATION1200；记录参考now、候选界、chosen epoch、expected start/seed/site、实际冻结日历SHA与来源合同。选择时余量须至少1100秒；此限制远大本轮600+100及外720，不改变原操作/清理预算。

启动原两服务、compat/空库/源核验后，在同service up及其原90秒调用预算内通过该实际profile CID只读调用一次真实pump.event()，核start/seed/site/active/period语义及剩余至少1100秒；失败进入原primary-error/down路径，不创建账号/场次、不补查询或重试。返回事件原件进入service-check，不能仅靠选择算法自证。服务成功后沿既有账号/大厅/两UI门/一次record生命周期，最终原精确清理不变。

**抽象与验证。** 这是有界可复现场景夹具，不是新的事件策略，不为它造通用环境框架。开发保原件/精确diff，直接控制实际派生选择器在多个参考时刻选首个合法候选、无解/不足余量拒绝；以锁定真实pump.event验证而非复制函数自证。实际服务响应错seed/site/start、inactive/不足余量须在原up失败路径拒绝且调用清理一次。核normal除service变化外不变，startup/existing派生字节不变，原预算/端口/清理无改。假docker控制不等于正式容器通过；test_lead独立审最小无资源资格，再另锁新W与运行门。不重跑符号/未变peer/默认CLI四组，不开a8或产品构建。

### a8离线BuildID格式AR（2026-11-15 root，带约束通过，仅解析器）

实际a8录制/收尾已[限定签收](verification/root-normal-a8-capture-review.md)。首次唯一离线CLI在读Godot MMAP BuildID时报错，原失败保留；dump.stdout:30089真实值是`build_id 0x383f9a53682e9f08000000000000000000000000`。当前native_addresses.py的未锚定正则只截出0，并非证实实际native身份不符。现有原ELF/SHA/BuildID与capture不改，不再录制。

M06 dump解析器拥有输出文本到完整BuildID的规范化；analyzer继续拥有映射/同构建/record有效门，采样器不为解析错误重录。允许原dev只改native_addresses.py的BuildID值提取：整行匹配、可选单个0x前缀、完整合法十六进制值，内部存无前缀值；保原无前缀格式。空/双前缀/非法字符/尾随垃圾必须拒绝，不能退回部分前缀；同文件规范化相同ID不冲突，不同仍拒绝。same_build、ELF/PT_LOAD、MMAP时序、sample/PID/TID/LOST、符号和其他工具代码不改；不放宽BID匹配或用SHA代替实际BID。

生命周期仅离线读不可变dump→严格解析→保原身份门→现映射/LLVM；失败保原件并退出，原全局90秒LLVM和Job预算不改。开发保前像/精确UTF8 diff，必要无资源直接控制实际整份a8 dump可得完整Godot ID；带/不带前缀同值、冲突、非法整行拒绝，并确认sample/MMAP/TID/lost结果未改。不重复符号/Android/旧完整矩阵，禁止修改实际capture/dump/旧analysis失败或旧锁。test_lead独立静审后root另签新分析输入锁/新输出单次CLI；不原地覆盖或自动重复。

## Technical references

[Godot同构建符号规则](https://docs.godotengine.org/en/4.6/tutorials/platform/android/resolving_crashes_on_android.html)；[4.6.1官方发行](https://github.com/godotengine/godot-builds/releases/tag/4.6.1-stable)；[Android profileable准入](https://developer.android.com/guide/topics/manifest/profileable-element)；[Google simpleperf流程](https://android.googlesource.com/platform/system/extras/+/android16-release/simpleperf/doc/android_application_profiling.md)。官方文档不替代本机BuildID和实际采样证据。
