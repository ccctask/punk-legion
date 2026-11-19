# light-player-onboarding Specification

## Purpose
定义首台机体引导、可提前收工的每日 PVE 探索和离线回归结算。玩家可独行或组队，首胜后可以继续试用新部件，重新登录时保留机体、探索奖励及当日进度。

## Requirements

### Requirement: 可中断的首次经营与回归
游戏 SHALL 允许轻度玩家在私人基地进入引导，依靠真实经营与战斗事件恢复进度，并在离线后理解其保存状态。
#### Scenario: 首玩中断
- **WHEN** 玩家从命名到换件、指挥、领奖或维修途中关闭应用并重新登录
- **THEN** 系统从尚未完成的步骤继续，已存在的部件、战报与奖励保持可查且不会重复发放。
#### Scenario: 轻度日常
- **WHEN** 玩家选择单人或组队 PVE 并正常完成一轮日常
- **THEN** 可不占领营地取得核心成长资源，准备、匹配与结算计入 15 至 30 分钟的日常会话验收；等待组队时可改走单人路线。
#### Scenario: 离线七天
- **WHEN** 玩家离开七天后重登并再次打开摘要
- **THEN** 实际累计生产、离线封顶、维修与袭击可与库存和战报对账，重复查看不影响余额。

### Requirement: Private base guidance fits landscape controls
The private base SHALL keep actionable onboarding text readable and its controls reachable at supported landscape sizes.

#### Scenario: Long next objective on a small screen
- **WHEN** a player views a long onboarding objective on an 800×450 or 960×540 viewport
- **THEN** all of the text is available through wrapping or scrolling and the player can activate the corresponding control.

### Requirement: 基地首页可读取已派遣首机的配置
客户端 SHALL 能通过正常档案服务在私人基地识别玩家的首机与实际装配。
#### Scenario: 多机阵容派遣后重登基地
- **WHEN** 玩家首机随队出发且再次登录
- **THEN** 基地读取真实首机及当前装配，允许玩家继续前往地图；真实连接故障可重试恢复。

### Requirement: 首次认证通信中断后继续
基地入口 SHALL 为登录和注册的未确认结果分别给出可执行提示，并在当前表单保留输入。
#### Scenario: 登录通信失败
- **WHEN** 兼容服务的登录请求未获得可用会话回执
- **THEN** 玩家可在原表单一次点击重新登录，输入可编辑，服务端明确拒绝时仍显示相应原因。
#### Scenario: 注册回执丢失
- **WHEN** 创建账号后回执未到客户端
- **THEN** 提示用相同账号登录核对，等待玩家操作，登录后恢复该账号的唯一首机。

### Requirement: 已建基地的在线冷启动
客户端 SHALL 在服务可用并完整交付有效档案时自动显示玩家最近保存的权威布局。

#### Scenario: 玩家重新启动游戏
- **WHEN** 玩家冷启动并成功连接档案服务，服务完整交付当前布局
- **THEN** 客户端显示已建建筑和当前布局版本，玩家无需手动重试。

### Requirement: Daily progress from collecting private production
The game SHALL count the first qualifying production claim or expedition of the current UTC day as the owner's completed daily, using the original receipt and actual credited items.

#### Scenario: A player finishes the day in the base
- **WHEN** an authoritative production claim deposits a positive amount in the owner's stock
- **THEN** the current daily shows completion, source, credited amount and receipt without a separate reward, including after reopening the base.

#### Scenario: Empty claims and daily rollover
- **WHEN** a claim credits zero or a prior qualifying receipt belongs to a previous UTC day
- **THEN** that receipt does not satisfy today's production goal; combat tutorial steps keep their own requirements.

#### Scenario: More than one qualifying activity
- **WHEN** the same owner later completes another qualifying activity that day
- **THEN** the earliest qualifying receipt remains the displayed daily result.

### Requirement: Confirmed installation advances first-fit guidance
The base guide SHALL recognize fitting at least one physical part through a confirmed workshop design application as completing the owning player’s first fit.

#### Scenario: Install a repair arm from a saved loadout
- **WHEN** a named starter receives an actual repair arm in its function slot through a confirmed design application and the player returns or logs back in
- **THEN** the guide credits fitting once and offers the next outstanding activity.

#### Scenario: Review a configuration without installing a part
- **WHEN** the player merely saves, previews or cancels a design, or completes an operation with zero parts installed
- **THEN** first-fit guidance remains at its previous state.

### Requirement: First-session three-role PvE evidence
The first-session evaluation SHALL track one fresh account from starter combat through a real refit and manufacture of distinct robots, and distinguish measured play time from human usability observations.

#### Scenario: The player continues after the first optional stopping point
- **WHEN** the player elects to continue a pure PvE session toward a melee, ranged and repair squad
- **THEN** the evaluation records the first stopping point, the actual resources and commands used, whether the three owned robots can deploy together within thirty minutes, and any obstacle to completing the route.

### Requirement: Android first-session route evidence
The first-session evaluation SHALL verify the existing pure PvE three-role route using actual Android touch input and one newly registered account in an isolated test environment.

#### Scenario: Touch-operated manufacture and redeployment
- **WHEN** the player completes starter combat, equips the earned drill, manufactures ranged and repair robots, and selects all three
- **THEN** the evaluation records actual touch navigation, elapsed time, authoritative costs and roster, and post-battle persistence after restarting the application.

### Requirement: First battle precedes optional first refit and manufacture
The initial guide SHALL recommend using the existing starter in PvE after naming, and offer optional continuation toward refitting and manufacture after a personally completed Rust Rail victory.

#### Scenario: First victory permits stopping
- **WHEN** the owner wins Rust Rail personally in solo or cooperative play
- **THEN** the guide retains the daily completion state and permits stopping, while optional continuation can open existing drill claiming, fitting and manufacture flows.

#### Scenario: Already completed steps and different equipment
- **WHEN** the owner has already fitted a compatible part, manufactured a legitimate robot, or must claim a pending first-win drill
- **THEN** the guide derives progress from their actual records, skips completed steps and opens the applicable existing flow after relogin.

#### Scenario: Player owns three ready robots
- **WHEN** the optional guide reaches the existing departure flow with three ready robots
- **THEN** it explains manual roster selection and command points without adding a requirement to the daily completion condition.
