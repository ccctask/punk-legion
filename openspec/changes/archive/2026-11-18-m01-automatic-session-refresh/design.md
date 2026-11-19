# Design

## Context

见proposal及research/refresh-audit.md。已核18类页面机制；世界/好友/维修等已有轮询，经营/库存/工坊等有真实缺口。现行game页面与已交付2345同源，仅net/party.gd保既有ACK差异。本轮不是重建网络协议；客户端GET仍会触发现行服务器维护事务，频率须有界。

## Goals / Non-Goals

正常在线不要求玩家手动刷新数据或同步日程；可见数据自动跟上进入/写后/前台/到期及外部变更。保编辑和经济语义。不新增玩法、后端回执API、WebSocket平台、全局Manager，不迁移或重置当前试玩数据。现有100%首胜实体钻头链作为新库验收，不改掉落率或将履带伪装已有实体掉落。

## Decisions

### 实现前系统评审与落位（root，2026-11-17，通过）

M01主责可见页面的读取调度，关联M07–M24各页面；模块/服务依旧拥有认证、原意图、库存、费用、资格、战果、时间权威。页面合成已有领域视图，不直接发奖或改变原事务。只读调查已核当前调用/继承链，具体源行见research/refresh-audit.md。以下清单限定实现授权，不按脚本长短决定边界。

| 落位及实现方 | 负责/不负责；为何放这里 | 状态与生命周期 |
|---|---|---|
| A：新增game/client/page_refresh.gd及.tscn | 小型场景组合的可见读调度；仅周期、单次due合并、前后台、成功/失败退避。平台/铭牌/商店/工坊/档案/基地有实际共同生命周期，避免重复该技术语义。不拥有HTTP/token/领域视图/写意图/导航，不Autoload。 | 场景创建/配置/释放；页面显式提供可读门禁并接due到现有纯GET，回包报告读结果。忙时记一次待读，非每帧排任务。隐藏/后台停新读；恢复合并一次；退出清调度。组件不取消或重发领域写。实际公开接口与必要状态在交付说明对应，不新增业务状态机。 |
| A：base/base.gd及base场景、production_panel、platform、plaques、facility_recovery | base持原共享HTTP/op，Economy只呈现/发信号；同槽统筹layout/production，不让子组件各扫profile。平台/铭牌自己持原请求与对象。设施恢复只沿父读并修错误文案。 | 只有本人可见活页、无pending/preview/chosen/submitted编辑、非访客/preview_only/封存才应用基地自动get，防_reset毁草稿。生产显示和实际入库分离；子页回流读取一次；选中对象/分页保持。 |
| A：profile/profile.gd及其场景，inventory/history/recovery/repair_quote | 档案根协调原HTTP、dossier与子面板读；库存首次自动取得，再按活页刷新。累计/检修展开仍是正常业务入口，不自动触发回收/救援/制造。 | account/token/当前机器人及原发射器拥有回包；换机/账号/销毁令旧回包失效；名称编辑不被_display覆盖。既有维修到期/守机定向恢复优先，避免多子面板饿死或重复读。 |
| A：owned/workshop.gd及场景、store/store.gd及场景 | 补明确的纯GET读取，不在pending调用混合_send。保既有持久化原意图和已签同key/body有限恢复，不借此次统一交易实现。 | 草稿、选中方案/实机/槽/实体、机名、商品/涂装/订单保留。ApplyPreview/HullNumber编辑/子商店覆盖时按各所有者停背景读；返回合并读。无新key/新POST/清pending，迟到包不能覆盖新上下文。 |
| B：world/world、friends/friends、raids/raid_watch、base/repair_bay、base/radar_panel | 原轮询/到期/退避仍唯一所有者；去健康刷新按钮，补前后台、隐藏、恢复合并与错误入口。保持其现有信号/请求接口，不与A同时修改同文件。 | 原world15秒、friends2秒、repair4秒+到期、radar服务器due、raid5秒/失败慢读复用。回放不被自动重读打断；父页被子页覆盖停读；本次错误与旧写失败提示区分。少量页面激活门禁留其生命周期内，不强提取异构业务状态机。 |
| B：expedition/expedition、camp/camp、treasure/treasure及对应场景 | 原大厅/搜索/原意图策略与实时房间边界保持；独行准备补自动读。factory/pump/armory继承链复用_api_path，不写死模式。 | 合作1.5秒/搜索3秒、camp3秒、treasure2秒沿原状态机；动作优先，不阻塞用户准备；隐藏/后台/关闭停止，回前台核原队/原场。战中仍ENet快照与原场重连，不用HTTP代替。 |

组A与组B对应脚本之外不改生产源。对应.tscn只用于组合组件、初始可见性，不删除被引用的%控件；账号启动的真实失败重试及内测诊断检查保留，不扩账号安全流程。不改net/、battle/、业务服务、签名材料和冻结快照。发现新增跨域写或接口/生命周期变化先回root复审。

### 调度/提交合同

1. 正常状态隐藏通用刷新、同步日程、查看库存前置按钮；首次自动加载。真正的展开累计、提交阵容、确认换装等业务操作保留。失败状态才出现重新连接/必要恢复原操作，不常驻改名假重连。
2. 新静态页面周期以10–15秒为起点；只有可见活页读，原有快速轮询不叠加新Timer。前台/到期/返回/显式成功后的必要读优先合并，busy期间不丢，不产生多份队列；失败约5/10/20秒退避封顶。401停止正常调度给登录恢复，409业务失败不伪装整个游戏掉线。
3. 页面持HTTP和busy/请求上下文；调度只发一次应读信号。页面确认原发射器/会话/对象后接受回包；关闭或换上下文必须取消/失效，不能让旧回包解锁新请求。组件显式场景组合，不全部运行时凭空生成。
4. 新周期请求严格走纯GET。store/workshop/inventory混合_send在pending时会POST，禁止用于新后台读；原RecoveryTimer等已签同key/body恢复保持，不新增自动写重放或假定GET视图证明任意原操作成功。没有通用receipt GET，不能写成已实现；base edit-status是现有明确例外。
5. 服务器时间＋monotonic锚点继续自动维护；本机对钟变化不裁定开放、产出和完工。后台读取不清正常输入或静默重置基地预览；若必须跳过读则延后，不伪造新鲜。

### 验收与工具范围（root准入）

复用research/test-selection.md的A–G选集及现有GUT9.6.1、HTTP fixture、OwnedJob、fresh Handler/正常Solo入口。允许test_lead为当前源新增窄测试组/用例，以及在已有http_fixture.py增加本组真实GET延迟/失败响应；不得复制另一套框架/资源状态机或跑含迁移整组。测试API只为控制独立环境的网络响应/时钟观察，不伪造业务战果。

用真实HTTPRequest覆盖自动更新、前台/关闭/晚包、草稿与未知写/频率，规则计时可单独虚拟推进但不能冒真实Android/服务器通过。新空库正常账号/独立新卷和场次；本轮首胜100%钻头用正常亲自指挥真实Solo链，记录部件ID入仓→自动可选→实装同ID，材料/配方分列。满仓前置若生成器构造必须另标合成来源，不冒自然积累。

先headless/新库集成，后一次必要Android模拟器前后台/触控烟测；不重跑全地图或真机性能/听感。测试先核内存/已用实例，独立服务临时端口不占用户R2，正式后清自有实例/容器并提交终态；root不另起重复矩阵。准确预算由test_lead依当前用例提交，不为小检查启动整套新基础平台。

## Risks / Trade-offs

- GET仍有维护事务成本→只活页有界读，不增后台全域扫描；后端性能组织风险另留原台账。
- 多页面继承/原意图不同→不统一业务写恢复；按实际上下文测试，纯隐藏按钮不算通过。
- 加轮询可能清草稿或持续打断输入→草稿门禁、身份保持、单槽调度和真实场景断言。
- 新UI源不等于已更新手机→源审/自测/独立验收后再唯一签发候选；LAN端点/原签名/默认模拟器变体分别登记，不改当前用户运行服务。

## Delivery

自动同步与运动问题分别立项。此change不夹带惯性/寻路实现；运动研究完成后独立签AR。最终按已签源/测试结果打安卓LAN更新并提供安装，保用户同版数据；没有迁移授权。UI交接/Space在实际通过后更新，不能用设计文档称产品已修。

## QA参考与适用

复用[Clash of Clans官方UI整理](https://supercell.com/en/games/clashofclans/blog/news/weve-revamped-the-clash-of-clans-user-interface/)的玩家任务归组和实际待处理状态提示原则；不由该文推断其内部轮询周期或“所有网游只有重连”。本项目的具体决定来自负责人明确的正常游玩期待与现有页面缺口：健康自动更新，实际异常才显示恢复，读写结果不假成功。[Godot4.6 HTTPRequest](https://docs.godotengine.org/en/4.6/classes/class_httprequest.html)明确同一节点不可并发发请求；[Node生命周期](https://docs.godotengine.org/en/4.6/classes/class_node.html)作为组合/通知/释放依据。实际六例调度组件已另独立通过，业务页结果仍待正式记录，不能以参考资料冒产品实测。


### Group A 实际技术接口（root 2026-11-17 消息签准）

PageRefresh 为每页显式场景子节点；read_due 无参信号，configure(active:Callable, available:Callable, seconds=10.0)、request_now()、retry_now()、current_lease()->int、settled(success:bool, stop=false, lease=-1)、defer(lease=-1)。lease 只隔离技术调度代次，不能代替页面原 HTTP emitter/会话/对象检查。active 不看自己的 busy；available 才看 busy/草稿/pending。hide/取消无完成回调后再打开仍可恢复，晚 settled/defer 不可解锁另一代请求。

root 另签最小 queued_wake 补差：configure 普通初始 queue 可由首次显式 GET 完成清除；真实 RESUMED/FOCUS_IN、活跃页隐藏/恢复产生的 wake 保留一次，消费 read_due 才清 wake。FOCUS_OUT 同 PAUSED 停调度；不增加新 owner、请求包装器或业务 API。原 helper 2bd5 的六例保历史，新 helper 58162335… 需由 test_lead 对实际共同依赖复验原六例并补初始 held GET 期间前台与 focusout 断言。
