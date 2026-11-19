# 自动会话/页面同步：最小独立测试预选

2026-11-17，test_lead，只读研究。收到派单时proposal/design/tasks尚未落盘，本页不代系统评审或扩大实现范围；最终以root已签改动/候选闭包修订。未运行测试、导入、服务、ADB或新包，未改工具。用户手机和当前R2服务不作测试环境。

## 当前实际行为与复用边界

- `game/world/world.gd:46,50,70,181,370`已有前台通知、GET单busy、15秒周期/部分失败5秒、服务时间+monotonic锚点；不是完全没有自动同步。需证新行为可靠恢复、不会隐藏后仍轮询或通知叠加，不以移除Sync按钮通过。
- `game/friends/friends.gd:60–98,246–266`已有取消旧HTTPRequest/替换节点、读写区分、child_open/closing与2秒轮询；`_process`没有单独visible判定。验证外部改变、不抢写、关闭晚回包及隐藏边界，不能仅测点击Reload。
- `game/base/base.gd:113,247–354`由submitted/key/原revision持有布局写意图，未知结果走`GET /v1/base/edits/{key}`核收据。自动读不能清submitted、重造key/POST、覆盖预览/冻结编辑，或把旧布局当本次保存成功。
- `game/base/repair_bay.gd:50–95,121–138`已有失败重读、server_now锚点/4秒读/到期核对；`game/profile/profile.gd:305–344`已有repair_due自然触发。倒计时归零不能擅自变业务ready；需一次权威GET确认。
- `game/beta/session.gd`只负责按endpoint存取会话；`game/beta/entry.gd:396`现有通知主要处理返回键，不能凭session文件存在推前后台恢复。正式需核实际创建/关闭/组合链及401语义。

## 最小正式选集（待AR及工具源锁，不是现可执行命令）

|组|实际刺激和通过条件|最小平台/证据|
|---|---|---|
|A 可见页自动读及生命周期|进入→无需Refresh/Sync即读；同页重复show/RESUMED/FOCUS_IN及定时到期仅合并必要一次，无同HTTP并发/忙碌状态丢失；hide/子页覆盖/退出树后不再发新请求；真实在途GET晚回不能更新已销毁页、新同名页、替换token/endpoint后的页面；恢复只刷新当前有效页，不能复活旧页|GUT真实生产场景+临时loopback HTTP，持有/释放真实响应；记method/route/requestID/开始/完成/最大并发/页面世代和完整原日志，不直接调用_response冒网络|
|B 正常同步、异常与会话边界|一次断网或503/408/429→保持可解释旧数据/连接中状态，按获签退避自行恢复到新快照；忙碌时多个到期合并，失败不每帧洪泛；坏JSON/错误schema明确失败而不假fresh。401/失效会话按签合同回登录或停止，不以无限自动登录/POST轮询恢复；任何后台/重开不得重复鉴权写|同A一次过程覆盖成功→暂错→恢复；重试间隔/次数上限取签收参数，暂不自定值。通过依据新数据/请求次数，不以按钮隐藏或错误文字消失代同步|
|C 写入未知与原结果核对|一个本轮合法布局写：真实Handler已提交但响应持有/丢失，期间周期/回前台触发；自动逻辑只核原key收据/当前revision，POST恰一次、receipt和费用恰一份、原预览/提交意图不被周期GET覆盖。权威拒绝和未找到收据保持各自语义，不因“可重试”自动重发业务写；只选这一代表性写所有者，其他写按未变合同继承|独立新SQLite、实际initialize/Handler和正常账户/API夹具，RO收据/费用/revision前后账；本轮响应时序控制不造业务算法/假提交。base._check_save现有逻辑和新同步必须同时经过实际场景|
|D 服务器时钟与到期|客户端响应锚点显示单调推进；服务时间相对本机±一天仍使用服务器锚点，焦点/恢复不把设备墙钟直接当权威。期限前、归零、到期GET在途/失败、权威回包后状态分别记录；归零仅“核对中”，不能本地派发奖励/完工。重复帧不重复到期请求，校时快照不造成负数/洪泛或回退旧revision|纯时钟/调度规则优先；已有实际scene方法与受控HTTP deadline快照验证显示/请求合同。合成短deadline仅标UI资格，不冒真实维修业务；服务器维修/日程规则未改时复用原真实30秒证据，若本次改变其业务提交边界才补一个实际到期case|
|E 外部变化与编辑隔离|两个本轮新账号，乙正常好友请求/接受/撤回其中一条变化，甲留在可见页自动出现新状态，无手动刷新；子页/隐藏期间无无效重复读，返回后取新状态。营地/公共地图用当前日程快照的外部版本变化验证当前owner/资格显示更新，不自动登记入场/重复费用。正在编辑/选中/滚动状态按获签合同保留，不用刷新全页抹掉用户操作|好友用实际正常API；营地若合法API前置过重，使用本轮真实Handler快照派生的UI-only版本夹具并明标，不能写“真实夺营通过”。不为同步重跑完整营地/援军/支付矩阵|
|F 唯一Android模拟器冒烟|新隔离包/服务数据，打开正常页→一次HOME/回前台→看当前页自动更新/恢复；一次页面切换及实际触控不需手动Refresh/Sync。记录实际App通知/页面、必要原图与请求账，无用户实体手机或R2服务操作，不重跑经营/合作/P95|只在A–E通过且涉及真实Android通知/触控后执行一轮；准备/候选源/实际包另签，动态服务端口由已审QA配置注入。有限观察点和单一操作方，避免逐图长往返耗窗|
|G 首胜实体装备→工坊自动同步|本轮新账号亲自完成锈轨实际首胜，receipt.part有非空唯一ID且definition=drill；库存同owner持有该ID，区别stock材料和recipe；无需手动Refresh进入/保持工坊即见该实体。通过原refit装到兼容机体，收据和实际weapon槽同一ID，库存占用/原武器归还正确；实际robot外观钻头或实际功能佐证。满仓支路首胜资格保留、释放空位后正常claim-first恰一实体/原key收据，不能把材料补偿当钻头|真实新库Handler+现Solo客户端/服务ENet真实结局，之后真实workshop场景；只有直接构造结算报文的规则检查不算“亲自首胜”。满仓夹具另明示来源，不能暗写SQL或把合成满包当正常养成。先headless，不因此必加Android完整战斗|

需root在实现AR确定：可见/应用后台与“子页覆盖”的准确所有者、刷新/退避间隔及合并策略、写未知时允许读哪些route、401退出行为、页恢复/过期数据的玩家反馈。测试不通过推测的策略替代未定合同。所有失败首停并保unrun，不自动补轮到绿。

## 已有入口/夹具逐项采用或省略

- `tests/godot/run.py`、`support.gd`、GUT9.6.1锁及`process_owner.py`：复用场景装配、真实输入、等待、空/skip/错误拒绝和Windows Job收尾；当前runner只有rules/scene/async/alerts/treasure固定组选集、旧rc1076保护耦合，不能宣称已支持本选集。新增窄入口/组须先AR，不能默认跑整组。
- `tests/godot/test_async.gd` + `http_fixture.py`：已验证真实HTTPRequest500→200/在途Cancel后晚响应与线程/监听释放。fixture无DB，仅workshop POST preview固定协议；可复用资源/真实延迟方法，不把它当world/base/friends GET或业务提交夹具，也不直接复跑其“显式Refresh”证明自动恢复。
- `game/world/tests/world_ui.gd`继承`profile/tests/profile_ui.gd`：正常随机新号入口及服务锚点±一天断言可借鉴；原断网通过直接调用_response、时钟通过写scene字段，不能代本轮真实网络恢复。`friends/tests/social_ui.gd`、`base/tests/base_ui.gd`和repair相关scene提供正常生产对象/调用链参考，不执行其大经营/援军流程凑覆盖。
- G3归档`verification/testing/composition_fixture.py`：实际fresh.sqlite路径先不存在/version0，再initialize并通过真实Handler正常注册；有真实held request身份/释放/保存RO账和严格cleanup。只读已确认无旧库导入；它的c1–c6合成资格及旧runner/旧门不复用执行。若新夹具需借其模式，先签窄测试工具范围、当前实际profile imports闭包，不复制整套fixture/协调器。
- 仓库本轮文件检索未见pytest.ini/pyproject.toml/conftest或集中pytest夹具；这不证明本机没装pytest。现有GUT和独立Python check入口足够，不为本修复引入第二测试框架。服务initialize里可能支持历史schema不构成执行迁移授权；只能新空文件初始化，不跑check_*整套升级/旧档用例。
- 1083安装/LAN与1082完整合作/P95、既有维修/权威费用幂等、G3生命周期原根证仅按未变依赖继承。不能用旧HTTP回调/401场景推断新定时所有者已验；改动后的A–E必须真实覆盖，F只补平台差异。

## 装备掉落新增要求的现有依据（后续用户补充）

1. `services/profile/expedition.py:263–285`：新账号首次win、wins=0/pity=0时，100%选择drill，生成UUID并`INSERT parts`，receipt.part回传实体ID；资源`changes`与`drill_recipe`是不同字段，不能互替。满仓记录`expedition_first_parts`而非丢弃首胜装备资格。`355–369`的`POST /v1/expedition/claim-first`在原事务内领取、检查空位并用原key幂等记收据。此轮复用现规则，不新增掉率或奖励系统。
2. `game/expedition/expedition.gd:90,478`已有Claim及pending_drill显示；`game/owned/workshop.gd`使用`data.available`实体和refit收据/实装验证，`game/loadout/catalog.gd:100`定义drill的arm接口/visual=1。G需证明新增实体自动进入实际可选库存，不能只见OPTIONS里一直存在“钻头”标签或研究按钮。
3. 已签`m23-architecture-release-integration/verification/root-solo1081-a1-result-review.md`明确真实Solo首胜钻头/扩地来自本场正常结算（362.95模拟秒）；这是旧正常掉落信用，未单独覆盖本次“新实体ID→自动工坊可见→实装同ID”新增前端链。后续按实际expedition/inventory/workshop/robot依赖锁继承，不把未执行维修或旧整体exit1改绿。
4. `game/expedition/tests/solo_peer.gd`/`solo_ui.gd`实际连接当前Solo并按route/collect/repair推进；可复用生产对象/正常命令入口，不重造战斗规则。旧入口310秒wall上限、自动断开/重复collect及当前任务CAP的适用性须在工具AR核定，不能原样拿来跑420秒上限或为“快”直接跳终局。新工具若需要，仅补准确夹具/受管衔接，不扩成网络平台。
5. `services/profile/check_expedition.py`从新临时DB出发，但会SQL填24部件/改expires、写结果spool并直接trusted settle；可参考首胜满仓和claim同receipt断言，**不作为真实亲自首胜入口**。`check_onboarding.py`虽含真实part.id→refit断言，整入口明确DROP表/PRAGMA user_version=8/initialize旧结构，禁跑；不能为借这一断言放行迁移。所需片段必须经新库窄夹具另AR。
6. 满仓来源优先本轮正常API库存构造；若默认资源不足以合法填满，不虚构材料或把recipe当实体。可在root签收后使用可复现、隔离的生产库存helper生成器构造容量前置，记录每个实体/来源并标“容量资格合成”，不冒正常玩家积累了整仓。主正例仍是真实新号首胜/实体钻头/实际装配。不得在用户服务或手机账号上造数。

G若须本轮完整真实首胜，预算按实际Solo上限420秒另提headless共同≤540秒/清理≤30秒，不沿A–E短控预算强塞、不缩短游戏期限；不另跑第二个同样实战来测纯满仓规则。是否需要Android一场取决于最终改动是否影响原生呈现/触控及该断言依赖，不能因新增装备说明机械重走全地图或真机。

## 预算、隔离与收尾

建议先纯/场景check-only准备≤60秒，独立headless A/B/D及同一HTTP时序≤60秒；新库C/E共享一次服务fixture≤90秒，公共清理≤20秒。最终候选和间隔确定后再合并准确deadline，禁止靠改短生产等待或预写业务状态过关。Android只一AVD/必要客户端/独立新服务，工作≤300秒+60清理提案；APK/导入准备单列，不把新包构建时间混作测试耗时。尚未批准这些运行预算或创建资源。

全部新run/锁/独立DB或卷/账号/场次；本轮合法fixture生成来源必须进报告，不导旧库/重投历史响应。临时线程/HTTPRequest/引擎/服务/AVD均归现有OwnedJob/fixture finally，成功/失败/超时保原证后关掉本轮资源，核端口与Job空；原用户手机App和当前六服务始终不动。只报告有意义的断言组、首错/未运行及资源终态，不以CLI次数/拍图数代覆盖；不重复本轮无关平台/签名/全矩阵。
