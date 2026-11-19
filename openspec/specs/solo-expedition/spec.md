# solo-expedition Specification

## Purpose
定义从私人基地整备自有机器人进入单人回收场、实时指挥、采集和撤离的玩法，以及服务器权威战果、机体损伤、部件掉落与断线后的恢复规则。

## Requirements

### Requirement: Playable persistent solo expedition
A player SHALL enter a server-authoritative expedition alone with a legal owned squad, explore resource nodes, fight staged encounters and a boss, and return to the same base account with a unique outcome.
#### Scenario: Return and deploy again
- **WHEN** the player completes exploration, receives a functional part, repairs and swaps equipment
- **THEN** the next sortie uses those same owned robots with the new loadout and the ledger records the costs and rewards.
#### Scenario: Retreat, defeat or disconnect
- **WHEN** a mission ends through retreat, defeat or expiry, or the player reconnects before expiry
- **THEN** the outcome or resumed state matches the authoritative mission, with at most one set of rewards and damage.
#### Scenario: Repeated solo progression
- **WHEN** a player runs three consecutive missions and uses the rare reward progression
- **THEN** progress is visible, duplicate result delivery cannot advance it, and a functional replacement is attainable through solo play.

### Requirement: 三次锈轨个人胜利解锁钻头配方
档案服务 SHALL 为累计三次亲自通关锈轨回收场的玩家免费解锁永久钻头制造配方，并允许玩家提前在工坊研究同一配方。

#### Scenario: 首胜至第三胜
- **WHEN** 玩家分别以单人或组队身份获得首个、第二个和第三个不同场次的个人胜利
- **THEN** 首胜获得可用钻头并计入一次，第二胜显示 2/3，第三胜获得可实际制造钻头的配方

#### Scenario: 未获胜或重复结算
- **WHEN** 玩家未亲自获胜，或档案再次接收同一场终局
- **THEN** 不额外增加胜利次数或发放配方奖励

#### Scenario: 提前研究
- **WHEN** 玩家在第三胜前通过工坊研究掌握钻头或在第三胜后查看研究
- **THEN** 相同配方可用于制造，已掌握后不能重复扣费

### Requirement: 移动端完整显示钻头制造指引
基地生产面板 SHALL 在小屏横向显示完整的钻头获取条件和掌握后的仓库制造入口说明。
#### Scenario: 成功研究后查看去向
- **WHEN** 玩家在窄屏上研究成功并查看钻头配方
- **THEN** 可读到已掌握状态及前往档案仓库制造的完整指引，文字不会被滚动条或面板边界遮住。

### Requirement: 首次亲自打通锈轨后可快速回收外围
独行准备页 SHALL 向已有锈轨个人胜利的玩家提供可选基础材料回收，独立于真实战斗。
#### Scenario: 成功回收
- **WHEN** 玩家选择一台待命完整机体、具有普通能源及库存空间、当日首次确认
- **THEN** 扣 1 能源，按剩余容量发放至多 2 结构材料，记录唯一回执，机体保持可派。战绩、配方、稀有掉落进度和首胜状态保持原值。
#### Scenario: 重复请求或无法回收
- **WHEN** 同一玩家在同一 UTC 日重复或并发尝试，或前置条件不满足
- **THEN** 同日成功最多一次，失败时资源与次数保持原值，原请求重试返回相同回执，准备页告知结果或原因。

### Requirement: 锈轨个人探索战报
服务端 SHALL 对本人当次出征列示实收、出征费用与净变化，并提供本场机体击败、有效施修、战损与后续维修报价。
#### Scenario: 单人撤退或胜利后查看战果
- **WHEN** 玩家在结算与回到探索准备页时查看同一场的个人战报
- **THEN** 净数匹配入账与出发回执，维修报价单列，重复读取战果不改变库存。

### Requirement: Visible command availability across exploration reconnects
The exploration client SHALL expose combat commands only after the current connection has received an authorized mission state, in solo, party and pump expeditions.

#### Scenario: Connection drops during play
- **WHEN** the transport is lost with the last mission snapshot still visible
- **THEN** the player sees a reconnect action and connection status, and battle HUD, field and minimap cannot issue orders or suggestions.

#### Scenario: Returning to the original mission
- **WHEN** the player reconnects and the server returns the current mission state or a final receipt
- **THEN** the relevant assembly, active, withdrawn or settled controls are shown; stale orders are never replayed.

#### Scenario: Another window has finished the expedition
- **WHEN** the original window reconnects with its admission after the other window has completed the mission
- **THEN** it receives its existing personal receipt without generating another outcome or unlocking combat; a seat transferred to another connected window cannot keep issuing orders.

### Requirement: 单人锈轨出发阵容与预算
单人准备页 SHALL 按档案装配报价显示各机体指挥点、已选台数和合计点数，刷新时保留仍可派遣的选择。玩家只能以一至十二台且合计至多二十四点的合法阵容新开场次，已有活动可恢复。

#### Scenario: 刷新保持手动草案
- **WHEN** 玩家改变或清空选择并刷新准备页
- **THEN** 仍可派遣的所选机体保留，空选择保持为空，名单和点数同步更新

#### Scenario: 调回预算内
- **WHEN** 玩家选择超额阵容后减少至合法预算
- **THEN** 页面显示当前实际点数，恢复出发操作，提交的机体与所选一致


### Requirement: Durable acknowledgement of solo commands
The solo authority SHALL acknowledge an accepted command only after its complete checkpoint is saved. A failed save SHALL preserve the current in-memory mission while suspending further commands, simulation and publication until recovery or terminal resolution. This contract does not require every periodic movement frame to be durably saved.

#### Scenario: Save fails after accepting a command
- **WHEN** a legal command changes a current-run mission and its save fails
- **THEN** the authority sends no success acknowledgement or affected full/dynamic state, does not execute another command or simulation step, and retains that mission and command sequence for bounded retry.

#### Scenario: Storage recovers before expiry
- **WHEN** the retained mission is successfully saved before its original deadline
- **THEN** current authorized seats receive the recovered authoritative state with the accepted sequence, and the original command is not executed again.

#### Scenario: Disconnect or seat transfer during a failed save
- **WHEN** the player disconnects or another authorized connection takes over while a checkpoint remains unsaved
- **THEN** the retained mission is not replaced by an older checkpoint and no connection receives its uncommitted state; recovery preserves the current seat's authority.

#### Scenario: Recovery occurs after the deadline
- **WHEN** storage recovers after the original mission deadline
- **THEN** the deadline remains unchanged and the mission resolves through the existing terminal rules before active play can resume.

### Requirement: Immutable solo terminal delivery
The solo authority SHALL preserve a durably recorded terminal result as the immutable delivery payload, even when its subsequent checkpoint fails. An older checkpoint SHALL NOT be combined with terminal flags and published as a recovered mission. A previously committed profile receipt remains authoritative and cannot be replaced by a conflicting late result.

#### Scenario: Terminal evidence succeeds but checkpoint fails
- **WHEN** terminal evidence is durably written and the following checkpoint cannot be saved
- **THEN** delivery uses that original terminal payload and never reconstructs its combat facts from the older checkpoint, including after a same-version restart.

#### Scenario: The first terminal write fails before expiry
- **WHEN** the mission has already reached a terminal outcome but its first terminal write fails and storage recovers after expiry
- **THEN** it preserves that outcome, original finish time and combat facts rather than replacing them with a later expiry outcome.

#### Scenario: Recorded terminal evidence cannot be read
- **WHEN** terminal evidence exists but is unreadable or structurally invalid
- **THEN** the solo authority does not restore active play from an older checkpoint or overwrite the terminal evidence, and retains the task for bounded recovery or diagnosis.

#### Scenario: The profile already committed a different expiry receipt
- **WHEN** delivery receives a result conflict for a solo-hosted timed activity
- **THEN** repeated automatic submission of that payload stops, its evidence is retained, and an authenticated recovery receives only the existing matching profile receipt; neither rewards nor damage are applied a second time.

#### Scenario: No authenticated player is available after restart
- **WHEN** conflicting terminal evidence exists without valid current-session credentials
- **THEN** the authority retains it for the next legitimate reconnect, does not resume active play or invent credentials, and makes no guarantee of unattended receipt retrieval; a restart can attempt the original payload again without changing it.

#### Scenario: A late authentication response arrives after terminal resolution
- **WHEN** an earlier in-flight admission request returns active deployment after that mission has become terminal or settled
- **THEN** it does not recreate an active mission, publish a mixed checkpoint, or regain command authority.

### Requirement: Rustrail collection landmarks have consistent physical boundaries
The Rustrail solo and standard cooperative expeditions SHALL treat the scrap, fuel and coil landmarks as impassable physical cover. Commands SHALL approach them at reachable positions within the existing collection radius, without changing guard requirements, rewards, budgets or deadlines. Landmark presentation SHALL agree with those boundaries and keep the nearby selected robot, its name and durability readable.

#### Scenario: Route and point movement toward a collection landmark
- **WHEN** a legal squad routes to one of the three landmarks or receives a movement command inside its footprint
- **THEN** its path and destination remain outside the physical footprint, and a reachable collection position is available within four metres of the landmark centre.

#### Scenario: Spawn and fight beside a landmark
- **WHEN** guards are created or activated beside a collection landmark
- **THEN** they stand outside its footprint, the landmark blocks firing through its physical cover, and units can navigate around it to engage and collect under the existing rules.

#### Scenario: Read the approaching robot
- **WHEN** a selected robot reaches each collection landmark in the normal expedition camera
- **THEN** the player can distinguish its body, name and durability from the landmark and its label without hiding the landmark.

#### Scenario: Restore a checkpoint generated by this version
- **WHEN** a valid current-version Rustrail checkpoint is restored during movement, after arrival or after a guard activation
- **THEN** positions, combat state and valid cached routes resume unchanged; invalid geometry is rejected rather than relocated or published as a successfully restored mission.

#### Scenario: Other expedition layouts
- **WHEN** a pump, factory, armory or public-camp mission is created or restored from its own current-version checkpoint
- **THEN** its authored layout remains authoritative and does not acquire Rustrail landmark obstacles.

### Requirement: The Rustrail exit posts have physical boundaries and an open passage
The Rustrail solo and standard cooperative maps SHALL include the physical exit post footings in their static navigation and cover data while keeping the exit centre and passage open. The exit location, four-metre interaction rule, stage requirement and visual geometry SHALL remain unchanged.

#### Scenario: Move toward a post or through the opening
- **WHEN** a legal robot is commanded toward a post or through the exit centre
- **THEN** normal planning avoids the post's occupied cells and still provides a route through the opening without teleporting or changing the requested goal to stage a screenshot.

#### Scenario: Restore current-map data near the posts
- **WHEN** a checkpoint freshly generated under this map is restored
- **THEN** legal positions and caches resume unchanged, while explicitly invalid post positions, goals or paths are rejected under the existing geometry validation; no older checkpoint is imported or relocated.

### Requirement: 标准单人锈轨权威安全转弯
标准单人锈轨探索 SHALL 按完整机体半径规划并推进路径，在有净空的转角提供有界的渐变方向路径；无法证明净空的圆角 SHALL 回退合法原路径，不穿越障碍、地图边界或其它存活机体。

#### Scenario: 空旷转角与连续转弯
- **WHEN** 机器人沿具有足够净空的九十度或连续转角路径移动
- **THEN** 权威位置分多步改变行进方向，每个实际扫段保持静态及动态净空，并到达原合法最终目标。

#### Scenario: 窄道和门柱
- **WHEN** 请求路径经过岩石边缘、采集地标、出口门柱或不能容纳候选圆角的区域
- **THEN** 规划及实际推进保持完整半径净空，使用可证明安全的圆角或合法折线；无路时停止或拒绝，不瞬移或缩小半径。

#### Scenario: 阻挡与原子指令
- **WHEN** 转弯途中有其它机体挡路，或整组移动的后续机体不能获得目标位置
- **THEN** 原动态裁剪和有界重规划继续有效，失败组指令不部分修改机体目标或路径，钻头仍须到真实有效射程才攻击。

### Requirement: 安全转弯配置与路径恢复隔离
安全转弯 SHALL 仅由标准单人锈轨的权威场次显式启用，并随当前版本场次的完整路径状态恢复；其它活动、合作探索和本地演练 SHALL 保持原运动规则，非法当前版本数据 SHALL 被拒绝而不修补旧格式。

#### Scenario: 当前版本途中续接
- **WHEN** 本轮新建的标准单人场次在转弯途中保存并由相同版本恢复
- **THEN** 相同后续指令与步长继续产生相同决策和位置，非法路径或配置被拒绝，原持久提交后才确认指令的合同保持。

#### Scenario: 共享模拟与继承
- **WHEN** 合作、旧军械库、泵站、工厂、营地、秘宝或本地演练使用共享模拟实现
- **THEN** 它们不因复用或继承获得本阶段转弯配置，不改变各自地图、经济和提交规则。

### Requirement: 标准单人锈轨轻惯性
标准单人锈轨机体 SHALL 在权威安全路径上短时加速、接近终点制动并在急弯主动降速，保持机体最大速度、完整半径净空和精确到达；重量感 SHALL NOT 通过客户端滑行、扩大目标半径或穿越障碍实现。

#### Scenario: 起步与终点停止
- **WHEN** 静止机体收到有效移动指令并行进到最终目标
- **THEN** 实际步进速度从低到高、停止前降低，在合法目标处归零，无越过目标后倒退补位或无限小速爬行。

#### Scenario: 连续转弯与阻挡
- **WHEN** 机体进入安全路径的急弯或被其它身体/障碍挡住
- **THEN** 急弯适当降速，阻挡时取消危险余速，不以惯性绕过逐段安全检查或保留假行走。

#### Scenario: 新令和战斗转换
- **WHEN** 玩家换向、取消移动、机体到达攻击距离或被判死亡
- **THEN** 新指令不继承逆向速度或继续过期目标，死亡和战斗反馈即时，盾向伤害/武器射程与指令失败原子性保持。

### Requirement: 轻惯性决定状态严格恢复
标准单人锈轨 SHALL 在当前版本检查点保存全部影响后续运动的速度和策略状态，同版本恢复后继续等值；其它模式 SHALL 默认保持原运动，缺失或非法的新决定状态 SHALL 拒绝而不回填旧格式。

#### Scenario: 加速或制动途中恢复
- **WHEN** 本轮新建机体在加速、转弯或制动中保存并由相同版本恢复
- **THEN** 相同后续指令与步长产生相同位置、速度、方向及到达行为，旧显示缓存不参与权威恢复。

#### Scenario: 非法速度或策略
- **WHEN** 当前版本记录中速度非有限、超出本场上限，或策略/必须决定字段不匹配
- **THEN** 不应用部分记录或发布恢复成功，不默认补零、导入旧档或迁移其它环境。
