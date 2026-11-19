# 自动状态更新 只读审计与最小实现建议

2026-11-17，automatic_sync_dev。状态：供root签实现前评审；未改产品或测试代码，未运行游戏、ADB、容器。必读已核AGENTS、docs/README、architecture-review、module-boundaries、ui-design-handoff及其两研究附录、current-playable-delivery。

## 基线与结论

静态比较178份非测试gd/tscn：工作区game与1083/1082的2345冻结客户端仅net/party.gd不同（已知服务器ACK差异），下面界面刷新相关文件均同。不得修改冻结快照。后续构建使用工作区源并单列此原有差异。

用户说的“同步时间”，当前直接可见对应为world.tscn:44的“同步日程”，没有发现玩家校准服务器时钟的设置。world.gd:181用server_time＋Time.get_ticks_msec锚点；repair_bay.gd:122、facility_recovery.gd:28–43也用服务端时间锚点，不依赖玩家手动对钟。问题是正常界面常驻手动数据按钮，以及部分页面缺进入后的自动读和失败恢复。

已有自动轮询应复用，不另开同目标轮询器。真正缺口需要补自动读取；只隐藏按钮会把库存、生产和配置停留在旧状态。所有自动读取都必须与经济意图恢复分离，尤其store/workshop的_send不是纯读函数。

## 一 玩家入口与当前机制

| 页面和按钮 | 源码位置 | 已有自动更新 | 本轮最小修复落点 |
|---|---|---|---|
| 世界“同步日程” | world/world.tscn:42–44；world.gd:32,47–75,181,370–376 | 进入读；15秒读；前台读；打开子活动in_party停；服务端时间本地走秒 | 健康隐藏Sync；失败才显示“重新连接”；继续原15秒单槽，不加第二Timer；补后台/隐藏门禁，忙时前台恢复排一个读而不是丢弃 |
| 基地“刷新布局/重新核对保存” | base/base.tscn:156；base.gd:85,111–120,249–345,395–450 | 进入、子页关闭、写后等读；只有受损设施到期读；无普通可见页读或前台恢复 | 基地持调度；正常可见空闲时约10–15秒读，前台/子页回流优先；有pending/preview/chosen/submitted、只读封存、访客/preview_only不覆写草稿；草稿期间只延后，不自动_reset；未知保存走现有edit-status GET，不重新造edit |
| 生产“刷新产量/刷新研究站” | base/production_panel.tscn:11；production_panel.gd:12,18–25；base.gd:216–224 | 只在打开与操作返回收到状态，无自身刷新 | 仍由base持HTTP和op；Economy仅显示/发意图；可见生产页按合理间隔读production（已有rate/cycle/progress可用于到期）；不与base GET并跑，不把生产展示推算当实发 |
| 防御平台“刷新装备” | base/platform.tscn:47；platform.gd:15,29–58 | 进入读，成功写后再读；无间隔/前台/失败重连 | 页面可见纯_send({})有界读，busy/intent时不发，失败自动退避；保Parts选择/目标平台；unknown_platform回基地，不无限重试404 |
| 纪念铭牌“刷新” | base/plaques.tscn:35；plaques.gd:15,33,69–105 | 进入、翻页、成功写返回状态；无轮询/前台 | 页面持原临时HTTPRequest，保page/shelf及selected identity；空闲可见10–15秒读；错误显示重连，自动读不制作/换展 |
| 修理站“刷新工位” | base/repair_bay.tscn:60；repair_bay.gd:24,48–56,89–99,122–140 | 进入；4秒读；预计到期立即读；失败5秒重试 | 健康隐藏Refresh；失败为连接恢复；补可见/后台/离页停止；保机器人选择；不另加调度叠加现4秒读 |
| 雷达“刷新袭击情报/重试情报” | base/radar_panel.gd:22,33–40,51–88 | 返回server next_refresh，1–30秒读；前台读；离页停 | 健康隐藏Refresh；失败保单读自动退避/重新连接；当前失败return后没有再设due，不能只隐藏按钮 |
| 野袭“刷新战况” | raids/raid_watch.tscn:75；raid_watch.gd:43,111–166,578–610 | 正常5秒读；失败两次快重试后10秒慢读；回放时停 | 复用原poll/retry_in，健康隐藏Refresh；失败连接态；补前后台门禁；不要回放期间重读打断frames/replay_at |
| 档案“刷新” | profile/profile.tscn:69；profile.gd:41,221–285,304–345,409,545 | 进入新鲜档案；读失败短重试；维修due到期再读；无一般前台/外部变化周期 | 根profile持HTTP/会话；visible $Scroll＋token/account有效时调度；守机定向恢复、dossier retry、经济写优先；选中机器人ID不变，不覆盖正在输入的名称 |
| 库存“查看库存”及原意图Retry | profile/inventory.gd:16,28–37,84–118；profile/inventory.tscn:15 | bind_account只清状态/恢复意图，不自动读；当前要点击后制造按钮才有数据 | 绑定并根档案首次同步后自动GET inventory；由profile协调单HTTP；库存持续可见时有界读；LoadStock正常不再承担必需手动取数，可隐藏/改仅失败重连。Retry是原写恢复，不能误当普通读按钮 |
| 服役累计“查看/刷新” | profile/history.gd:10–27 | 用户首次展开触发读；换选机且opened时重读 | 首次“查看服役累计”是展开内容，可保留；已展开后随机器人/前台/到期状态读取，无需再点同按钮更新；同父HTTP不能挤掉其它请求 |
| 单机检修/回收预览 | profile/recovery.gd；profile/profile.gd:319–345 | 选择机体后读；到期调度；pending持原key | 打开内容保留正常展开行为；已展开需更新quote/状态，纯读自动，不能自动送修/救援/确认回收 |
| 工坊“刷新工坊/重试上次请求/核对本次制造或保存/核对本次换装” | owned/workshop.gd:82–85,160–203,327–344,608–646 | 进入/子商店返回读；read/build/design/refit一次RecoveryTimer自动重试；之后手动 | 没pending时自动纯GET workshop，保draft_changed/方案名/Robot/Slot/Item/常用版本；ApplyPreview、HullNumber编辑、商店子页隐藏时停。不允许auto读调用有pending的_send；原意图恢复另见后文风险 |
| 商店“刷新或重试” | store/store.tscn:56；store.gd:23,31,59–85 | 进入；成功写返回新store；pending从本机恢复，_send会POST | 无pending可见页约10秒GET；有created/paid订单可更短但有界，不自动simulate/retry发货；保商品/机体/涂装预览/订单ID；未知操作不清pending |
| 锈轨/工厂/武器库/泵站“刷新任务” | expedition/expedition.tscn:106；expedition.gd:88,233–253,291–295,954–978；继承于factory/pump/armory outing | 合作大厅1.5秒，搜索3秒，读失败两次后failed停；独行准备无持续读 | 正常Reload隐藏；合作沿原状态机恢复，failed显示重新连接；独行准备可见有界GET expedition/任务模式，不调用出发/领取。加入/队伍变化/读取失败保原读代次，继承派生的_api_path不能写死 |
| 营地“重新读取营地” | camp/camp.gd:63,90–118,208,576–584 | 准备3秒读，Retry仅overview_error显示；写能优先退役后台读 | 无健康按钮需删；错误文案改连接恢复，补后台/隐藏门禁与前台即时读；保勾选和报价；战中仍靠net快照，不用HTTP读代替ENet |
| 秘宝整备/“重新核对我的机体” | treasure/treasure.gd:132–185,297,349–357 | 未attached时2秒GET，read-intent状态机分离未发/已发 | “提交/重新核对我的机体”实际是名单业务确认，保留，不简单删字；纯读不需按钮。失败自动连接恢复仍不得重放过期阵容意图；战中ENet按原场重连 |
| 好友“刷新” | friends/friends.tscn:30；friends.gd:30,53–102,261–266 | 2秒GET，子页child_open停，写优先退役旧读 | 健康隐藏Reload；错误连接恢复；补前后台/关闭停止，读成功清过期网络错误但保真正写失败提示；保输入FriendName/选中项 |
| 账号入口“重试连接”与诊断“重新检查” | beta/entry.gd:45,88–151,396；beta/diagnostics.gd | 账号初始化短重试；前台重新compat；诊断为内测支持 | 真失败连接重试保留，正常状态不露同步。诊断手动检查属于支持，不列本次删除；不自动注册/登录创建新会话，不改账号恢复安全流程 |

真实正常手动按钮约13处，另外库存首次取数、失败恢复、多种业务确认不可用同一个正则批量删除。game/*/tests、net/probe和运营工具不属于玩家改造目标。

## 二 共同生命周期和最小抽象

建议根评审批准一个小型可组合的局部调度组件（如game/client/page_refresh.gd/.tscn）：仅持可见/前台/到期/间隔/退避与“需要一次读”信号；不拥有HTTP、token、领域数据、经济pending或页面导航，不Autoload、不管理所有页面。当前平台/铭牌/商店/工坊/档案/基地确有共同可见读生命周期，组合价值是避免每页再复制应用通知和退避状态。

- 页面场景显式组合组件并提供“当前是否可读”门禁：真实可见、没有子页面或编辑覆盖、非preview/访客/封存、无经济写或未知意图、当前会话有效、HTTP槽空闲。
- 组件发due，页面才调用已有纯读入口；busy时合并为一个待读，不丢前台刷新、不每帧发请求。success/failure由页面回调反馈。角色/认证401停止正常调度，提示重新登录，不无限连401。
- 创建时读取一次；从子页返回、前台恢复合并一次；周期采用tick时间，失败退避5/10/20秒封顶；成功清连接错误，不清写入失败原因。短暂隐藏不重建队伍/机体；关闭和queue_free清调度，发出中的HTTP按现有请求所有者取消/失效。
- 已有world/friends/raid/repair/camp/treasure/expedition轮询继续原所有者，不加并行组件定时；只补前台/隐藏与健康按钮可见性。可复用同组件的前台门禁，但必须选择一个调度器，不“原poll+新Timer”叠加。
- 晚回包按原发射器及token/account/目标ID判定；不能用旧请求signal去解除新请求busy。已有base临时active_http、profile独立dossier_http、friends/camp _retire_http可复用。
- base原get会_reset；自动读不可在pending/preview/submitted/chosen期间应用，不能毁编辑草稿。workshop draft_changed保草稿；store旧_style/robot/order选择保持；profile机器人名称编辑不能被周期_display覆盖。
- 背景隐藏页面和打开子层的父页面都停止新读；不能只测CanvasLayer.visible就认为所有子Control是活跃页。CanvasLayer不等同CanvasItem的is_visible_in_tree，门禁使用各真实场景根/HUD/子层状态。

不建议WebSocket、全局事件总线、全局SyncManager、统一Repository，也不重构所有网络Autoload；本次是已有客户端状态读取生命周期修复。

## 三 精确允许文件建议

必需产品脚本：

- 新增局部调度组件game/client/page_refresh.gd及page_refresh.tscn（最终命名由root签）。
- game/base/base.gd、production_panel.gd、platform.gd、plaques.gd、repair_bay.gd、radar_panel.gd、facility_recovery.gd（改尾部手动错误提示并沿父base读）。
- game/profile/profile.gd、inventory.gd、history.gd、recovery.gd、repair_quote.gd（后两项仅消除“请刷新”错误出口并由父读，不重写回收领域）。
- game/owned/workshop.gd、store/store.gd。
- game/world/world.gd、friends/friends.gd、raids/raid_watch.gd。
- game/expedition/expedition.gd、camp/camp.gd、treasure/treasure.gd（复用既有读状态机，不改战斗规则/ENet命令）。
- 对应需要组合组件或初始隐藏控件的上述.tscn；不得为了隐藏按钮删除%节点让原入口/既有测试崩溃。

不需改服务端、协议、已部署六服务、冻结快照、Drop概率/底盘实体或签名材料。若实现必须新增业务回执查询接口，必须先回root复审后端范围，见下一节。

## 四 未知经济结果不能伪装纯GET

现状具体差异：owned/workshop.gd:85 RecoveryTimer.timeout连接_send；_uncertain在一次不确定结果后开Timer；_send:181–199在pending非空时会按原key POST。store._send:59–70同理。inventory._retry也会emit保存的原POST。它们靠既有幂等合同恢复，不是按key的只读回执查询。

当前server.py:313 GET /v1/workshop只返回view；build/design/refit没有通用owner-scoped receipt GET。GET /v1/inventory只含最近30条账本body，无business_key，不能证明任意原意图是否提交。base有明确GET /v1/base/edits/{key}，是可以只读核对的已存在例外。

因此本轮client-only的安全合同是：新增自动刷新绝不在pending状态调用会发POST的_send；不清原意图、不改业务号、不用“当前视图看起来相似”宣布原操作成功。root已明确本轮保留既有同key/body有限幂等恢复（含RecoveryTimer），不改后端／镜像，不新增回执API；只有异常才可显示“恢复本次操作”，健康不常驻伪装重连。正常读取失败改连接恢复。若以后要求所有经济不确定结果也绝不重放POST而全自动原回执核查，需要另审最小新回执GET及后端镜像更新，不能宣称本轮已完成。

不能把原来“核对原换装/提交我的机体/重试原保存”一律改成自动GET并清pending，这会把合法业务确认或可靠提交语义删除。也不能把“重新连接”按钮实际绑定到新的购买/制造动作。

## 五 HTTP GET并非数据库只读与请求预算

server.py:215–225只有edit_status/defense-alerts/radar等走mode=ro单快照；大部分GET先在独立事务调用profile_maintenance.advance_request_state（:228），再进业务事务。其调用顺序为service_record.expire→recovery.complete_due→party.expire→expedition.expire→camp.expire→friends.expire→treasure.expire→raids.due_accounts。production GET还update production_state（production.py:63–114），按当前时间推进并保留有上限产出。

逻辑GET可以自动发，但不能按“无副作用”假设高频全后台轮询。建议只读活跃页，原快队伍2/3秒轮询不新增并行，静态库存/铭牌/工坊10–15秒，维修保4秒＋到期。无秒级更改需求的全档案／基地不要1秒扫；不在每个子组件独立扫全profile。重连退避并合并focus/resume重复通知。生产未确认不能客户端加库存，研究/收费/领取仍显式动作。后端全局维护成本为既有边界风险，不能本轮顺手改领域次序或数据库事务。

## 六 必须可观察的验收

1. 健康进入各正常页面，没有“刷新/同步日程/刷新工位”等常驻维护按钮；列表和费用初始自动读，库存无需先点“查看库存”才能造件。
2. 生产保持可见跨一产出周期，无点击自动看到新可领；维修30秒到期自动归队；显示仍以服务回包为准。
3. 好友申请/援军接收/营地归属等由另一账号产生变化，本页自动可见；选择与输入不跳回首项。
4. 编辑基地预览、方案草稿、换装预览、机名输入保持跨自动读间隔不丢；既定提交后真正库存/选择更新。
5. 隐藏父页、开子页、HOME后台无新增轮询；回前台合并一次并刷新；关闭/换账号后旧回包不污染新页。
6. 纯读断线保持旧状态但禁过期动作，自动有界重连，真实失败有重新连接入口；不要求玩家“同步时间”。401回登录、不永久重连；业务409不是全游戏掉线。
7. 写后断包，自动读取不能另发购买/制造/领取，原意图不丢；已有合同允许的原key恢复与新增只读poll分开计数；交易不能假成功。
8. 世界时间在设备时钟偏移下仍以server_time+monotonic走；前台恢复读新窗口，不能客户端越权开营地。
9. HTTP请求量和同时在途数受控，单页同槽最多1；读请求不得阻塞已允许显式动作，不能busy期间丢前台恢复或每帧排多次。

首轮测试应以实际代码的Godot headless/局部可控HTTP、两个新账号集成及必要单模拟器交互为主；资源/数据预算由test_lead提出，主代理不重复完整矩阵。这里未编写/执行测试工具。

## 七 用户新补充的实体装备掉落边界

结构材料/通用零件/能源是可堆叠资源；drill等是parts表中有独立id的可实装部件，两种结果不能只以“材料+1”合并。expedition.py:263–285现已实现个人首胜：first时必选drill（首次不走随机rare）；有仓位插parts实体，无仓位记expedition_first_parts待领；:356–368 claim-first按原key领同一确定钻头。普通后续reinforced_boiler为20%概率和连续未出保底；本轮不用改它。

履带crawler当前是catalog的四种固定底盘定义之一（loadout/catalog.gd:6–9），制造按chassis收费，robot_chassis存definition。不是独立parts物品，不存在“副本发一件有id履带→占背包→装到机器人”的当前合同；不能把已可选底盘或造整机称为已支持履带实体装备掉落。要新增实体底盘需另审M03/M09/M14库存/接口/身份与消耗。

可直接作为本轮自动同步的新账号端到端链：正常亲自锈轨首胜→真实结算必得drill（或明确满仓待领）→回库存/机库自动取得该实体id→选兼容待命机实装→返回自动显示实装与背包变化，全程不靠刷新按钮。原材料奖励与实体装备各列；不新增掉落系统，不改概率，也不伪造迁移数据。
