# Design

状态：root已在末段带约束签最终AR/六组选集；只准限定实现，准备/正式运行另门。2026-11-14。主责/必要性见[proposal](proposal.md)，现状与源身份见[G3只读输入](../../../../build/architecture-review/g3-final-review-input.md)。

## Context

G2限定出口已签。Expedition已组合PartyPanel、QuickSalvage、Debrief、RoleSelect、BattleAudio和HTTPRequest；缺口是外部依赖及关闭顺序，不是缺少场景文件。当前三源SHA分别为expedition21accc5c…6f999、base0487f78b…f0b2d、world40dfe4a4…14681。五处closed.emit先于_exit_tree收尾，仅静态可构造风险；历史大厅恢复证明不能代替本次同步重开/晚响应验证。

## Goals / Non-Goals

使现有探索场景能在无同名Autoload的上下文由明确依赖正确初始化，缺配置安全返回，关闭先释放本页资源再通知宿主，旧页延迟销毁不能断开新页复用的会话。保留现有全局会话、派生钩子及网络/账务权威，不制造新管理器或HTTP抽象；本案不支持两个同时活动的探索页面共享同一mission连接。

## Decisions

### 所有者与依赖方向

工程根继续创建并持有Solo/Party；M05网络节点拥有连接/权威快照，M14/M15页面仅持借用引用与本页订阅/请求上下文。基地_open_area识别Expedition及派生后，在add_child前配置两会话；通用_show_area仍可承载非探索页面，不无条件注入。world的_open_pump与party分支在已知实例入树前配置，营地/秘宝分支不改。endpoint/token和模式继续按原父根提供。

宿主使用preload现有solo.gd为Session类型；Party本就继承Solo，不新增接口/Autoload/class_name或逐字段鸭子验证。configure_sessions限入树前且不在关闭态调用，保存两有效且不同的Session引用，返回明确成功/失败；不偷偷回退/root查找。常规模式切换仅转移changed订阅，选择注入对象，不额外disconnect旧mission。原_continue_party连接逻辑不改。

### 配置失败与派生约束

_ready先只绑定本地Back，再验证配置。失败时停止process/unhandled_input，不连接其余父级业务信号、不订阅net、不自动fetch/切模式，隐藏提交入口；用现有LobbyReadBanner/LobbyReadStatus明确诊断，因为派生会覆盖Rules/LobbyStatus。Back走同一局部关闭，不依赖net；不在_ready自动emit（父根此时尚未接closed），不用lobby_closing冒充配置失败。

Factory/Pump/Armory在super返回后继续其原UI初始化，不能假设父_ready return会终止派生。宿主在实际跨会话边界_request/_join/_party_toggle/_continue_party/_sync/_process/_unhandled_input/_send/_field_tap共用局部usable判断，避免缺配置或关闭后的直接入口/排队信号访问net；纯展示方法不堆砌guard。统一谓词要求有效配置、当前会话有效且页面未关闭；正常_ready选好net后才启用业务。开发若发现这三文件无法守住派生路径，回root复审，不能顺手改派生。

### 幂等关闭与失败合同

五个关闭出口统一走局部close方法：先幂等release再emit一次。release先检查/设置现有lobby_closing、清pending_button并停帧/输入；无条件http_generation++，断当前实际HTTPRequest的http_callback并清Callable，再cancel本地IO/清等待状态；断当前net.changed的_sync，再对有效当前net调用一次disconnect_mission，不free两注入对象、不更改其余会话。_exit_tree调用同release兜底，已关闭时不再断新页复用的同一Session。

关闭不调用服务端cancel/finish/重发请求，不给未知POST生成新业务键。cancel_request即使针对POST也只放弃本地IO/观察，不能宣称服务端未提交；原未知结果与下次权威读取语义保持。_response原代次/closing屏障保留。隐藏/暂停的_cancel_lobby_get仍保其原GET语义，不借关闭扩大后台POST重试。

这使closed的成功通知点明确：监听者回调时页面已失效且不再拥有订阅/连接释放责任，可同步新开同会话页面。直接父级释放不发closed，仍完整收尾一次。缺配置/已释放引用也必须能收尾，不访问失效子控件。

### 允许范围与不变边界

仅game/expedition/expedition.gd、game/base/base.gd、game/world/world.gd的上述依赖/入口/收尾；tscn、三个派生、Solo/Party、所有服务/模拟/定义/资产/版本与11当前交付文件不改。测试工具由test_lead预选后root锁定，开发必要自测限新入口解析和最小构造资格；完整正式行为另新锁/门。无数据迁移、无旧场次重放、无部署或重签1077/r2。

### 官方依据

[Godot4.6场景组织](https://docs.godotengine.org/en/4.6/tutorials/best_practices/scene_organization.html)建议上层提供外部依赖；[静态类型](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/static_typing.html#what-can-be-a-type-hint)允许preload脚本常量作类型；[Node](https://docs.godotengine.org/en/4.6/classes/class_node.html#class-node-method-queue-free)的queue_free延迟删除解释为何不能等_exit_tree才履行closed合同；[HTTPRequest](https://docs.godotengine.org/en/4.6/classes/class_httprequest.html#class-httprequest-method-cancel-request)取消本地请求不构成业务撤销。

## Risks / Trade-offs

- 脚本预加载/类型可能形成环：当前闭包未见回边，仍需确切入口check-only，不能以目录import绿灯代替。
- 缺配置可能被派生UI覆盖：保独立诊断及未接业务信号，并用三派生实际实例验证。
- 旧页退出与新页会话复用：用closed当下断订阅/一次释放及同帧重开证明，不等旧页free后再造响应。
- 未知POST关闭：验证真实服务已处理但未收到时本地放弃不重发，不改变服务端提交。
- 大宿主仍协调大厅/编队/战场、派生仍覆盖_request/_api_path、net._lost仍为已登记耦合；负责人M14/M15，新增玩法/第二请求消费者或修改状态机时复审。Camp/Treasure全局依赖本案不动。
- 两个旧直接bench缺入树前配置，按使用另审最小适配，不恢复隐式fallback、不擅改采样或将历史性能结果提升。

## 待最终准入

test_lead需给真实tscn/实际父根/三派生/真实HTTP晚交付/同步重开及直接释放的精确最小选集、探针路径/闭包/import策略与资源预算；root核源及方案后补最终AR再派实现。该处是开发准入门，不是留给开发临场猜测的开放范围。

## 最终AR（2026-11-14，root）

带约束通过任务1.1。根已重新读取三个实际脚本、三派生_ready与_request/_api_path、Party extends Solo、父根add_child/closed连接及原_response代次/关闭屏障，三源哈希与Context一致；现有场景/状态所有者及关闭静态风险等级保持。采用上文typed Session、Back先绑定/缺配置不连其余信号与统一usable、无条件代次失效/本地cancel/断changed/一次disconnect后closed；不采用运行时换注入、额外模式断线或新会话管理器。

采用[test_lead六组预选](../../../../build/architecture-review/g3-test-plan-input.md)：C1明确注入/订阅/入树后配置拒绝；C2基页+三派生缺配置可诊断/Back/零请求；C3同一真实Solo/Party在途GET关闭后无旧更新/意图；C4closed槽同步复用会话新页不被旧exit断、直接free另证；C5本轮freshDB/当前真实Handler正常账号/start提交后hold→Back关闭→新页GET读同active、单任务/费用/收据不重发；C6实际base三入口/world两入口及非探索入口、三派生原路由/body。C5按原solo Back允许关闭在途请求，不修改busy/强行改关闭路径求绿；若实际发现不能用Back，保事实回root而非临场换刺激。

允许测试新增tests/godot/test_expedition_composition.gd、composition_solo_probe.gd、composition_party_probe.gd以及本change verification/testing/{composition_fixture.py,run_scene_selection.py}。Probe分别继承真实Session脚本，仅观察会话边界，不证明ENet/RPC；HTTP使用真实生产HTTPRequest，C5真实当前Handler和空DB/空spool正常创建，不导旧库/战报/进度，不直接改任务/账目。可复用既有GUT9.6.1/support/OwnedJob和纯staging闭包函数，不改公共runner、原测试或框架；新选择薄编排只拥有本案夹具/监督，不另造多套断言。若实际无损复用需要公共runner变更，先回root给精确差异，不能凭预选的备选建议自动扩大。

准备与正式分门：3D/UI新隔离stage单import，最多90秒工作/外120（含清理），确切新测试/三个生产脚本及Probe逐入口check-only，依同一总deadline；只能产准备通过。正式六组工作60/清理30/外90，最多1引擎/1协调器/2个loopback监听及有界请求线程。启动前查共用实例/可用内存，至少1.5GiB余量，不启动AVD/容器/现行试玩；不足时先报当前实例和归属，不批量杀进程。工装实现后先静审锁完整515生产/集合、实际资源/UID闭包/GUT/工具/引擎两exe/Python及11交付，root另签唯一准备/正式门，不凭本AR运行。

开发自审精确三源diff/业务不变与派生安全；不另重复正式六组。解析资格统一由test_lead准备门完成，开发交付不等于通过。成功/失败/超时保首错/原输入/未运行、OwnedJob同创建身份及HTTP线程/监听终态；观察超时追同句柄，不重复POST。回包BrokenPipe只按已取消原请求有界记录，不吞一般异常。公开证据去秘密，保留新敏感DB需标私有来源，不宣称已销毁所有秘密。

生产范围仍仅三脚本，其他512生产/11交付不变；工具在工程game之外、不入发行包。派生/网络/服务端/数值/资源/旧bench/部署均禁止附带；实际跨边界需要扩文件或改变合同先复审。准许开发及工装实现，任何运行另门；当前1077/r2、A01/M04源签收及平台性能结论不重签。

### 开发静审类型边界澄清

root重新核实际调用：suggest仅在Party定义，宿主_field_tap经_can_mark的party_mode/can_command门调用该现有扩展。两配置入参/保存引用仍typed Session，但当前选择net保原Node类型，不把父类不存在的Party扩展硬当成公共接口；这是已有动态角色扩展的有限保留，不新增方法、运行时fallback或has_method静默丢动作。根仍提供实际Solo/Party正确角色，测试Probe各继承对应真脚本。负责人M14/M15，若新增第三种会话或改变标记调用再复审角色接口；本轮不为静态类型扩网络父类或造适配层。允许该一处声明澄清，三文件范围和玩家行为不变。

### a2工具失败后最小修订AR

2026-11-14，root带约束通过。[a2根审](verification/root-scene-a2-review.md)确认helper日志悬挂引用及取消观察不足，非已复现产品缺陷。额外允许tests/godot/support.gd的click在原获取at同一时刻预存name/rect，末尾只打印预存值；原按下/抬起/位置获取时刻/等待帧不变。真实关闭场景是这个公共helper的使用方，修共同日志所有者比复制一套private click更合理；不扩大到其它helper或搬旧用例。

本案test_expedition_composition.gd在pointer前后、until和组末只读GUT9.6.1公共get_errors()，检测到原生错误即置failed并停止进一步业务输入；不clear/handled/吞错误，原JUnit仍失败。根已读本轮固定GUT test.gd:2298的get_errors及既有a2原生错误捕获，复用该框架机制，不改插件/新增框架或再造负例矩阵。

composition_fixture.py只补每请求稳定身份/was_held与明确关闭后release许可：相关真实Back关闭的generation/frame须由控制消息关联本次held请求，只有该请求获close-release且BrokenPipe/ConnectionReset或ConnectionAbortedError.winerror==10053才登记预期取消。reset/cleanup只解等待，不授予正常取消资格；其它OSError/未关联错误仍失败。旧三错误缺身份不逆签，新journal保完整原因，不直接设置生产closing或注入假_callback替代真实Back。

保原a1/a2完整输入/日志/源与未通过结论；生产三源/其他512及11交付不变、原六组业务刺激/字段断言不变。test_lead实现后交精确差异/新锁，准备及正式仍另门，不自动重试。本次共同helper日志变化覆盖六组的输入观察，沿原小选集复验，不重跑其它不依赖此关闭用法的旧GUT矩阵；不为此次局部修订增加缓存系统或selector。
