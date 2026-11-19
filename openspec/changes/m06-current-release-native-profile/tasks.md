# Tasks

M06/P0原生CPU归因。保持1077+r2/33.333ms预算；主代理规划签收、开发实现、test_lead独立正式执行及清理、进度代理原页维护。

当前状态补注（2026-11-15）：a8实际录制/清理与同一份录制的修订解析已通过有限签收，642样本/5桶/全局LOST0且覆盖限制明确；[切片出口7/7](verification/root-native-profile-exit-review.md)，只代表工具及归因完成。下一为履带动画轨道切片真实导入调查，生产修改须第二门。原P95仍失败、M23仍1/5，不作整款/新候选通过；下列历史失败保留。

前序状态（2026-11-14）：M01既有诊断a2已[限定根签](../m01-startup-connection-observation/verification/root-run-a2-result-review.md)：实际1077诊断页显示10.0.2.2:33480/协议就绪，返回未认证表单，单CID/网/4Job/监听清、622/11与十共享同。空prelog不证明无ERROR，旧间歇连接错未定因；不是认证/CPU/FPS通过。工具owner已修真实子入口依赖，并有[fresh解释器实际导入资格](../m01-startup-connection-observation/verification/root-import-result-review.md)。

normal-a6已[实际到达手机同房6机/12点Ready，但因同PID双GLThread名拒绝采样资格](verification/root-normal-a6-result-review.md)，未发布第二门/开场/record；2CID/网/4Job/监听已清、十共享1040/11同。已在design新签应用进程采样AR，新增2.3前置（当前3/6仅准备），只准四工具实现/必要无资源控制，不许旧a6补录或新W/资源。2.2仍无CPU样本，原P95失败不变。M01暂未归档，避免其固定源入口被active装配/锁引用失效。

历史[a5连接失败主动停止](verification/root-normal-a5-result-review.md)、[a4 IPC读取失败](verification/root-normal-a4-result-review.md)、[同回执组件资格](verification/root-ipc-component-result-review.md)、[startup-a2组合限定签收](verification/root-startup-native-a2-result-review.md)及a1–a3原失败均保留，不回填原passed或抹旧错误。不改产品参数/强制retry，不混入M01三动作。

## 1. 同构建符号离线门

- [x] 1.1 开发代理提交现有正式/正常诊断APK的profileable/native/BuildID及模板身份、旧工具可复用与不能原跑的实际引用；实现最小官方符号获取/校SHA/目标ABI安全解包/ELF匹配与地址控制入口，交源锁/必要边界自测/确切命令和缓存预算。开发不下载大包/启资源，root审后才交test_lead运行离线门。见[实现签收](verification/root-development-review.md)；该签收仅静态，后续实际结果见1.2。
- [x] 1.2 test_lead审输入及实际磁盘/工具/本机缓存后，按root单独门一次获取或复用已验官方包，核SHA/x86_64 BuildID/函数地址及错BuildID拒绝，提交原始命令/结果/覆盖与资源终态，root独立签收；不启动设备/服务/数据库，也不把符号可用当性能通过。见[root离线签收](verification/root-offline-review.md)，真实匹配/三地址及负控制通过、两Job空，缓存约1.443GiB保留；未采样。

## 2. 当前正常战斗的唯一采样

- [x] 2.1 符号门通过后，开发代理最小适配正常客户端入场/peer/采样/清理，移除SF/旧1076上下文依赖而不改生产；test_lead提交独立静态/必要准备证明、现成1077诊断APK与实际源/镜像/工具锁、新数据/实例/端口/预算及采样有效性标准，root核后另签实际运行门。见[静态签收](verification/root-normal-development-review.md)与[实际准备/单次门](verification/root-normal-prepare-review.md)：唯一check-only 0.323秒、总11.288秒，子树空；正常场与采样仍未运行。
- [x] 2.3 作为2.2新前置，原dev按design应用进程AR只改四工具/必要控制，交前像/diff/真实双名ps与PID换代/严格argv/双TID映射分组/BuildID冲突/LOST及分母守恒直接控制；test_lead独立审新target/parser/analyzer与旧资格复用，root签后另锁新W/一次真实命令。见[默认入口与a7准备签收](verification/root-normal-a7-prepare-review.md)：实际默认CLI四组通过、两空树/11保护不变，M06现4/6；单次a7实际权限/样本待验，不改产品/预算/旧a6。
- [x] 2.2 待2.3及新门后，test_lead在新数据正常泵房单场执行一次30秒79Hz锁定应用PID用户态FP采样，保实际PID/process starttime/前后线程表及同场状态/数据/BuildID/lost/错误并同构建离线解析；按raw(pid,tid)桶和进程总计记录leaf/栈覆盖/函数分布与身份限制。见[a8有效归因有限签收](verification/root-normal-a8-analysis-result-review.md)：同一份录制修复格式后离线解析，642样本/5桶/FP476与166/全局LOST0，资源与保护已核；不再宣称唯一GLThread或FPS通过。

- [x] 2.4 a7导航失败后，原dev按design固定场景AR仅修normal service派生的有界epoch夹具及实际事件核验，交真实合同控制/差异；test_lead独立审最小资格，root签后才另锁新轮。见[独立静审](verification/test-fixed-site-static-review.md)与[源码限定根签](verification/root-fixed-site-tool-review.md)，5/7仅工具准备；真实up/导航/CPU/帧预算未过，不扩大产品范围。

  a1已执行但在prelaunch门拒绝：账号输入时仍启动图，未launch/record/分析，保原失败见[test_lead报告](verification/test-normal-a1-report.md)。2.1的headless准备通过不变，2.2保持未通过。先由原开发方按design补一次首次表单就绪门并交差异，test_lead审范围/新输入锁，root再决定新数据独立轮；不得原地重发a1或重复符号/未变peer验证。

  a2的首次门阻止手机输入；一次只读线程资格显示NAME列实际为包名，原识别器不能取目标，按门停止，未launch/record。见[实际报告](verification/test-normal-a2-report.md)及[root签收](verification/root-normal-a2-review.md)。仅按design修CMD字段及保空格解析，下一轮在安全prelaunch阶段核真实唯一目标；compat result13记录保留未定因。3/5仅准备工作，不是采样或性能达标比例。

  **原normal流程最后为a3停止，不是a2；与后续独立startup-a1区分。** CMD/header修订已在当前工具中，但a3在任何账号输入前的表单门遇到“连接与版本未能同步”；Android日志为compat result=-1/status=0/err=25。账号输入、现场CMD资格、launch、record及分析均未执行。见[实际报告](verification/test-normal-a3-report.md)与[root停止及清理签收](verification/root-normal-a3-handoff-review.md)。服务删除后再取日志失败，手机请求到达/返回metadata缺失；不得据主机compat成功或err25猜定根因，也不得复建a3补证。后续已评审QA启动连接观测及销毁前取证，不原跑旧整场。只读依据见[工具边界](../../../build/architecture-review/m06-tool-boundary-input.md)与[测试恢复预选](../../../build/architecture-review/m06-resume-input.md)。

  2026-11-14 root已按[文件级输入](../../../build/architecture-review/m06-startup-design-input.md)及[独立预选](../../../build/architecture-review/m06-startup-test-input.md)，在[design实施签收](design.md#主代理实施签收与约束)批准限定startup工具实现，委派expedition_composition_dev。单profile/一AVD/无账号场次采样，日志先于销毁、公共截止贯通；test_lead待实现差异后独立资格/另锁执行门。当前仅开发中，没有正式运行许可，不勾2.2或改变原P95失败。

  工具已交[实现入口](verification/startup-README.md)，root与test_lead独立静审发现终态汇总可能吞掉host观察错误，已退原实现方做同范围修订；测试代理补真实无标记请求来源断言并保前像。组件与Android资格均尚未执行；原开发自检不代正式通过，后续采用最终差异/新锁，旧交付证据保留。

  后续：终态缺证拒绝及同journal顺序屏障已修，组件唯一a1五组通过；原外层监听查询超时仍为passed=false，另准一次netstat补证后由root[组合限定签收](verification/root-startup-component-result-review.md)。无组件重跑/Android/场次/采样；只允许继续新W的startup准备，实际设备门另签，不勾2.2。

## 3. 性能主干去向

- [x] 3.1 root审全部实际证据/失败与资源终态，区分已证可改热点、需要新证据及无效采样；test_lead维护测试索引/限制，进度代理同步原任务/里程碑及下一具体工作。见[有限出口与下一AR](verification/root-native-profile-exit-review.md)，维持M06/F；不把工具或CPU占比当预算通过。

## Workflow follow-up

- 有限任务通过后strict验证/skip_specs归档，修链接但保原始执行JSON/源码/锁，不修改主规格。
- 归档或交接明确已验符号缓存保留用途，无需常驻下载/采集进程；实际优化另据热点定范围，不无限延长本工具任务。
