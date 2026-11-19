# android-private-beta Specification

## Purpose

验收适用范围遵循仓库 AGENTS.md。下文涉及特定历史版本的迁移、旧数据兼容和同卷回退场景，仅适用于当次交付；当前及以后使用本轮新生成数据，除非用户明确要求此次迁移。
定义本机安卓独立内测的签名、升级、资产恢复和交接要求。维护者据此核对内测专用包名和签名、递增版本、账号权益恢复、公开端点及渠道后续验收范围。

## Requirements

### Requirement: 可升级的安卓独立内测版本
项目 SHALL 提供可验证签名与版本的独立内测 APK，使用明确配置的测试服务和模拟订单。
#### Scenario: 安装与升级
- **WHEN** 在安卓模拟器安装旧包、建立测试账户并原位升级到候选包
- **THEN** 设备接受更新，客户端能从正常入口连接指定服务，既有机体、库存与权益保持一致。
#### Scenario: 后台和重装
- **WHEN** 玩家切前后台或重装游戏并重新登录
- **THEN** 账号恢复其已确认的资产与权益，旧协议不兼容时显示处理方式，交易状态可核对。

### Requirement: 内测交接与后续渠道
项目 SHALL 交付安装、连接、回退、已知问题、版本兼容和反馈说明，清楚标识内测交易。
#### Scenario: 首次交付给测试者
- **WHEN** 领取签名 APK 与内测说明
- **THEN** 测试者可在说明的环境中完成安装及游玩，并分辨模拟交易。正式渠道和真实支付沙箱留待平台选定后另验。

### Requirement: 更新后客户端与服务端的版本追溯
每次向本机模拟器发布更新时，项目 SHALL 记录实际 APK、兼容服务和测试网络的可达范围，同时维持既有账号和监控数据。
#### Scenario: 经营与移动画面更新
- **WHEN** 经营入口与移动端画质决策已定稿并作为新的递增签名包交付
- **THEN** 原位升级后能操作更新入口，既有资产可恢复，部署对应快照的档案与战斗服务能够通过本地网络访问。

### Requirement: Coordinated tactical content upgrade
The beta SHALL distribute an identifiable client and matching local services supporting playable chassis, squad orders, party continuity, disruption and owned robot favorites.

#### Scenario: Return from version 1007
- **WHEN** an existing 1007 player installs the signed update and enters the corresponding service
- **THEN** their original robots, parts, purchased capacity and applicable gameplay receipts remain accessible and new tactical features can be exercised through the normal Android client.

#### Scenario: Old client with incompatible gameplay rules
- **WHEN** a previous client cannot represent the new rules for an active service
- **THEN** the player sees the upgrade requirement before any new activity can consume inventory or enter a mismatched battle.

### Requirement: Android opens on the private base
The Android beta SHALL open on the private base, allow a new player to name their first owned robot there, restore the returning player's own base, and place connection details and the test range in a menu.

#### Scenario: First visit
- **WHEN** a new player launches the app and completes registration in the base
- **THEN** the player can name the first owned robot there and see the accepted name on that same robot after relaunch.

#### Scenario: Returning commander and menu
- **WHEN** an existing commander signs in or resumes a valid session and visits the range or diagnostics
- **THEN** their base and previously named robots remain accessible and returning from the menu restores the same commander.

#### Scenario: Interrupted start or rename
- **WHEN** the network fails during launch or naming, or the required protocol is unavailable
- **THEN** the player can see the appropriate recovery or upgrade action, and retrying never grants another robot or overwrites another account's name.

### Requirement: Distribute the base-first and two-camp client together
The signed closed-beta release SHALL enter the private base, route both public camps to their own authority and prevent previous clients that only address the default camp from performing territory operations on the new live service.

#### Scenario: Update the existing installation
- **WHEN** a commander upgrades a 1008 signed installation and logs into the migrated local service
- **THEN** their existing account and robots are recoverable from the base, and each map location opens its corresponding camp.

#### Scenario: An older client contacts its published address
- **WHEN** an old single-camp client uses its published profile address after cutover
- **THEN** the service returns an update requirement before the client can modify any territory data.

#### Scenario: Local service cutover
- **WHEN** the accepted build becomes the local beta
- **THEN** operators can verify the one live profile, the five real-time services and the original recoverable snapshot using the documented deployment and recovery procedure.

### Requirement: Distribute accepted camp art and mobile construction controls
The beta SHALL provide a signed Android update containing the accepted construction controls and both authored camp scenes while remaining compatible with the published protocol-five service.
#### Scenario: Upgrade from the base-first release
- **WHEN** a player installs the update over version 1009 on the same device
- **THEN** the existing account can resume at its private base, inspect readable construction controls, and access the two distinct public camp scenes from the map.

### Requirement: Distribute a compatible public-camp settlement correction
The local closed beta SHALL distribute the accepted mobile entry fixes and timeout settlement correction with a signed and recoverable update.
#### Scenario: Upgrade the camp patch
- **WHEN** the operator updates the published client and camp and profile services
- **THEN** previous accounts and compatible clients retain access, published endpoints remain usable, and valid persisted timeout results can settle once.

### Requirement: 发布私人基地首通扩地
本机内测发行 SHALL 保留历史账号、基地资产、胜利资格和已扩建的地块。

#### Scenario: 同签名升级
- **WHEN** 有本人首次胜利记录的 1011 玩家覆盖安装扩建版本
- **THEN** 原账号回到原基地并可免费使用新增三列，普通建造按原价结算

#### Scenario: 发布后需要恢复服务
- **WHEN** 已有玩家在新增区域建造后发生发布故障
- **THEN** 经演练的恢复路径保留其建筑、道路和库存，且账号可读取基地

### Requirement: 开发内测用当轮数据验证战术目镜
开发内测 SHALL 使用空数据库、当轮创建的账号与编队核验已发布的战术目镜。

#### Scenario: 新账户装备目镜
- **WHEN** 当轮新建账号在机库选择战术目镜并出战
- **THEN** 装配界面说明首发优势，权威战斗显示可测的首次开火差值，同款武器持续射速一致

### Requirement: 在同一内测入口交付探索配方与整机报价
签名内测 SHALL 让当轮新建账号在同一项目中查阅锈轨钻头制造进度和机库整机指挥点。

#### Scenario: 首次进入基地工坊
- **WHEN** 新号在当轮私人基地查看研究与机库并保存制造方案
- **THEN** 可看到三次通关和提前研究的获取途径，报价中的整机指挥点与制造后的实际出战数值一致

### Requirement: 安卓签名版提供并行维修及完整工坊指引
本机安卓内测 SHALL 提供已供电站房的双机维修与完整的钻头制造去向。
#### Scenario: 安卓新账号的私人基地
- **WHEN** 玩家在供电站房送修两台受损机体并在车间完成钻头研究
- **THEN** 两台分别按三十秒期限完工，窄屏可读到完整的档案仓库制造说明。

### Requirement: 安卓玩家按个人额度参加双人秘宝
安卓内测 SHALL 显示每人 12 点、最多 6 台的双人编队，从同一版服务确认双方选择后准入。
#### Scenario: 与好友确认后入场
- **WHEN** 两人各自提交合法选择并确认当前阵容
- **THEN** 安卓界面显示双方个人额度及状态，并能进入同一权威场次。

### Requirement: 安卓组队探索从准备报价到收工
签名安卓内测 SHALL 在同一轮真实合作探索显示准备报价，按个人支付入场，战果页可正常收工。
#### Scenario: 玩家带机回营
- **WHEN** 安卓玩家选择实体机体、和好友准备出发、进入房间并结束自己的探索
- **THEN** 大厅报价与实际部署、扣费相符；结算后可从正常入口返回基地。

### Requirement: 安卓合作探索集结
安卓签名内测 SHALL 显示合作探索队员到场状态，在全员到齐或等待达到 30 秒时开始作战。
#### Scenario: 队友先后入场
- **WHEN** 安卓玩家和桌面队友先后完成房间认证
- **THEN** 等待期间显示到场人数，战斗时间保持完整，全员到齐立即可以指挥。
#### Scenario: 队友超过截止
- **WHEN** 安卓玩家已到而队友未在 30 秒内进入
- **THEN** 已到者开始战斗，缺席者按个人过期处理。

### Requirement: 安卓可核对合作探索机体服役记录
签名安卓内测 SHALL 按真实参战事实显示机体的参战场数。
#### Scenario: 一人作战一人缺席
- **WHEN** 一名玩家实际作战后撤退，而队友到截止仍未进入
- **THEN** 作战方在机库看到该机体参战场数增加一次，并在玩法回执中看到主动撤退，缺席方收到过期回执且机体参战数保持原值，双方机体都解除派遣。

### Requirement: 安卓首胜后可从基地快速回收
签名安卓内测 SHALL 按玩家真实锈轨个人胜利展示快速回收，并在手机确认前显示所选机体、本次费用及可得材料。
#### Scenario: 通关后再访回收场
- **WHEN** 一个新账号从基地查看锁定条件、获得真实个人胜利，再从安卓基地返回准备页完成回收
- **THEN** 回执与报价一致，每日仅能成功一次，实际战绩和钻头进度只计之前真实胜利。

### Requirement: 安卓可与好友完成公开地图合作泵站
签名内测 SHALL 允许安卓玩家从公开地图进入遗迹，与好友分工完成两阀、共享开箱、独立撤离。
#### Scenario: 不同客户端合作撤离
- **WHEN** 安卓指挥官和桌面队友通关同一泵站实例
- **THEN** 双方各获得符合当日额度的个人回执，安卓可回到地图查看剩余额度，锈轨专属首胜进度保持原值。

### Requirement: 安卓内测玩法按当前基线核对
项目 SHALL 在整体验收时对照策划的可玩路径、当前冻结运行时与可复查的实际证据。
#### Scenario: 多个模式共用个人档案
- **WHEN** 新活动依赖通用出征、资源与机体档案并进入签名候选
- **THEN** 验收能区分新活动与既有玩法的独立进度，并列明当前版已复验的玩法、尚待核实的场景和测试环境。

### Requirement: 安卓泵房指挥信息验收
签名候选 SHALL 在移动端验证密集机体的选择反馈和指挥。
#### Scenario: 满编三人泵房
- **WHEN** 玩家在安卓端切换单机与全队并发出指挥
- **THEN** 身份栏反映真实选择，权威房间接收对应指令，验收记录该设备的交火呈现时间与测试范围。

### Requirement: 安卓内测核对基地首机快照
候选包 SHALL 和对应档案服务共同验证基地启动时所用的玩家机体。
#### Scenario: 安卓读取已派遣的首机
- **WHEN** 玩家在当前签名版登录或重新打开应用
- **THEN** 基地能从当前服务显示该账号真实机体与装配，成功到达正常日常入口。

### Requirement: 签名包试穿与权益一致
内测版本 SHALL 从基地进入商店显示所选机体的真实装配，在签名客户端确认预览、装备持久化与测试订单退款。
#### Scenario: 指挥官为第二台机体购买外观
- **WHEN** 在新测试账号选中第二台机体，试穿、模拟购买并装备薄荷涂装，再次登录后退款
- **THEN** 试穿期间无扣费，重新登录可见该机体已装备，第一台机体保持基础色，退款后恢复基础涂装。

### Requirement: 签名包领地生产闭环
签名包与其本机服务 SHALL 允许实际占领公开营地的内测玩家通过正常指挥台建设采集站并按真实服务器时间领取营地产物。
#### Scenario: 新营主投资并领取首份产出
- **WHEN** 新玩家在开放窗口真实占领、建设采集站并在生产到期后返回领取
- **THEN** 场次归属、建设扣料和领取入库都能通过同一玩家和营地的服务端记录复核。

### Requirement: 签名安卓复看个人协作战果
签名内测包 SHALL 按指挥官和活动复看同一场合作探索中各自的实际战果、机体和收支。
#### Scenario: 两名队友分别离场
- **WHEN** 两名新玩家在同一合作场次分别离场，再依次登录签名客户端
- **THEN** 各自只看到本人该场的回执，重复查看不新增战果或费用。

### Requirement: Signed beta with current base-defense information
The signed Android beta SHALL expose insured stock estimates and the frozen guard presentation through the private base, with matching authoritative services.

#### Scenario: Observing and closing a private defense
- **WHEN** a newly registered player views a warning and its resolved defense on the installed release
- **THEN** the estimate follows the current stock, actual loot matches the settled inventory, only registered defenders appear, and the owner's showcase returns on leaving.

### Requirement: Playable signed beta with live camp reconnect rules
The signed Android beta SHALL connect to release-matched camp and profile services implementing bounded attacker reconnect and valuation of completed private production.

#### Scenario: Disconnecting an installed mobile client on the core
- **WHEN** the attacker disconnects from a camp while its robot controls the core
- **THEN** the installed client can return to the original session within grace or retrieve the settled receipt after grace, the server freezes capture during absence, and the signed release exposes the corresponding defender outcome after expiry.

### Requirement: Android exploration reconnect and roster preview release
The local signed Android beta SHALL provide the tested exploration reconnect controls, pump HUD changes and public camp roster preview on matching services.
#### Scenario: Try a fresh local installation
- **WHEN** a new player prepares an expedition or public camp force from the normal Android client
- **THEN** valid orders resume only after reconnecting to the expedition and the camp roster displays the combined player and accepted aid costs before committing.

### Requirement: 安卓基地防守与战后送修
签名内测 APK SHALL 支持在同一客户端从私人基地查看新场次的野生袭击记录，并按当前库存判断能否送修。
#### Scenario: 防守中受修后战损
- **WHEN** 玩家在新生成的防守中受到维修平台支援并产生战损
- **THEN** 正常安卓野袭回放可核对平台和战损，机况页可辨认受损机体；修理站能读出材料缺口，补足后正常送修。

### Requirement: 安卓合作指挥继任与认证恢复
签名内测客户端 SHALL 在认证结果不明时支持原表单再次登录，并在合作房间展示服务端决定的集结人数和现任队长。
#### Scenario: 安卓队员接任
- **WHEN** 原队长退出而安卓玩家依入队顺序接任
- **THEN** 安卓玩家可用普通战术标记按钮建议位置，队友能看到同一建议。
#### Scenario: 登录请求中断
- **WHEN** 安卓首次登录未取得会话回执
- **THEN** 玩家可从当前表单在恢复连接后直接登录。

#### Scenario: 同步错误之后的完成回调
- **WHEN** 登录请求立即报错，随后原请求又送达延迟完成通知
- **THEN** 只处理一次失败；后续请求拥有独立的完成通知，恢复联网后能直接使用原表单登录。

### Requirement: 安卓出征与驻防选择
签名内测客户端 SHALL 在单人探索、合作大厅与私人基地的正常入口保留玩家的合法机体选择，并向档案提交对应身份。

#### Scenario: 备战中更新名单
- **WHEN** 安卓玩家在单人准备页刷新、合作选择时遇到轮询，或驻防候选中有人出征
- **THEN** 仍可用的目标保持所选，以当前装配报价与本人机体编号完成对应操作

### Requirement: Qualify mobile base controls and battle report handoffs
A signed internal Android candidate SHALL exercise base sound settings and cooperative and defense reports against its matching local services before publication.

#### Scenario: Accept a candidate with fresh player data
- **WHEN** the candidate is installed on a clean emulator and linked to fresh local services
- **THEN** verify persisted volume, distinct assembly exit reports and correct guard identity in recovery using the ordinary mobile interface.

### Requirement: Deliver the signed friends and raid candidate
The playable local Android beta SHALL include the accepted friends action and shared fit changes and the private raid read recovery using matched local services.
#### Scenario: Use signed candidate on a fresh account
- **WHEN** a tester opens the installed beta on the emulator and uses the private base menu
- **THEN** the tester can inspect and save a received support fit and read the account's raid information from the normal game screens.

### Requirement: Recover the active dossier read
The ordinary commander dossier SHALL recover a transient profile read failure on the current account and expose a manual refresh after bounded retries.
#### Scenario: Temporary failure while entering from base
- **WHEN** the current commander opens the dossier and the first profile GET fails transiently
- **THEN** the same page fetches the same commander again, applies only a valid response and displays the correct fleet without repeating writes.

### Requirement: Ship the paired workshop quote client and service
The signed local beta SHALL pair the qualified dossier and workshop clients with the matching fabrication service.
#### Scenario: Fabricate from the signed mobile build
- **WHEN** a new commander enters the workshop through the private base and saves and fabricates an affordable fit
- **THEN** the preview price equals the actual debit and the resulting robot and mounted parts correspond to exactly one build receipt.

### Requirement: Ship territory collection and reviewed refit together
The playable local Android beta SHALL pair the qualified camp claim and owned-robot refit clients with their matching service.
#### Scenario: A commander collects yield and confirms a refit
- **WHEN** a new test account plays the signed candidate through the private base, territory map and workshop
- **THEN** a partial claim preserves remaining territory stock, cancelling the refit moves no parts, and confirmation produces a single receipt and the reviewed robot loadout.

### Requirement: Android beta public rustyard matching
The signed standalone Android beta SHALL let a new commander cancel a rustyard search, find a stranger, ready a robot, and play the same authoritative expedition with individual results.

#### Scenario: Cancel and match from private base
- **WHEN** a commander cancels once in the Android base daily flow and searches again alongside another account
- **THEN** the first search costs nothing and the new search leads to a shared lobby, two authenticated seats and separate personal histories after battle

### Requirement: Android territorial sortie supply
The signed local Android beta SHALL present the attack price and support reconnecting after spending the attacker's final energy. The signed client SHALL display only the current rustyard search status on a second search.

#### Scenario: Last energy paid once
- **WHEN** a commander starts a territorial attack on Android with one energy, reconnects and finishes
- **THEN** the same battle resumes and only one supply receipt charges that commander

#### Scenario: Search again after canceling
- **WHEN** the commander cancels rustyard matchmaking and searches again
- **THEN** the current waiting state is visible and the previous cancellation notice clears

### Requirement: Android pump recovery to garage
The standalone signed Android beta SHALL let a player complete their first pump extraction, identify the recovered repair arm in the personal result and fit that same physical part in the home garage.
#### Scenario: Recover and equip
- **WHEN** a fresh account successfully extracts from the pump and installs its recovered arm on its robot
- **THEN** the signed client's personal report, garage and authoritative AUX mount identify the same item and the reward is issued once

### Requirement: Android 1043 defense candidate
The signed Android candidate SHALL expose the accepted raid warning preparation behavior and the revised pump auxiliary result text.
#### Scenario: Clean mobile acceptance
- **WHEN** a tester installs 1043 and exercises each feature with fresh test data
- **THEN** the tester can inspect the warning defense and revised pump result in the installed client and identify the matching services and artifact.

### Requirement: Mobile treasure targeting and equipment status
The signed Android candidate SHALL support explicit treasure focus selection and render the earned pump item identifier legibly in preparation.
#### Scenario: Candidate playthrough
- **WHEN** the tester taps a farther enemy and then empty ground in a live treasure match and inspects an earned pump reward on the preparation page
- **THEN** the room reports the selected enemy followed by movement and the Android reward label matches the owned item.

### Requirement: Signed mobile raid formation and approach
The Android private beta SHALL expose the same seeded enemy formation and approach path as the local authoritative raid service.
#### Scenario: A mixed raid reaches the mobile base
- **WHEN** the tester opens a mixed warning, edits the defense and watches the resulting battle and replay using the signed Android build
- **THEN** the approach reflects the accepted layout, advertised type counts match the fielded units, and the replay and receipt identify the same raid.

### Requirement: Mobile defense recovery after an extended transient outage
The signed Android beta SHALL automatically reacquire an active defense after connectivity returns while the tester stays on the defense page.
#### Scenario: Connectivity returns after the battle ends
- **WHEN** two fast GET retries are exhausted on a live defense and the service becomes reachable after settlement
- **THEN** the installed game retrieves the matching outcome without a refresh tap or repeated guard assignment.

### Requirement: Use the battle plaque collection in the signed Android build
The signed Android client SHALL let a player select distinct settled robot records by touch, commission two plaques, switch the exhibited plaque without charge, and retain that exhibit when reopening the base.

#### Scenario: Choose a non-default battle and change the exhibit
- **WHEN** an owner touches a non-default battle in the list, commissions both records, selects a different exhibit and reopens the base
- **THEN** the base shows the selected battle-time name and short reference and the authoritative ledger records exactly two commissions charging eight structure and two components in total.

### Requirement: Resolve a distant foundry's power on Android
The signed client SHALL show the eastern foundry's loss of coverage and allow a player to build one relay by touch, preview changes, and switch the relay off and on.

#### Scenario: Restore power and reopen a base
- **WHEN** the owner places the relay at the edge of core coverage, pauses it, resumes it and reopens the base
- **THEN** the foundry's displayed and authoritative operating states agree at each step, the relay cost is charged once, and the resumed layout is retained.

### Requirement: Verify a lost save response in the signed client
The signed Android client SHALL automatically read the committed edit receipt after losing a successful build response and show the saved revision and charge in the private base editor.

#### Scenario: Receive a receipt without a second tap
- **WHEN** the server accepts a base construction and the phone does not receive the response
- **THEN** the player sees the matching receipt without touching the screen again, the service records one build and one charge, and reopening the base shows the saved structure.

### Requirement: Cold start a saved base from the signed beta
The signed Android beta SHALL restore the saved private base from the matching local release service after process death.

#### Scenario: Enter a previously built base
- **WHEN** the tester cold starts the signed client with a valid session on the available release stack
- **THEN** the current revision and built structure appear without manual reconnect, and loading performs no additional construction charge.

### Requirement: Signed Android production and cooperative play
The signed beta SHALL reflect a player's credited production claim in the daily card and permit cooperative pump controls after authoritative assembly completion.

#### Scenario: Finish daily progress at home and enter a pump room
- **WHEN** a player collects available production in the signed app and joins a pump expedition with two teammates
- **THEN** the player sees actual credits and the original daily receipt, receives combat controls at start, and can issue a command that the room accepts and receive a personal settlement.

### Requirement: Signed Android fitting guidance and treasure audio
The signed Android beta SHALL advance onboarding after a confirmed design installs a physical component and play friendly action cues during a live treasure battle according to the saved effects level.

#### Scenario: Return to base after a confirmed installation
- **WHEN** the player confirms fitting a saved design with an owned repair arm to the starter
- **THEN** the base offers the next outstanding step and the workshop shows the same physical component on that robot.

#### Scenario: Fight and settle in the signed client
- **WHEN** an Android seat directs its robot in a live treasure encounter and obtains its result
- **THEN** the app presents the expected friendly action audio and a personal result matching the authoritative settlement.

### Requirement: Signed Android robot career totals
The signed Android beta SHALL expose the selected owned machine’s settled participation count, finishing kills and effective repair output.

#### Scenario: Inspect two machines
- **WHEN** a player opens two same-name machines, then relaunches and returns to the garage
- **THEN** the three authoritative values match each machine’s identity, including a new robot with three zero values.

### Requirement: Verify protected reward on the Android beta
The signed local Android beta SHALL show the actual treasure cargo and separate participation reward at settlement and when reopening the latest personal result.
#### Scenario: Normal entry and settlement
- **WHEN** a new account enters a matched treasure room through the installed app and successfully picks up a crate
- **THEN** the personal result and the reopened result agree with the authoritative warehouse deposit and the independent once-per-day reward.

### Requirement: Android private raid recovery warning and replay
The signed Android beta SHALL present the authority's adjusted budget, causes and resulting roster through the normal private base defense entrance.
#### Scenario: Regrouping after a loss
- **WHEN** a new account loses a real defense and its registered guard remains injured at the next warning
- **THEN** the installed app shows the resulting reduction and the same encounter reaches a replay with the frozen adjusted budget and roster.

### Requirement: Correlate Android login and raid polling delivery
The beta verification process SHALL distinguish a successful service response from a successful on-device login or raid read using fresh accounts, the same signed client and time-correlated evidence without credentials.
#### Scenario: Connection loss before or after the response
- **WHEN** a signed client reports a transport error during login or defense polling
- **THEN** the investigation compares matching service events and normal client behavior and records whether a bounded response-delivery change is warranted.

### Requirement: Bounded delivery for successful sign-in and private raid reads
The profile service SHALL allow a well-framed successful HTTP/1.1 session creation or private raid status read to use its existing bounded keep-alive window. Every request on a reused connection SHALL be authenticated independently.
#### Scenario: Normal client reads the result
- **WHEN** the Android client requests a session or a private raid on a connection permitting persistence
- **THEN** it can receive the complete response without an immediate server close and without automatically resubmitting a login; explicit close, errors and unrelated writes still close the connection.

### Requirement: Signed beta supports large garages and relay defense
The signed beta SHALL be verified with a new owner of eighteen robots and a valid relay building.
#### Scenario: Login and reopen the relay defense
- **WHEN** this owner signs in, enters the defense view and plays a frozen raid
- **THEN** the base, relay and actual raid result are readable, and reentering shows the same encounter and receipt.

### Requirement: Signed Android defensive aid repair
The independent Android beta SHALL show and charge the reduced defensive reinforcement repair price for the selected injured robot.
#### Scenario: Repair on emulator
- **WHEN** a new owner with one component and zero structure opens the signed app and submits an eligible repair
- **THEN** the repair starts, one component is charged once, and a separate ordinary damaged machine retains its normal price.

### Requirement: Playable Android release with personal treasure salvage
The signed Android release SHALL let a player collect cargo, extract and receive an equipable rare boiler when their personal guarantee applies.
#### Scenario: Guaranteed capture in the actual mobile game
- **WHEN** a new player with two prior misses extracts a carried item in a real network room on the emulator
- **THEN** the visible result, reopened receipt and workshop item identify the same owned part, and the signing and local services match the delivered release.

### Requirement: Signed Android treasure site art
The signed beta SHALL ship the three accepted dioramas and render the actual room site on Android while allowing movement, pickup and extraction.
#### Scenario: Play the live event on the emulator
- **WHEN** an owner enters a matched treasure room from the map, picks cargo and extracts
- **THEN** the visible title and diorama match the authority and receipt, landmarks leave targets accessible, and a real in-battle presentation sample is recorded.

### Requirement: Play facility recovery and part comparison on Android
The signed beta SHALL expose post-raid facility recovery and owned single-part comparison through the normal private-base and workshop interfaces.

#### Scenario: Restore and refit a fresh account
- **WHEN** an emulator player returns to a damaged powered factory, repairs it and compares and equips an owned reinforced boiler in the garage
- **THEN** its authoritative production resumes, its repair is charged once, and the confirmed combat statistics and item identity match the preview and service ledger.

### Requirement: Android factory escort and salvage swarm release
The signed independent Android beta SHALL expose the accepted factory escort and swarm through the private base while delivering the authoritative camp and refit results.

#### Scenario: Touch through the integrated candidate
- **WHEN** a fresh commander enters an unlocked factory, defends a swarm raid, responds to a camp warning or refits a robot
- **THEN** the installed candidate can complete each applicable flow against its own local containers and show the correct settlement, including an automatic original-key refit receipt after an interrupted first response.

### Requirement: Android armory expedition and public camp release
The signed Android private beta SHALL support the armory reward and public workshop card against a locally deployed release with recoverable camp settlement.

#### Scenario: Equip an extracted prize
- **WHEN** a commander extracts the armory cache from the private base and claims the reserved prize after freeing space if needed
- **THEN** the workshop installs the same owned launcher and the signed client can use it on a later sortie.

#### Scenario: Visit a public workshop and recover a camp
- **WHEN** a visitor opens an occupied camp or a room restarts with an incomplete terminal result and a valid checkpoint
- **THEN** the visitor sees the current owner's public details according to the display setting and the affected contest preserves one authoritative settlement.

### Requirement: Signed Android research and account continuity
The independent Android beta SHALL support building an optics station, fitting a fabricated visor, and recovering the same account on a clean app installation.

#### Scenario: Return to a fitted robot
- **WHEN** an Android owner builds and powers an optics station, learns the recipe, crafts and equips the visor, and subsequently recovers the account after clearing local app data
- **THEN** the recovered base preserves the station, learned recipe, owned robot and original installed part, and the pre-reset session no longer grants access.

### Requirement: Android players can deploy a shield and command a custom group
The signed Android build SHALL support crafting a physical rivet shield, deploying the equipped crawler and recalling a mixed selection on a touch screen.
#### Scenario: Recall and issue a move
- **WHEN** the commander equips the crafted shield, deploys three robots and recalls a saved two-robot group
- **THEN** recall by itself issues no order and a subsequent move changes only the selected robots' destinations
#### Scenario: Resume the same battle
- **WHEN** the client reconnects to the same seat
- **THEN** the saved group and authoritative heading of the shielded robot are available on the Android client

### Requirement: A signed Android client supports the light wheel chassis
The Android workshop SHALL let a player refit the starting robot with the wheel chassis and deploy it in an authoritative room with its original identity.
#### Scenario: Touch refit and return to base
- **WHEN** an Android player chooses and pays for a compatible wheel refit
- **THEN** the garage shows four wheels, updated statistics and the original robot and the base offers an attainable next step
#### Scenario: Move and resume
- **WHEN** a wheeled robot receives a movement order and the player reconnects to the same mission
- **THEN** the authority and client retain the wheel chassis and original component identities through the resume

### Requirement: Radar outpost and chassis feedback on Android
The signed Android client SHALL support the private base radar station, its server-timed intelligence and the garage's equipped chassis state.
#### Scenario: Inspect the station
- **WHEN** a player builds a powered station and opens it before a scheduled warning
- **THEN** the station shows the appropriate signal, later offers the formal raid details and returns the player to the same base after visiting the linked destinations
#### Scenario: Inspect a paid chassis
- **WHEN** the player inspects the current chassis after paying for a refit
- **THEN** the current chassis displays its equipped state while another candidate displays the applicable quote

### Requirement: Numbered fleet and shared chassis on Android
The signed Android client SHALL preserve per-robot hull numbers across sessions and display shared designs using the interfaces of the selected chassis.
#### Scenario: Return to a numbered machine
- **WHEN** a player saves 07 through the touch garage and reopens the game
- **THEN** the same robot displays 07 and a second machine built from its design starts unnumbered
#### Scenario: Receive a chassis design
- **WHEN** a friend shares a design with an optional part on a supported interface
- **THEN** the recipient sees that part and its ownership requirement and can save the design without receiving the sender’s parts or machine number

### Requirement: Survey scout assembly and shared cargo intelligence on Android
The signed Android client SHALL support a craftable rivet repeater and survey radar, a legal survey-wheel scout, and team-specific sealed crate discoveries in a live treasure room.
#### Scenario: Equip a scout on a touch screen
- **WHEN** a player manufactures the two parts and installs them with a boiler and eye on the survey wheel
- **THEN** the garage shows the physical radar, four used payload and three command points, and the same owned machine can join a treasure match
#### Scenario: Survey and recover cargo
- **WHEN** the Android scout detects a sealed crate before pickup range and a pilot later retrieves and extracts it
- **THEN** the discovering side sees the resource, an opposing side outside detection range sees a sealed crate, and the extracting player receives the verified cargo once

### Requirement: Android base defense return
The signed Android client SHALL show the settled private raid outcome, actual loot, guard and facility damage, and applicable recovery period in the initial report view.

#### Scenario: A returning owner inspects a defeat
- **WHEN** the owner opens the settled raid from their private base and revisits the report after inspecting the guard
- **THEN** the summary agrees with the original receipt, guard inspection targets the same robot, and viewing details or replay leaves the settlement and inventory unchanged.

#### Scenario: Return after extended absence
- **WHEN** an owner first returns after the original 48-hour loss protection has expired while offline
- **THEN** the service grants the configured 24-hour return period and subsequent logins retain the same deadline.

### Requirement: Android first-battle guide and warning release
The signed beta SHALL expose the accepted first-battle-first optional guide and three-hour formal private raid warning through normal Android entry points.

#### Scenario: New player stops or continues after victory
- **WHEN** the owner wins Rust Rail and returns to the private base
- **THEN** Android displays daily completion and optional continuation, opens the appropriate existing fit and manufacture screens, and preserves completed facts after relogin.

#### Scenario: Returning during the warning
- **WHEN** the owner returns two hours after the warning's scheduled start
- **THEN** Android displays the approximately one-hour remaining deadline from the same scheduled three-hour window.

### Requirement: Signed Android workshop recovery acceptance
The signed beta SHALL verify bounded confirmation recovery for workshop design and build operations under controlled reply loss and connection failure, retaining one original operation and charge.

#### Scenario: Committed build response is lost
- **WHEN** the service commits a build but its response does not reach Android
- **THEN** the Android workshop retries its original key at most once automatically per round, shows unconfirmed feedback if still uncertain, and confirms the same robot and receipt after manual recovery or relogin.

#### Scenario: Ordinary release environment after injection
- **WHEN** temporary fault injection is removed
- **THEN** the installed signed APK confirms normal workshop reads and writes against the verified frozen services, and temporary resources are cleaned before handoff.

### Requirement: Bounded delivery for successful workshop writes
The profile service SHALL permit well-framed successful HTTP/1.1 workshop design and build requests to use the existing bounded six-second idle keep-alive window, while preserving original-key receipts, charges and per-request authentication.

#### Scenario: An unchanged Android client confirms a write
- **WHEN** the Android client saves a design or builds a robot with a complete supported request on a connection permitting persistence
- **THEN** it can receive the complete framed result without immediate server closure, and repeating the original key returns the same receipt without an additional charge.

#### Scenario: Persistence boundaries remain enforced
- **WHEN** a request explicitly closes the connection, uses HTTP/1.0, fails authentication or business validation, is outside the selected routes, or the idle window expires
- **THEN** the original close behavior remains, and every request received on a persistent connection is authenticated independently.

### Requirement: Signed release integrates bounded workshop delivery
The signed Android beta and its frozen profile service SHALL integrate the accepted bounded workshop write delivery policy and be verified together on fresh data before playable handoff.

#### Scenario: Confirm writes and return to the same workshop
- **WHEN** a new owner saves three successive design versions and manufactures their robots in the signed Android client
- **THEN** on-device confirmations agree with once-only receipts, actual robot identities and resource charges, including after a cold relogin.

#### Scenario: Replace the playable release
- **WHEN** the candidate passes independent package, live service and Android acceptance
- **THEN** the previous release's containers and dedicated network are removed, its named volumes are preserved, and the new playable version and evidence are recorded.

### Requirement: Signed Android cooperative lobby recovery
The signed Android beta SHALL deliver the reviewed cooperative lobby read recovery, protect actions requiring an authoritative snapshot, and preserve normal cooperative deployment and personal settlement on the matching local release.

#### Scenario: Recover or stop a failed lobby read
- **WHEN** a player opens a cooperative lobby before its first valid snapshot or encounters a temporary read failure, exhausted retries, or an expired session
- **THEN** Android shows the applicable recovery action, permits no dependent write before confirmation, uses at most two automatic read retries, and does not automatically resubmit writes.

#### Scenario: Background, return and close on Android
- **WHEN** the installed app actually enters the Android background, resumes, or leaves a lobby while a read is in flight
- **THEN** inactive lobby polling and old queued actions stop, return obtains a fresh confirmation, and leaving causes no invalid UI access or subsequent submission from the closed scene.

#### Scenario: A processed preparation loses its reply
- **WHEN** the service accepts preparation but Android loses the response
- **THEN** the installed client reads the authority to display the current state without another preparation POST, distinguishing an uncertain sent operation from one never sent.

#### Scenario: Ordinary release after fault verification
- **WHEN** temporary fault transport is removed and the signed client starts a cooperative expedition with another fresh account
- **THEN** both seats can authenticate, assemble, start, issue a valid command and obtain separate once-only personal settlements; the same task's confirmed state remains readable after a cold app restart before playable handoff.

### Requirement: Bounded delivery for successful cooperative lobby reads
The profile service SHALL permit well-framed successful HTTP/1.1 GET requests for the party, pump and factory cooperative lobby snapshots to use the existing six-second idle keep-alive window. Each request SHALL be authenticated independently, and snapshot protection, read retry limits and write submission semantics SHALL remain unchanged.

#### Scenario: Read a changing cooperative lobby
- **WHEN** the Android player reads a cooperative lobby while another legitimate member leaves and rejoins
- **THEN** complete framed snapshots expose the current membership while preserving the player's valid selection and permitting preparation only after a confirmed read.

#### Scenario: Persistence remains bounded and scoped
- **WHEN** a lobby request uses HTTP/1.0, explicitly closes, has unsupported framing, fails authentication or business processing, targets an unselected route, or exceeds the idle window
- **THEN** the existing closing behavior remains, no previous request's authentication is reused, and reads cause no entry charge or deployment.


### Requirement: Deliver Android owner alerts and refit recovery
The signed playable beta SHALL expose owner defense alerts and recover one lost single-part fitting receipt through normal Android gameplay.

#### Scenario: Defend a live camp and recover a refit
- **WHEN** an emulator owner receives an attack and also refits an owned item whose first committed response is interrupted
- **THEN** the defender can command the correct contest and the garage converges to the single recorded installation with no manual retry after that interruption.
