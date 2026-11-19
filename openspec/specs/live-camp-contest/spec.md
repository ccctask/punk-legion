# live-camp-contest Specification

## Purpose
规定开放日程内真实玩家争夺公共资源营地的阵容锁定、固定部署、实时指挥、核心占领、有限产出与归属转移，确保断线重启可恢复、同场只结算一次。

## Requirements

### Requirement: 时窗内的实时攻守
玩家 SHALL 按服务器公布的时窗，以自有机组参与实时营地争夺，攻守两方各自遵循总计 24 指挥点和 12 台上限。
#### Scenario: 已部署守军与防守者缺席
- **WHEN** 攻方进入一个玩家未上线的公开营地
- **THEN** 只有已实际部署的机体和炮塔自动执行基础行为，攻方可完成占领，守方上线可接回本人机组控制。
#### Scenario: 同时挑战
- **WHEN** 两支攻方同时申请同一据点
- **THEN** 服务器只创建一场有权改变归属的对局，其他请求得到明确结果，未投入的机体与资源可继续使用。

### Requirement: 唯一归属与有限收益
服务器 SHALL 对战果、归属、有限产出和战损执行可重放验证的单次结算。
#### Scenario: 重连或异常结算
- **WHEN** 双方掉线、房间重启、窗口关闭或终局结果重复送达
- **THEN** 可恢复同场状态或确定终局，归属和资源只处理一次，机体可恢复正常派遣。
#### Scenario: 保护边界
- **WHEN** 公开营地易主
- **THEN** 旧营主失去该地控制与对应后续收益，私人库存、主基地、已得部件与蓝图保持归属，营地数、驻防数量与领取额度均受服务端校验。

### Requirement: 合法的攻守部署位置
营地房间 SHALL 将每台机体与固定塔生成在权威战场边界内，使用互不重叠、可从核心到达的开放格。
#### Scenario: 双方满预算部署
- **WHEN** 满员攻守阵容进入黄铜转运场，包括架设炮塔与援军
- **THEN** 所有实际单位完整生成并能有效参战，固定塔保持禁移，人数、射程与胜利条件不因部署修复而变化。

### Requirement: Two public camps with independent stocks and garrisons
The game SHALL allow a player to hold both Brass Yard and Coil Depot with independent garrisons, production, capacity, and ownership, while enforcing one assignment per robot.

#### Scenario: Hold two camps
- **WHEN** the owner of both camps deploys distinct robots and collects from each
- **THEN** Brass Yard credits structure and Coil Depot credits components up to each resource storage limit, with excess held at its producing camp.

#### Scenario: Lose only the depot
- **WHEN** a different commander captures the depot and the outcome is retried
- **THEN** only its ownership, local stock and affected garrison change once, and the yard and private inventory remain intact.

### Requirement: Show reliable camp actions during overview loading and recovery
The console SHALL show the selected territory immediately and offer camp actions based on its authoritative overview or a valid battle seat.
#### Scenario: First read is delayed or fails
- **WHEN** a player opens either camp and its initial overview is delayed or unavailable
- **THEN** the player can identify the camp, read its loading or recovery status and return to the map without being offered attack, garrison or claim actions.
#### Scenario: Overview arrives or is recovered
- **WHEN** the server supplies the camp overview after a delay, changed ownership or a failed read
- **THEN** the console exposes the actions for that player's current role, retains valid selection, and normal successful polling leaves usable controls stable.

### Requirement: Settle a camp battle at its time limit
The camp room and profile SHALL use a consistent terminal timestamp for regulation play and settle previously persisted valid timeout results affected by numeric rounding.
#### Scenario: Live camp reaches regulation time
- **WHEN** an authoritative camp simulation with surviving damaged robots reaches the 180-second limit
- **THEN** both sides receive the authoritative contest result and the single ownership and damage outcome releases the original sortie assignments.
#### Scenario: Recover the prior room result
- **WHEN** a previously stored legitimate 1010 timeout result is drained or redelivered
- **THEN** its original contest reaches the same terminal state once, with strict validation of materially invalid reports.

### Requirement: 公开营地采集设施
服务端 SHALL 允许营主为当前占领的每个资源营地投资建设一座采集站，并在当前任期内按界面承诺的周期生产、按营地上限存放。
#### Scenario: 领主建设并领取
- **WHEN** 营主确认建设、重复提交并于产出后领取
- **THEN** 私仓支付一次费用，保留已生产份数及在制进度，领取当地材料，满仓停止产出。
#### Scenario: 失守后重新占领
- **WHEN** 营地在攻防中易主，原营主再度占领
- **THEN** 各任期独立计产，之前建成的采集站及库存清除，新营主可重新建设。

### Requirement: Live attacker presence for earning or winning a capture
The public camp room SHALL retain earned attacker progress during the principal attacker's reconnect grace and resume capture only after that principal authenticates in time. Ordinary combat, defender capture, and the match clock continue.

#### Scenario: Dropping on the core
- **WHEN** the principal attacker disconnects with an attacking unit on the core, including when allied aid remains online
- **THEN** attacker progress does not increase and an unattended force cannot win by core control or timeout; reconnecting in time resumes the same progress and original remaining round time.

#### Scenario: Expiry and recovering a room
- **WHEN** the reconnect deadline or match deadline passes before authentication succeeds, including across a room restart
- **THEN** an absent attacker cannot recover a winning seat; surviving garrisons, the same unique settlement, and existing player ownership of robots are preserved.

#### Scenario: Local loss of room connection
- **WHEN** the connection is lost while the client holds a previous battle snapshot
- **THEN** the battle view indicates the interruption, offers return to the original room, and suppresses commands until the authenticated snapshot or final receipt arrives.

### Requirement: Visible camp roster capacity
The camp lobby SHALL show the current combined unit count and command cost before the player commits a garrison or starts a new attack, including the effective aid reserved for this camp and side.

#### Scenario: Choosing an affordable roster
- **WHEN** the player selects or deselects a robot, or marks one selected defender as stationary
- **THEN** the lobby immediately shows its actual mounted cost and combined occupancy against both limits; a stationary garrison uses its normal cost exactly once.

#### Scenario: Editing around another player's reservation
- **WHEN** a fresh overview includes accepted aid that takes the selected roster over either cap
- **THEN** the player sees the excess and can revise the roster; submitting a new over-budget force is unavailable, and returning to an existing seat remains possible.

#### Scenario: Public window is replaced before a pending attack starts
- **WHEN** the server replaces the camp window after issuing a pending attack seat
- **THEN** the obsolete reservation is unavailable for a new entry, an already-started fight remains reconnectable, and a new valid window uses only its applicable aid reservations.

### Requirement: Show the collectible territory yield
The camp owner SHALL see the current collectible quantity, private free space for the local resource, and the amount left at the camp before collection.
#### Scenario: Partial transfer or uncertain acknowledgment
- **WHEN** the private warehouse has less room than the available yield
- **THEN** the partial transfer matches the authoritative receipt, the excess remains locally available, and an uncertain submission can recover its original receipt without a second credit.

### Requirement: 攻方营地出征补给
营地服务器 SHALL 在黄铜转运场与线圈港首次成功开战时仅向进攻发起者收取 1 私仓能源，向玩家显示报价，并通过持久收据支持复核。

#### Scenario: 预约与首次开战
- **WHEN** 攻方先查看报价、登记并预约，随后经房间验证进入实时战斗
- **THEN** 仅成功开战产生一次费用，守方与援军不承担攻方费用，同场重连免费

#### Scenario: 余额变化或竞争失利
- **WHEN** 报价后能源耗尽，或另一攻方先开场
- **THEN** 失败者不付费，机体不被派遣，救援凭证保持原数

#### Scenario: 最后一份能源用于开战
- **WHEN** 攻方开战后余额为零并接回席位
- **THEN** 接回正常，显示已开战的信息，不需要再次支付

### Requirement: Discover and answer a live attack on an owned public camp
A player on the normal private base or public map SHALL see which owned camps are under live attack within five seconds on a healthy local connection, and SHALL be able to open that camp's existing defense console from the alert.

#### Scenario: Owner responds from home
- **WHEN** an adversary begins a real contest while the owner remains at the base
- **THEN** the owner can discover it without first selecting a camp, enter the same match and command the garrison.

#### Scenario: Two locations and a completed battle
- **WHEN** two owned camps are contested, either contest ends, or the owner returns to the foreground
- **THEN** each pending response refers to its own live location, a settled attack ceases to be offered, and another account cannot receive owner-only actions.

### Requirement: Recover a camp room from valid local evidence
After a restart the room SHALL prefer a valid terminal result for the same contest, otherwise attempt the last valid checkpoint, and permit normal expiry when neither can establish a result.

#### Scenario: Torn terminal write
- **WHEN** an incomplete terminal file accompanies a valid checkpoint for a live contest
- **THEN** the room recovers the correct contest under the ordinary clock and admission rules and submits at most one accepted settlement.

#### Scenario: Exhausted evidence
- **WHEN** both local records are unreadable or the service has already closed the contest
- **THEN** the room continues to serve other contests, stops repeatedly parsing the same invalid data, and preserves the authoritative settlement and loss bounds.
