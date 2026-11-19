# Design

## Context

见[proposal](proposal.md)、[产品只读卡及复用补评](../../../build/architecture-review/m01-startup-compat-boundary-input.md)、[独立预选](../../../build/architecture-review/m01-existing-diagnostics-test-input.md)。M06正常场被真实连接发起失败拦截；现有diagnostics页已能提供有效URL及另一HTTPRequest的可见结果。先复用实际1077诊断APK，不新增trace包。旧err25与result13分开，当前不定底层原因。

## Goals / Non-Goals

本切片只完成原入口→一次既有诊断→一次返回的有界采证，区分采证完整、页面观察和产品通过。它不修连接、不证明首帧/线程因果，不运行认证/战斗或CPU采样，不改变产品/服务/路由/代理、超时、线程或读取重试规则。skip_specs=true，纯QA组合不改变业务规格。

## Decisions

### 文件级AR：root带约束通过（2026-11-14，仅工具实现）

主责M01的工具流程拥有菜单/诊断/返回语义及其观察结果；M06工具资源owner拥有单profile/设备、deadline、Job、毁前取证与finally。共享的是两个已存在消费者的资源生命周期，不是产品状态：M06只截图启动与M01现有诊断使用同设备/服务关闭机制而判定不同。允许复用显式callback，拒绝复制整套owner、猴补丁、动态模块加载或新通用管理器。Base不接HTTP/诊断责任，Endpoints/入口/diagnostics生产代码均不修改。

允许执行源仅三个：

1. 本change新增`verification/tools/m01_existing_diagnostics.py`：静态import已锁M06 owner，组合有限流程及专用观察；不自行启动/停止服务或AVD。其main/worker仅用已存在OwnedJob重启同一已锁入口。
2. M06 `verification/tools/normal_owner.py`：worker增加两个成对显式keyword callback（capture含report/run/out/deadline/device_future；observe含out），仅本新mode/本已锁入口可用。默认都省略时现normal/startup CLI和行为不变；不得接受任意CLI模块/路径/eval。M01子worker重新静态提供同两callback，不能在跨进程中序列化Callable。仍由现worker唯一finally推进资源释放。
3. M06 `verification/tools/normal_stage.py`：新增固定`existing-diagnostics` mode，组合现startup单profile派生与固定M01入口，manifest记录固定入口/实际SHA及有限权限。不得把旧startup截图许可隐式改成可点界面。normal七个/startup四个原资源helper派生字节保持，owner文件接口变更单列，不能称整个runtime字节未变；新mode设备send复用已签同回执重读，只许可下述有限动作。不得改ORIGIN/现compat observer生产Handler、owner账号plan/native或源锁。

状态/事务所有者：客户端业务仍由原场景/服务所有，工具只持本轮文件证据与进程身份；无游戏持久写。实际启动生命周期：根签新文件/锁→新runtime授权→现owner建单profile/屏障→安装同SHA APK/ready→初始固定三候选→M01流程→正常done→现finally取证/精确down→Job终态后核资源/签收。任一步未知/拒绝/到期即abort原finally；保已发生输入，不重发。共用运行实例不交M01接管。

### 有限输入与预算

先用现0/20/40秒截图原语保存入口实际终态。M01流程最多120秒，且始终服从原公共300工作截止；不另起预算。三个交互许可各最多20秒并受剩余界：绑定本轮最新PNG/实际PID与焦点、request SHA和单一动作名/坐标，test_lead先exclusive写许可再汇报。只准本轮图中正向辨认的“基地菜单”“连接诊断、版本与反馈”“返回基地”各一次。未知布局、非预期状态或不确定坐标即停止，不猜点/重发；不借此接口传任意actions。

允许snap、上述三次tap、原done；若菜单需要滚动而本轮无法明确定位，记录限制停止，不临场扩动作。诊断打开后固定有界等待并取一次终态，返回后固定有界等待取一次终态；具体12/20秒等待计入120/300，不循环采到绿。初始若auth成功同样可观察，不强造错误。入口与诊断可能在途重叠，保事实，不按跨端UTC强配请求。

不点击任何Retry/反馈/登录/注册/恢复，不HOME/前后台/重复开页。既有理论GET上界入口3＋诊断2＋返回3=8，不新增网络请求或host探针。返回触发原entry._check，不等于认证成功；出现额外请求则记录污染/限制，不篡改产品行为满足上界。

### 观察、失败及释放

复用单profile受控host前缀屏障、原QA metadata与destroy前raw日志/prelog。M01专用observe可调用现纯journal解析机制，核前缀不变/有限事件完整性及原件；**不要求客户端suffix200，也不要求存在客户端arrived**。观察者启动/已验证host前缀及日志保存完整但客户端suffix为零，可如实记录“未观察到到达”，不能称手机未发送或网络哪一段必坏；有arrived时必须核对应terminal完整，不能忽略坏metadata。真实连接失败可以是有效观察。记录entry/diagnostics/return各为成功、错误或未决；只有完整采证且资源关闭才可给execution_passed，产品结论保持独立。缺图/日志/身份、输入来源不符或清理缺证仍失败。

不使用SDK早期全机emulators快照冒充最终泄漏。最终由test_lead在Job后提交本轮AVD/私有ADB/精确CID/完整专网/监听/同创建身份子树终态，保十共享实例、保护文件、AVD/镜像/命名卷。默认原件不可覆盖，失败也先保取证再清资源。观察异常处理同实际future，不因超时再发写入。

### 允许验证与后续门

开发保前像、精确diff与必要无资源控制：default mode不变；callback成对/固定mode/已锁入口；未知/拒绝/过期零动作且finally；每动作最多一次、禁账号/Retry；单调剩余界；无200仍可完整观察、坏metadata不能绿；不吞原失败。M01新mode派生及接口新锁，HTTP observer/符号/peer未变断言复用。假边界不证明Android。

该AR只准实现/必要开发控制，不准stage新W、改执行锁、构建APK或启动资源。交回后test_lead独立审最小选集，root另签文件与一次Android观测门。真实socket或产品trace若仍必要，先写缺证再复审，不在本案顺手追加。

### a1真实导入失败后的依赖边界补正AR（2026-11-14 root）

依据[原失败签收](verification/root-run-a1-result-review.md)。资源worker实际使用process_owner，不能依赖调用者先改sys.path，更不能依赖父解释器路径被子进程继承。最小修订归M06 normal_owner模块自身：在导入common取得固定R后，模块级声明既有固定tests/godot路径并import owned_run，删除worker/main中重复的局部路径/导入。模块自己声明运行依赖，M01只静态组合其API；不通过M01补丁掩盖模块前置，不改PYTHONPATH全局环境/安装包/共享框架。

只准normal_owner.py此依赖前置及必要增量证据；M01入口、stage派生/权限/超时/流程/旧a1不动。process_owner导入仅绑定既有Win32 API/定义类，不创建Job或服务。保本次6206前像与差异，原纯控结果不重标新SHA。

开发交对应最小无资源控制/源证据；test_lead随后提一次≤5秒活动/既有OwnedJob收尾的真实新Python解释器纯导入资格：不得预置process_owner到sys.modules或替换其模块，读取真实common/修后owner/M01入口及共享process_owner，记录实际文件路径/SHA与新解释器身份，绝不调用main/worker/runtime_release/owned_run业务路径或启动Docker/ADB。可用旧a1 runtime common作只读导入上下文，不读取其数据库或恢复任务，不改旧文件/锁/manifest。该资格只验证模块依赖初始化；图许可/零suffix及游戏行为依原未变合同复用。

本节仅准原开发方实现/必要无资源控制；正式导入资格与新stage/新运行仍各待root门。此次真实前置覆盖后再决定新W，不继续碰旧a1。

## Risks / Trade-offs

- 页面只显示摘要、不呈完整errno → 保原log及结果限制，不把新HTTPRequest结果当原请求事实；缺什么证据再确定下一最小切片。
- 可见错误不代表网络根因 → 区分端点显示、同UID第二请求、原TCP日志、时序，禁止盲改线程/timeout/预览。
- 人工窗口/加载可能超过剩余界 → 有界失败并清理，不延长公共300或重复动作。
- 生命周期接口影响旧QA → 只许成对固定mode接入，独立核原normal/startup默认差异及清理，旧a5失败原件不动。
