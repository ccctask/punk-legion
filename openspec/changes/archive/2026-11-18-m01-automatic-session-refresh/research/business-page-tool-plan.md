# 真实业务页最小工具落位（待root准入）

2026-11-17 test_lead。组件6例已签，不能代此处。A最终候选未签；本页不运行资源、服务或设备，手机/R2不动。

## 仅4个测试文件

1. **新增 `tests/godot/refresh_profile_fixture.py`**：继承现`http_fixture.Fixture`，沿其唯一127.0.0.1端口0、非daemon线程/stop_event/join/监听释放。仅新空SQLite初始化、正常Handler账号/API前置、受控原生HTTP时序/固定RO proof与公开请求账；不实现各业务route响应字典、不导入旧测试库、不启动raid scheduler或新资源manager。
2. **微调 `tests/godot/http_fixture.py`**：构造器可选handler class，默认原Handler不变；新组传当前真实`services/profile/server.Handler`的窄传输子类。GET的一次503/held在进入生产respond前控制；未知写用`send_response`前的精确请求钩子持有/断开（该位置生产handle已完成提交），仍由原Handler读取/认证/事务/响应；不手造receipt，不包装/替换业务handle。
3. **新增 `tests/godot/test_refresh_pages.gd`**：5个实际场景测试段，见下表。真实HTTPRequest，GUT断言原字段/选择/草稿/请求数与新fixture账；不直接调用_response冒网络。测试可正常configure已注入的本轮会话，不重复登录UI；控制通知只说明headless合同，不冒Android。
4. **微调 `tests/godot/run.py`**：独占`refresh_pages`组，原OwnedJob/GUT/fixture生命周期不变；新增真实服务helper与配置闭包锁/组专属env，失败/空/skip拒绝沿旧门。未改其他组，不复制第二runner。

新fixture唯一小控制面采用本轮文件标记/固定case（或同端口固定/qa控制路径，root选一种后固定），只调度指定GET/POST响应。每个held请求独立ID、route/method/当前owner上下文，明确release/cancel，错误异常仍hardfail；不能用全局held或假通用receipt API。RO proof只固定本case的order/receipt/库存/revision计数与ID，不任意SQL、不记录token。

## 真实项目与闭包

起点为`profile/profile.tscn`、`base/base.tscn`、`owned/workshop.tscn`、`store/store.tscn`、`world/world.tscn`、`friends/friends.tscn`；按实际res依赖展开。profile/base的继承/预载会触及探索、camp和机体资产，不以空Room等stub绕parse。QA stage取实际`game/project.godot`的五Autoload **Room/Solo/Party/Camp/Treasure**与对应真实脚本、实际渲染配置；仅改独立custom_user_dir和运行测试入口，不引private_beta/用户会话。主场景/图标若仍在配置中，也纳入真实闭包。

复用原closure/复制过程扩到project配置res引用、实际`.gd.uid`/资源`.import` sidecar，保GLB/纹理与原import设置；不拷共享.godot缓存。准备只导入这一真实闭包一次，不另造空Autoload或反复parse全部仓库。当前profile服务独立fresh DB，实际Python imports闭包单列；不能声称仅2组件生产保护。

## 5段必要页面断言

|段|场景/真实前置|通过条件|
|---|---|---|
|P1 初始库存/生产|实际profile+Inventory、实际base+Production；正常新号，core/必要foundry通过正常API|无需“查看库存/刷新”即取得真inventory。生产module显式QA clock（仅独立fixture进程）推进后，当前GET触发原生产维护并更新progress/pending；不假装自动领取入库。必要一次正常claim造成真stock变化，当前页自动跟上；没有镜像响应。|
|P2 工坊实体/草稿|实际workshop，正常API制造一个有成本的实体部件作快前置，真part ID；不充作G首胜钻头|可见自动GET取到新增实体，选机/槽/物品ID保持；正在编辑方案名/草稿时不重置或误提交，清理编辑后一次合并读。ApplyPreview/子商店覆盖时不背景刷新，返回一次；旧请求晚回不覆盖新对象。|
|P3 world/friends外部变化|实际world与friends；第二新账号正常好友API；world保持原日程/资格逻辑|健康无手动Sync/Reload；外部好友变化自动出现。一次真实GET503后自行恢复；隐藏/子页/PAUSED不新读、恢复合并，世界仍server_time+monotonic，不误登记入场；401止读且不重放认证。|
|P4 store未知写|实际store正常创建订单，原Handler提交后将该唯一POST响应hold/drop|pending/body/key保持，周期/焦点/恢复不调用混合_send重发；RO账恰一订单、POST次数1。后续允许的原用户“恢复原操作”和自动GET分开记账，不要求系统不存在的通用receipt GET，不以隐藏按钮代通过。|
|P5 base未知保存/同槽|实际base正常布局操作，Handler提交成功后原响应hold/drop|自动读不抢HTTP槽、不清submitted/原revision/preview；只沿现`GET /v1/base/edits/{原key}`核收据，费用/receipt/revision各一份，原POST不被周期逻辑重复。|

P1的生产clock/世界锚点只通过隔离fixture的已有production.now/world_calendar.now入口控制，不改当前主机时间或共享server源码，不冒自然等待的玩家时间。无法正常API满足某制造/布局前置时，先报差额/合同，不临场SQL加料。

## 预算与G链

建议真实scene/GUT stage准备共同≤90秒（一次import），5段headless+一fixture共同≤120秒，失败/线程/Job清理≤20秒，单引擎/单监听；无需Docker/ADB。源码与HTTP依赖都冻结后再定精确命令/锁；先按5段一轮首错停，不人为拆成多次平台资格。

G另用现`solo_peer.gd`/Solo实际服务/新号正常start→route/collect/repair→真实win，**不直接settle**；同一生成的数据接P2实际workshop验证钻头part ID、自动可见和实装同ID。它比页面快测长：上限420秒任务，提议共同≤540秒+30清理，1真实Solo headless server+1client及profile fixture，无Android。旧peer310秒硬上限/回连策略与当前CAP、原ACK的适用性需窄工具AR，不为求绿改游戏期限或拉旧spool。满仓资格是单独容量前置/正常claim规则，明确合成来源；不必重复第二场相同完整Solo。

真实网络/异步UI风险优先由P1–P5发现，G不重复页面故障矩阵。最后一次Android模拟器仅前后台/触控平台差异另准，不重P95/全地图/物理手机。所有临时资源按原owner finally保证关/Join/端口和Job空，当前用户服务始终不动。

## a1通知刺激修订依据（实施前记录）

a1 P1通过；P2新增UUID已由真实10秒GET看见，随后wake只Node.notification页面本体，没有给PageRefresh子节点发通知。Godot4.6.1 node.cpp2434–2441明确propagate_notification递归子节点；workshop无_notification转发，不能让产品适配错误测试。原请求23项/失败/1000即时后核及清理见verification/test-business-pages-a1-report.md。按root窄准仅wake两通知改propagate_notification；P2–P5固定test_recheck_与run.py固定--refresh-pages-recheck/expected4沿旧treasure filter，不延长wait。P1/7helper依赖未变复用，不回写a1原件或重跑其它组。
