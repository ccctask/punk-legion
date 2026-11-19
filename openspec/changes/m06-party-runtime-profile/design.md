# Design

## Context

动机见proposal。当前Party由20Hz物理回调推进PumpMission→Sim.step，同回调还保存/同步。1081 a1约340.83wall/270sim；人工九图203.993秒和固定30秒guard等待属于另两类成本。旧Linux短M3无真实Party/ENet/存档，同窗计时不成立且整体失败，不能继承为回调占比。

## Goals / Non-Goals

一次有界真实三席场分账，回答首先应调查Sim、持久化/同步还是回调供给；无终局/安卓/P95信用。没有新玩法、数据迁移、正式代码优化、通用采样框架或旧工装修补。

## Decisions

### 系统评审与落位（2026-11-16 root带约束通过）

主责M06诊断，关联M04模拟/M15合作/M23交付；游戏权威状态仍原Party/Pump/Sim及Profile，诊断状态只归本场探针实例。探针不入checkpoint、协议、库存或战绩。

|职责|允许文件/入口|组合与依赖、生命周期|
|---|---|---|
|固定两服务声明式资源|verification/party-profile.compose.yaml|pin现fd2f Godot/b0eded Profile，不build；两新命名卷/一专网/本轮room key只读/结果spool只读。Compose管理create/stop/remove，不抄Android Owner手写docker-run生命周期。|
|一次运行与资源核属|verification/run_profile.py|只通过现tests/godot/process_owner.py执行固定project/config/cwd/env的Compose及三个headless进程；启动前核新路径/项目/端口/内存/shared；成功失败timeout均先保存原件再同配置down（无volumes），核实际CID/label/net/监听/Job终态。无继承Android Owner、无SDK/route/AVD能力。|
|业务合法场景|verification/profile_scenario.py、verification/profile_peer.gd|独立endpoint合同，复用正常API及现Pump peer模板；三本轮新owner各一次initial_fit加5机/6台12CP，正常Join/Ready/Start和三真实ENet。当前客户端state可决定合法Route/近距校准，不直接写坐标/HP/时钟/stage；不伪造结果。客户端有界自动推进，消除人工图义往返这一混杂因素。|
|临时Party覆盖|verification/overlays/party.gd|消费已审1081对应原party源，函数体逐字保留；薄包装_physics_process/_persist/_broadcast，_send_delta只调用super原实现一次；创建Pump前注入TimedSim。覆盖只挂诊断容器，正式game/net/party.gd不改。|
|实例计数与TimedSim|verification/overlays/pump_profile.gd|TimedSim继承原simulation.gd，step(delta)只super一次；与Party实例组合，在内存按窗口聚合。无Autoload/逐tick日志、无探针checkpoint。|
|定向资格与分析|verification/check_profile.py、verification/analyze_profile.py|核包装调用数/顺序/返回值与错误传播、状态/序列化不污染、计数/窗口/嵌套分账与坏输入；分析只解释实际原报告，不用源码推运行占比。|

复用依据：Android Owner在构造、inventory、acquire、HTTP guard、cleanup均耦合SDK/route，仅跳prepare_auth不够；为两服务诊断扩许多分支不合理。既有services/profile/check_live_party.py是endpoint场景，不是容器资源所有者，也只有标准Party单机小队，不能整套冒本场；可复用其正常HTTP/注册约定。Docker Compose已是项目服务声明机制，以固定配置组合现OwnedJob比复制服务Owner更窄。根compose含build/多服务，不整套启动；现check_live_expedition/soak的down--volumes路径禁止使用。

容量夹具来源补准：严格复用已签Owner.prepare_pump_fixture的新库限定生成器：三个本轮注册owner原各一台、无mission/task等前置下，每人同事务只为五个新robot建立原robots实体INSERT，再调用真实workshop.initial_fit建立parts/mounts。允许这项已用容量生成，不额外公开制造五次、不扣费，不直接填parts/mounts、库存、战损或任务；报告明确混合正常HTTP与新数据生成器来源，不能声称全部由公开API产生。不是迁移或旧数据导入。

### 行为与统计合同

原正式源与两个诊断覆盖的身份分列，实际运行不得称原41源未变。计时使用单调微秒，窗口记录wall、delta和、sim.elapsed增量、物理回调次数/间隙/总耗时/最大值、Sim.step次数/总耗时、persist/delta/full广播次数/总耗时。回调内部与RPC外部调用分开，嵌套计时不相加冒占比；余额只称未归因加探针开销，RPC提交不是传输/接收时延。

原函数参数、调用次数、返回与错误/保存成功门保持。full广播计时只指_broadcast入口调用，阶段变化在_physics_process内直接_full.rpc_id不计入该入口，开销保留在回调未归因/探针残差；不得宣称测量了全部full RPC发送。无需为此修改原函数体增加探针。探针产生无效类型/非有限值/计数矛盾/窗口回退立即失败，不静默补0。聚合有界内存，末尾一次输出原JSON，不逐tick写盘或打印。

### 单次选集、退出与清理

采样首席到齐18友6敌的冷启动/西阀及正常西阀校准后的东阀移动接战，每段至少10sim秒/200有效物理回调；东阀段另需20wall秒。Start后硬120wall秒，整个任务工作上限300秒、清理绝对360秒、外OwnedJob380秒并留既定终止/即时锁后核尾，总最坏不超420秒。准确包若准备不足即止，不延租。未进入第二段或数据不足为部分诊断；以自然/诊断主动停止区分，不要求胜利，不把模拟结果补造成完成。

精确停止补准：host以原HTTP Start时钟+119秒启动固定compose stop party --timeout 1，120为硬采样界，grace期间不补采样。helper可在首个实际started后110秒单调wall作一次正常报告并get_tree.quit，标签为诊断主动停止，host原119界仍优先；启动/回调滞后导致报告缺失则partial，不延时或假设SIGTERM必触发_exit_tree。报告保server起止ticks/UTC与host Start时钟对，分析核采样不越原host120与最低样本要求。无逐tick文件轮询或热日志。

无Android/SDK/collector、无第二实际环境；当前Repair结束并root签清理后才可执行。API未知写不重发；新账号/卷/场次，不迁移。原300sim玩法、后续340peer及帧门不变。异常、超时与取消均由thin runner finally核属down和OwnedJob清理；保卷/镜像/证据。所有配置/探针/源/命令前后锁与原CLI退出码齐，shared不变。

2026-11-16 root补准精确编排：最终执行包用原OwnedJob给run_profile外层380秒；其内worker工作300秒上界（包含服务启动和场景），三headless各有现OwnedJob，均沿同一原始起点/绝对预算。worker退出或超时后run_profile父层finally保存证据并同config down，清理绝对360秒，不把finally放在已被强杀worker内。外层380后原8+5秒终止、20秒立即流式后核，总最坏413秒，小于420共同上限，不累加新的重试或租期。正常失败尽早清理，最后报告来源/范围与实际未完成阶段。

### 分工与准入

开发只实现上表工具及必要自检；交原函数体/语义保持差异、探针注入点/生命周期、实际import与源闭包。root源码审，测试代理独立资格后再root准确单次运行门；root只审原件不运行。结果只指向一项后续生产优化或回调供给调查，不授权探索多个算法试验。

## Risks / Trade-offs

- 探针开销与headless负载不同于安卓：只作服务端归因，不能签安卓性能；计数开销与未归因项明列。
- 120秒内无法覆盖东阀：保partial，不重复到绿；用已得数据明确缺口，再由root决定是否仍值得继续。
- 覆盖件随源漂移：锁实际snapshot与原函数体，差异超计时/实例注入需重新AR；禁止发布诊断覆盖。

## Deployment and retirement

只新数据一次临时Compose环境，无正式部署/迁移。结束删本项目两CID与专网、三个headless Job/后代，保卷/镜像/证据；1077/r2和Repair环境不动。无需回填旧格式或保旧档升级。
