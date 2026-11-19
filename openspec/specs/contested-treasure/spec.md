# contested-treasure Specification

## Purpose
定义限时秘宝的服务端日程、团队争夺、撤离和个人结算规则。维护者据此核对预组队与单人匹配、携带上限、权威拾取裁决，以及房间恢复和重复撤离的唯一入账。

## Requirements

### Requirement: 自愿进入的临时秘宝事件
玩家 SHALL 可从地图选择单人或组队参加明确标注为对抗玩法的随机秘宝区域，区域不可占领。
#### Scenario: 入口与事件切换
- **WHEN** 普通 PVE 队伍浏览地图或临时事件开启与关闭
- **THEN** 地图标明地点、时限与风险，进入对抗需明确同意，普通 PVE 玩家仍可沿原入口探索。

### Requirement: 有限携带与唯一撤离结算
权威服务 SHALL 在既定队伍预算内裁定争抢、拾取和撤离，同时保护玩家既有资产。
#### Scenario: 两方争抢与撤离
- **WHEN** 不同玩家同时拾取同一件秘宝，经历战败、撤离或超时
- **THEN** 拾取物不重复归属，成功带出才在个人限额内入账，既有部件和收藏不会因争抢失败而减少。
#### Scenario: 断线与重投
- **WHEN** 客户端或服务器中途重启，或再次投递已结算场次
- **THEN** 恢复同一事件或确认其终局，归还机体占用，玩家只得到一次应得的收益。

### Requirement: 秘宝按个人容量准入
双人秘宝 SHALL 允许每人最多部署 6 台且最多 12 指挥点；单人上限为 12 台且 24 点。
#### Scenario: 好友额度独立
- **WHEN** 一名队员超出自己的额度而队友仍有余额
- **THEN** 阻止该阵容，保留队友的名额和机体。
#### Scenario: 两人确认同一份阵容
- **WHEN** 双方都已选好且确认当前阵容
- **THEN** 服务端核对两人的个人预算并将队伍排入匹配；一方改选后旧确认失效。
#### Scenario: 单人参加
- **WHEN** 单人选择 12 台共 24 点并确认
- **THEN** 可正常进入匹配。

### Requirement: 小屏能操作秘宝拾取与撤离
秘宝战场 SHALL 在受支持的小屏横屏尺寸显示可触达的战斗操作并留出地面移动区域。
#### Scenario: 玩家带货撤离
- **WHEN** 玩家点地靠近货物、拾取、返回己方门并确认撤离
- **THEN** 关键按钮在屏幕内可实际触控，玩家能看到本人撤离结果。

### Requirement: 秘宝固定场地采用可编辑场景组合
秘宝战场 SHALL 在 Godot 场景中提供可独立检查的固定地标。
#### Scenario: 编辑和进入争夺现场
- **WHEN** 作者打开战场场景或玩家进入一场新事件
- **THEN** 可定位双侧撤离门、门牌及五段轨道，玩家看到的地标与实际撤离方向相符，动态货物独立响应权威状态。

### Requirement: Direct target selection in contested treasure
The treasure battlefield SHALL let a player issue a focus command to a particular visible living enemy by tapping or clicking it with their current selection.
#### Scenario: Pick a farther support unit
- **WHEN** a player selects their fire support group and taps a support enemy behind another enemy
- **THEN** one command targets the tapped enemy using the selected owned robots and the server reflects that focus.
#### Scenario: Ground and shortcut actions
- **WHEN** the player taps empty terrain or presses the nearest-target button
- **THEN** terrain orders movement and the shortcut still selects the nearest eligible enemy.

### Requirement: Protected treasure participation reward
The service SHALL award one common component for the first eligible personal settlement per account and UTC match-start day. The client SHALL distinguish actual cargo deposits and participation reward deposits and explain eligibility before entry.
#### Scenario: Eligible owner loses temporary cargo
- **WHEN** a player picks up an item successfully and later times out or becomes disabled
- **THEN** temporary cargo is lost and the eligible player receives the participation reward up to free warehouse capacity.
#### Scenario: Independent and bounded
- **WHEN** a teammate picks up an item, another result arrives that day, a receipt is reopened, or storage is full
- **THEN** only the actual picker qualifies, daily entitlement is consumed once even at capacity, extraction cargo is deposited first and totals match stock.

### Requirement: Bounded rare salvage from personal extraction
The service SHALL provide one independent personal rare-part opportunity per UTC match-start day when the player extracts cargo, and show the odds, guarantee progress and outcome before and after play.
#### Scenario: Eligible personal extraction
- **WHEN** a player extracts at least one cargo item on their first eligible settlement for that match-start day
- **THEN** they get a 20 percent chance for a usable reinforced boiler, guaranteed after two misses, even when resource storage is full; issuing the part clears the personal guarantee progress.
#### Scenario: Capacity and isolation
- **WHEN** the free part warehouse is full on a winning roll, or a player leaves without cargo, or only their teammate extracts
- **THEN** a full warehouse retains a guaranteed next eligible opportunity with no material grant, while an ineligible player spends no opportunity and changes no progress.
#### Scenario: Replay and daily bound
- **WHEN** the client reconnects, repeats extraction, or extracts again on the same match-start day
- **THEN** the earlier receipt stays stable and no extra part or progress is awarded.
#### Scenario: Review a full parts warehouse before entry
- **WHEN** the player reviews the opportunity with no free part storage
- **THEN** the lobby explains that a successful roll cannot deposit a part, consumes that day's opportunity and preserves the next guarantee.

### Requirement: Recognizable industrial toy treasure sites
The contest SHALL display an authored, site-specific industrial diorama matching the server's matched event throughout play and reconnection.
#### Scenario: Three recognizable locations
- **WHEN** the three event sites are played from the same camera angle
- **THEN** each has distinct thematic landmarks and ground treatment, with both gates, active cargo and player units readable.
#### Scenario: Rejoin the original room
- **WHEN** a player resumes their seat or their device clock differs from the server
- **THEN** the same room keeps its original art and tactical interactions, including ground movement, pickup and extraction.

### Requirement: 大厅写意图必须基于有效视图
秘宝大厅 SHALL 在首次有效视图到达前及读取失败后禁止创建、提交、确认或取消写入。读取失败、超时、同步请求启动失败或无效响应结构须使未发送的待处理意图失效；后续读取成功只能恢复当前视图，不能复活已失效意图。

#### Scenario: 初始与读取失败
- **WHEN** 首次读取尚未成功，或玩家在刷新中点击操作后该读取失败
- **THEN** 初始按钮不访问空视图，失败不发送缓存写请求，提示刷新/重新核对，后续自动轮询成功不自动执行旧点击

#### Scenario: 无效成功响应
- **WHEN** HTTP成功但响应无法提供页面所需的有效秘宝视图
- **THEN** 不恢复写入口或消费待处理意图，不以空字典/残缺成员数据继续确认

### Requirement: 成功刷新须按相关上下文复核待处理意图
大厅 SHALL 至多保留一个刷新期间的待处理写意图，并保留点击时的请求体及机体顺序。成功刷新后，仅在该操作相关事件、队伍、版本、选择和可见点数仍有效时最多发送一次；相关上下文改变须丢弃并要求重新确认。无关显示变化及同阵容的队友正常确认不得误使合法意图失效。

#### Scenario: 原意图仍有效
- **WHEN** 创建、提交、单人确认、双人确认或取消在刷新后仍满足各自相关条件
- **THEN** 至多发送一次原请求，名单顺序不被刷新重建，不能额外添加服务不接受的字段

#### Scenario: 阵容或目标改变
- **WHEN** 与该操作相关的事件、队伍/成员、版本或用户输入改变，或该操作所选机体的可派性/可见点数改变
- **THEN** 不用新视图静默构造另一操作，显示当前状态并让玩家重新核对；单人确认不依赖不存在的版本字段

#### Scenario: 正常队友确认与取消目标
- **WHEN** 同一双人阵容的队友仅推进确认状态，或取消同一未入场队伍时仅机器人选择改变
- **THEN** 不把这些无关变化误判为操作目标变更，仍按本人确认状态和队伍阶段判断；本人已确认/排队不再次确认，出现入场凭证不再发送旧大厅写

### Requirement: 关闭与旧回调不得产生新大厅副作用
页面 SHALL 在通知上层关闭前失效本页请求/意图生命周期。旧请求、已取消请求或旧页面的回调不得改变新请求的忙状态、视图或发送待处理写；进入战斗凭证出现时须先清待处理大厅意图。

#### Scenario: 离页与延迟响应
- **WHEN** 玩家关闭页面后旧读取或写回调到达，即使页面尚未在帧末释放
- **THEN** 不再发送尚未发送的排队写，也不污染新页面/请求；现有战斗清理仍按其生命周期执行

#### Scenario: 请求实例退役
- **WHEN** 请求取消或同步启动失败后新请求已开始
- **THEN** 旧实例回调不能结束新请求或推进其意图，失败和后续恢复各自反馈准确

### Requirement: 未知写结果只核对当前事实
大厅 SHALL 对结果未知的已发送写请求读取当前队伍、名单、确认/排队或入场事实，且不自动重发POST。取消本地请求或离开页面不代表撤销服务端已在途事务，未取得回执的状态观察不能伪称原写请求成功。

#### Scenario: 写已提交但响应丢失
- **WHEN** 创建、提交、确认或取消可能已在服务执行而响应未知
- **THEN** 后续读取展示当前事实，未自动重发原写；不会因本地取消要求服务回滚已提交操作
