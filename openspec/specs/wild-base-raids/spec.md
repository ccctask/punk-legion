# wild-base-raids Specification

## Purpose
规定私人基地野生机器人袭击的预警、财富估值、锁定防守布局、驻防机体与炮塔行为，确保在线及离线共用裁定和损失保护，并可追溯每次结算。

## Requirements

### Requirement: Bounded authoritative wild raids on private bases
A private base SHALL receive advance warning of a wealth-scaled capped raid. The defense layout SHALL track committed base and platform edits during the warning, lock at the authoritative battle start, and settle a bounded outcome exactly once regardless of owner presence.
#### Scenario: Warning, defense and recovery
- **WHEN** an owner restores power or installs a module on a defensive platform before the attack begins
- **THEN** the warning and the battle use the updated layout with the original threat and schedule, powered fixed defenders act within their ranges, and the owner receives a report and a recovery interval
#### Scenario: Start deadline and replay
- **WHEN** a defense change takes effect at or after the start, including when the first post-deadline request is the edit itself
- **THEN** the current raid and its replay retain the last committed pre-start defense; otherwise-permitted changes still apply to the private base and in-use platform modules remain locked
#### Scenario: Bounded offline losses
- **WHEN** an offline owner loses a raid
- **THEN** protected resources and owned robots, equipped parts and blueprints survive, total material and repair losses obey their limits, and the same raid cannot be charged twice
#### Scenario: Current wealth and threat
- **WHEN** an owner dispatches robots or loses assets
- **THEN** deployed robots still count toward current wealth, enemy budgets remain capped and subsequent threat responds to the current account state

### Requirement: 既有袭击存档兼容
档案服务 SHALL 从带或不带离线等待字段的既有第七版数据库迁移，同时保留实际玩家身份、袭击记录与保护时间。
#### Scenario: 旧版结构重启
- **WHEN** 更新后服务打开任一种已有 v7 存档
- **THEN** 玩家可以登录、查看原有档案和营地，已结算袭击不会因升级再扣一次，重复启动仍能服务。

### Requirement: Current stock exposure in a raid warning
The warning SHALL describe eligible resources above each insured floor and the combined maximum loot from the owner's current stock, separately from any repair cost.

#### Scenario: Viewing and refreshing a warning
- **WHEN** an owner views a warning and then refreshes after a stock change
- **THEN** eligible amounts and the combined upper bound reflect the current stocks and existing loot cap, including zero at or below all floors, without charging the owner or determining the random outcome.

#### Scenario: After the raid
- **WHEN** the owner opens the settled defense report
- **THEN** the report shows actual losses from its receipt and the warning estimate is absent.

### Requirement: Raid view represents the registered guard
The private base raid view SHALL hide the home showcase robot and its name while displaying a warning, live raid or replay. Only the registered guard from the raid may appear as a defending robot.

#### Scenario: Opening and leaving defense
- **WHEN** the owner opens a raid with or without a registered guard, returns home, and reopens it
- **THEN** the raid consistently shows exactly its registered defenders, and returning restores the current home presentation with the owner's named showcase robot when available.

### Requirement: Count completed private production once for threat
The server SHALL value completed, claimable private production at the same resource weights as stocks when freezing a raid warning. It SHALL apply the production limits at the scheduled warning and preserve both the frozen budget and the original stock-only loss rules.

#### Scenario: Same production with different claim timing
- **WHEN** two otherwise equivalent owners claim immediately before and after the warning boundary
- **THEN** their frozen wealth and enemy budget match, each resource is counted once, and subsequent real spending may reduce future wealth.

#### Scenario: Offline production and insured stock
- **WHEN** a warning is processed late while a production line partly or fully completes cycles
- **THEN** only claimable units completed by warning time within storage and offline caps affect threat, later production remains claimable on schedule, and a loss cannot debit unclaimed production.

### Requirement: Render the guard name and status legibly
The raid view SHALL present the registered guard's name and current duty status legibly with supported separators.

#### Scenario: Latin and Chinese names
- **WHEN** a registered guard has a Latin or Chinese name and the player opens its warning or replay
- **THEN** the full name and duty status remain legible without a replacement glyph between them.

### Requirement: 野袭预警保留驻防机身份
预警界面 SHALL 按机体实体身份维持驻防选择，并在失去资格时要求玩家重新选取，允许玩家区分同名机体。

#### Scenario: 驻防候选顺序变化
- **WHEN** 所选机体仍可驻防，名单中有其他机体移除或重排
- **THEN** 显示及登记的仍是原先选中的机体

#### Scenario: 所选机体失去资格
- **WHEN** 玩家选好的机体失去资格且仍有其他候选
- **THEN** 界面提示重新选机，直到玩家主动选择前均不能提交另一台机体

### Requirement: Inspect the damaged guard from a settled raid
A settled raid SHALL distinguish loot debited by settlement from the guard's subsequent repair charge and allow the player to inspect the current condition of the exact damaged guard.

#### Scenario: Inspect a damaged guard after defense
- **WHEN** the player opens a settled raid with guard damage and selects the guard's condition
- **THEN** the current condition or an explicit unavailable state is shown for that guard without charging or selecting another robot.

#### Scenario: Reopen a past defense
- **WHEN** the guard has already been repaired
- **THEN** the report retains its original loss while the linked condition shows the current state.

### Requirement: Recover a lost defense read in place
The client SHALL retry transient failures of defense status and linked guard condition reads with bounded delays and preserve the intended target for manual retry.
#### Scenario: Temporary unavailability
- **WHEN** a defense read fails then the service recovers
- **THEN** the client initially allows at most two rapid GET retries and preserves the view.
#### Scenario: Visible active raid outlasts rapid retries
- **WHEN** an open warning or live defense with a confirmed snapshot remains temporarily unreachable after the rapid retries
- **THEN** the client retains its last confirmed frame, permits manual refresh, and queries status once per ten seconds until a valid response, permanent failure, or departure, without repeating a write.
#### Scenario: Settlement or guard registration has an uncertain reply
- **WHEN** the client must reconcile an ambiguous write result
- **THEN** any automatic recovery is read-only and cannot repeat a charge or guard assignment.

### Requirement: Preview the incoming raid path
The private raid warning SHALL show the entry direction and the incoming path used by the authoritative simulation for its current defense layout.
#### Scenario: Preparing a branched defense
- **WHEN** the commander sees a warning and commits a layout change that redirects the approaching robots before battle
- **THEN** the same warning reflects the new ordered path to the core and distinguishes that path from unused roads.
#### Scenario: Viewing the actual defense
- **WHEN** the warning ends or the commander returns to the base
- **THEN** preview markers leave the view and the battle follows the last accepted pre-start layout.

### Requirement: Budgeted wild raid enemy formations
Private raid warnings SHALL identify the enemy types and counts that actually participate, with distinguishable patrol and heavy dismantler behavior in battle and replay.
#### Scenario: An established base faces a mixed wave
- **WHEN** the seeded raid budget permits heavy machines and the scheduled formation includes them
- **THEN** their higher durability, slower advance and two-point cost are reflected in the simulation and the visible battle uses the advertised types and total count.
#### Scenario: A small base or an offline defense
- **WHEN** a low-budget warning is scheduled or an owner misses a battle and later views its report
- **THEN** low-budget waves keep patrol behavior and replay uses the same composition, outcome and bounded loss as the authority.

### Requirement: Bounded private raid recovery pressure
The service SHALL freeze a bounded recovery adjustment when scheduling each private raid warning. The normal warning screen SHALL show a positive reduction with its reason and resulting threat budget.
#### Scenario: Owner is recovering after a private defense loss
- **WHEN** the most recent settled private raid was a loss
- **THEN** deduct one threat point and deduct one more if its registered guard still needs repair, down to a final minimum of two; repeated losses do not stack.
#### Scenario: The situation changes after the warning
- **WHEN** an owner repairs, relogs, or reopens the replay after the warning
- **THEN** the displayed and simulated budget and roster remain the ones frozen for that encounter; a later warning after victory uses the normal wealth budget.

### Requirement: Read encounters from a powered relay base
The defense view SHALL accept valid frozen private-base layouts containing power relays in the warning, live and settled phases.
#### Scenario: Inspect a defense after extending power coverage
- **WHEN** a player builds a legal relay and reopens a real defense containing that building
- **THEN** the view shows the actual defense layout and battle state, supports playback after settlement and still rejects unknown or malformed buildings.

### Requirement: Bounded facility downtime and recovery after a breach
The private raid SHALL persist at most one damaged production facility on defeat, show its identity, repair price and recovery time, and exclude only that facility from productive operation until it recovers. The service SHALL cap raid loot plus quoted robot and facility repairs at four resource units.

#### Scenario: Repair a breached facility
- **WHEN** the owner returns after defeat and repairs the affected workshop or foundry for one structure
- **THEN** the base identifies the location and restores operation when powered, existing output is retained, and repeated repair submissions cannot charge twice.

#### Scenario: Offline recovery
- **WHEN** the owner remains offline past the ten-minute downtime and later claims production
- **THEN** production credits eligible time before and after downtime under the usual caps, unaffected facilities continue, and the owner owes no fee for natural recovery.

#### Scenario: No eligible building
- **WHEN** a raid succeeds defensively or no eligible facility exists
- **THEN** no facility is stopped or repair fee quoted.

### Requirement: Independently targetable salvage swarm
The authority SHALL sometimes allocate three existing threat points to a burst of three light salvage drones in an eligible private raid. The warning, battle and replay SHALL identify the same individual enemies.

#### Scenario: Inspect and counter a burst
- **WHEN** a commander sees a swarm warning and changes powered tower coverage before combat
- **THEN** three distinguishable drones enter together, receive individual shots and may be intercepted individually according to the frozen layout.

#### Scenario: Bounded losses and repeat viewing
- **WHEN** the raid is resolved and reopened after login
- **THEN** enemy identities, shot targets, breaches, result and settlement remain reproducible; low budgets remain swarm-free and no additional raid loss is charged.

### Requirement: Recovery interval follows the private raid outcome
The private raid authority SHALL schedule the next formal warning at least 48 hours after a loss and 24 hours after a win, preserving the existing owner-return protection. The defense report SHALL explain the applicable recovery interval.
#### Scenario: Recover from a loss
- **WHEN** the owner returns before the 48-hour recovery period ends, including after a loss with no exposed stock
- **THEN** the next warning keeps the same deadline and no new raid or debit occurs before that deadline
#### Scenario: Return after the recovery period
- **WHEN** the owner remains offline beyond the deadline and later returns
- **THEN** the authority grants the existing 24-hour return interval and never settles missed raids in a batch
#### Scenario: Successful defense
- **WHEN** the player wins and returns before the recovery period ends
- **THEN** the protection timer continues toward the original 24-hour deadline

### Requirement: Outcome-first private defense report
A settled defense report SHALL present the authoritative outcome, actual loot debits and damage status before the defense roster, with optional details and replay available from the report.
#### Scenario: Return to a heavily defended base
- **WHEN** an owner opens a settled report in a compact landscape viewport with multiple platforms
- **THEN** the outcome and actual resource loss are visible without scrolling and the player can inspect the recovery interval, expand the full roster and replay the same raid
#### Scenario: Separate incurred losses from possible repairs
- **WHEN** the raid has zero loot or a guard or facility is damaged
- **THEN** the summary shows the actual loss including zero, identifies damage and keeps any future repair quotes distinguishable from charged resources
#### Scenario: Refresh an open report
- **WHEN** the owner expands details and refreshes the same receipt or starts its replay
- **THEN** the receipt and stock remain unchanged and a same-report refresh preserves the chosen disclosure state

### Requirement: Three-hour formal raid warning
The server SHALL schedule private base raid combat to start three hours after the scheduled formal warning, using the same deadline for all sessions of that raid.

#### Scenario: Owner returns during the warning
- **WHEN** an owner returns two hours after the formal warning began
- **THEN** the base displays the remaining hour, the same encounter and its current material risk, and accepts otherwise valid defensive preparations until the scheduled start.

#### Scenario: Lock and offline settlement
- **WHEN** combat starts after the three-hour window and the owner is away
- **THEN** the last committed pre-start defense is locked for that encounter, and offline and later viewing paths produce one settlement.
