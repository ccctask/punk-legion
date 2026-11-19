# party-expedition Specification

## Purpose
规定两人及三人如何邀请、整备和协作探索，使各人只指挥自有机体，在共享预算和房间内完成目标、断线恢复并获取独立的战绩、损伤和有限奖励。

## Requirements

### Requirement: Cooperative expeditions for two or three players
Players SHALL join a shared non-occupiable expedition using independent accounts and owned squads, with readiness, joint objectives and server-authoritative per-player results.
#### Scenario: Form and finish a party
- **WHEN** two or three invited players ready distinct owned squads within the room budget
- **THEN** they enter one mission, command only their own robots, and receive their own durable rewards, battle records and damage.
#### Scenario: Membership interruption
- **WHEN** the leader leaves the lobby or a participant disconnects during play
- **THEN** the other members can continue or leave, the disconnected member may recover the same mission within its window, and no robot remains permanently reserved.
#### Scenario: Three-player scale
- **WHEN** three clients enter and complete a mission
- **THEN** observed wait time, peak friend and enemy unit counts, and device performance are recorded for that actual encounter.

### Requirement: 成员独立结束已结算的合作回合
每名队员 SHALL 能在自己的已结算回合选择收工并返回基地，且重复请求只产生同一效果。
#### Scenario: 队友先开新局
- **WHEN** 三人已结算，其中两人原队再次出发，第三人仍在旧回合战果页选择收工
- **THEN** 第三人返回基地，个人战果保留，已开启的下一局和队友状态保持有效。
#### Scenario: 战果页请求暂时失败
- **WHEN** 收工请求因临时错误失败
- **THEN** 玩家能在战果页读到原因并重试。

### Requirement: 组队探索准备前可核对实际出发报价
组队探索大厅 SHALL 在勾选或取消机体时立即展示个人草案、整队预计台数与点数，以及本人实际出发需支付的费用。
#### Scenario: 与已准备队友核对预算
- **WHEN** 玩家更改勾选或收到队友新的准备状态
- **THEN** 显示与实际装配一致的预算，个人机体只计入一次，指出空编或超过整队上限，玩家可以调整。
#### Scenario: 支付来源及资格变化
- **WHEN** 玩家拥有能源、仅有救援凭证或两者均无
- **THEN** 大厅分别说明出发消耗，准备和报价不扣费；若选择的机体已不可用，更新草案和报价。

### Requirement: 合作战场显示真实的队员连接状态
合作探索 SHALL 为本场玩家展示各席位当前是否已连接、正在等待连接或已离场，以权威房间状态为准。
#### Scenario: 已登记的队友尚未进房
- **WHEN** 第一人进房，另一个已登记的队友还未连接
- **THEN** 两人状态能区分，队友成功认证后变为在线。
#### Scenario: 离线与重连
- **WHEN** 队友断线、在宽限内重连或已经撤退
- **THEN** 正常战场面板显示相应变化，已离场的席位不会被显示为在线。

### Requirement: 合作探索在全员到场或集结截止后开战
合作房间 SHALL 在首名队员认证后等待全员，最长 30 秒；集结期间不消耗战斗时间或执行战斗操作。
#### Scenario: 队友提前到齐
- **WHEN** 最后一位队员在截止前到场
- **THEN** 立即开战一次，战斗从初始状态开始。
#### Scenario: 部分队员缺席
- **WHEN** 到固定截止时间仍有队员缺席
- **THEN** 已到场的队员开战，缺席者按个人规则过期；没有在线玩家时终结本场。
#### Scenario: 等待重连和恢复
- **WHEN** 等待期间队员重连或本轮服务恢复
- **THEN** 按原定截止执行，已经开战的场次不会重新集结。

### Requirement: 合作探索的独立个人战报
客户端 SHALL 在锈轨队伍与泵房结算展示本人的场次结果、实际收支、出征机体本场贡献及战损报价，并保留原有收工及续队动作。
#### Scenario: 队员各自结算
- **WHEN** 队友有不同参战状态、战损或个人奖励
- **THEN** 每人看到本人的材料、战损和维修报价，不把队友收益或未到场机体计作本人贡献。

### Requirement: 集结只等仍有资格进场的队员
房间 SHALL 在仍有资格参战的队员全部在线时立即开战，且人数提示使用相同口径。
#### Scenario: 已有人主动退出
- **WHEN** 三人集结中一人主动退出，另外两人先后到齐
- **THEN** 分母变为二，最后一人到场后立即开战；退出者仍在原席位名单中，个人回执显示未参战。
#### Scenario: 暂时断联或无人到场
- **WHEN** 有人尚未到场或暂时掉线且未退出
- **THEN** 继续等到其归队或最初三十秒截止，截止时只有在线的有效席位参战，无有效在线席位则不启动战斗。

### Requirement: 房间战术标记权随队长正式离场交接
房间 SHALL 在队长席位终止时按原入队次序将标记权交给下一位仍有资格的队员，并向各端展示同一身份。
#### Scenario: 队长撤退后继续指挥
- **WHEN** 原队长发出建议并主动撤退
- **THEN** 原标记清除，继任者可立即标记，其他人仍只能指挥自己的机体。
#### Scenario: 重连与截止
- **WHEN** 队长短暂断线或已离场者重新接入，或房间从本场检查点恢复
- **THEN** 短暂断线保留原职权；席位终止才交接；已发生的继任在重连及恢复后仍有效。

### Requirement: 连续快照中的选机操作
客户端 SHALL 在同一大厅内保持可用机体的输入连续性，更新队友状态及资源报价；每次有效点击只改变一次选择，已失去可用性的机体应从可提交阵容排除。

#### Scenario: 按住选机项时收到队友更新
- **WHEN** 玩家按下可用机体的选机项，收到同一房间快照，然后在原按钮上松开
- **THEN** 该次选择生效一次，报价和准备请求对应新的名单

### Requirement: Distinguish assembly exits in personal reports
The client SHALL identify voluntary withdrawal during assembly separately from a seat expiring before deployment in live and reopened personal reports.

#### Scenario: A commander exits before the squad starts
- **WHEN** a non-participating commander receives a retreat receipt
- **THEN** the summary and report identify withdrawal during assembly and show the recorded departure cost.

#### Scenario: A seat expires before deployment
- **WHEN** a non-participating commander receives an expired receipt
- **THEN** the summary and report identify assembly expiry without attributing a voluntary withdrawal.

### Requirement: 锈轨公开寻找合作队友
锈轨合作入口 SHALL 允许两名无好友关系、没有邀请码的玩家主动匹配同一任务。搜索与取消免费，不占用机体。匹配成功后双方在同一大厅自行选机和准备。

#### Scenario: 同时搜索
- **WHEN** 两人主动寻找队友并重复刷新
- **THEN** 服务端将两人各一次加入同一锈轨大厅，继续原有准备和出发流程

#### Scenario: 搜索取消或中断
- **WHEN** 等待者取消或停止续租超过期限
- **THEN** 后续搜索不会匹配该等待者，账户能源及机体派遣保持原状

#### Scenario: 仅显式搜索参与匹配
- **WHEN** 其他玩家处于好友邀请码大厅或泵站
- **THEN** 公开匹配不会加入这些房间，也不会抽走其中成员

### Requirement: 当前匹配状态反馈
锈轨大厅 SHALL 在新搜索期间清除旧的取消反馈和无关的上一场摘要。

#### Scenario: 取消后再次寻找
- **WHEN** 玩家在已确认取消后再次寻找并收到等待状态
- **THEN** 等候区与下方提示均与当前搜索一致，匹配成功后可正常准备

### Requirement: Command availability across the assembly transition
A cooperative expedition client SHALL enable a present active player's commands when the authority confirms combat has started, including when a movement update arrives before the phase confirmation.

#### Scenario: First combat update arrives ahead of the phase confirmation
- **WHEN** an assembling client receives the same mission's combat movement update before its authoritative start frame
- **THEN** it waits for confirmation and then displays active combat controls, applies subsequent movement updates, and can issue its own order.

#### Scenario: Assembly still pending
- **WHEN** no authoritative start has arrived
- **THEN** movement commands remain unavailable and the client displays the assembly state.

### Requirement: 合作大厅读取状态与安全操作
客户端 SHALL 区分首次读取、有效队伍、读取恢复、重试耗尽和登录失效。未取得有效快照或读取已失效时禁止依赖队伍数据的写操作，保留退出与恢复入口；成功恢复清除读取错误并保留仍有效的选机草案，不误清独立业务错误。

#### Scenario: 首次读取失败后恢复
- **WHEN** 首次GET临时失败，下一次GET成功
- **THEN** 玩家无需手动刷新即可看到队伍，读取错误消失；首次有效快照前出发和复制邀请码不访问空数据，也不产生写请求。

#### Scenario: 持续失败和登录失效
- **WHEN** 大厅连续读取失败或服务明确返回登录失效
- **THEN** 临时失败最多自动重试两次，耗尽后停止并提供手动刷新；登录失效立即停止自动请求并指向重新登录，已有名单不冒充新确认状态。

#### Scenario: 已有队伍恢复与业务反馈
- **WHEN** 已有队伍短暂断联后恢复，或最近一次准备被服务明确拒绝
- **THEN** 恢复只清读取错误，原房间内仍有效的选机保留，独立的准备业务错误保持可读。

### Requirement: 合作大厅读取生命周期与排队意图
客户端 SHALL 在后台、不可见、战报遮罩或关闭时停止普通大厅读取；恢复可见时重新确认状态。只在成功读取且owner与room上下文相同时发送一次用户排队操作；读取失败或上下文变化时明确告知未发送。自动读取恢复不得自动重投POST。

#### Scenario: 读取期间准备与换队
- **WHEN** 玩家在后台GET期间重复点击准备，随后GET成功、失败或显示不同队伍
- **THEN** 同队成功至多发送一次准备；失败或换队不发送旧意图，恢复后不偷偷执行，并给出明确反馈。

#### Scenario: 后台与迟到响应
- **WHEN** GET在途时界面隐藏、应用暂停或关闭，旧回复随后抵达
- **THEN** 不再轮询、不触发失效界面的排队动作；恢复时只接纳当前读取结果，关闭后不再发送请求。

#### Scenario: 写请求回复丢失
- **WHEN** 准备等POST已被服务处理但客户端未收到回复
- **THEN** 客户端通过后续GET核对队伍状态，不自动重发POST，也不把该请求称为未发送。
