# owned-workshop Specification

## Purpose
为账户内每台机体保存独立身份、版本化装配方案和实体部件占用。玩家可以从正常游戏入口按材料制造、预览和拆换机体，重登后恢复装配和余额。

## Requirements

### Requirement: Manufacture and refit owned robots
The service SHALL save account-owned versioned designs and atomically manufacture or refit uniquely identified robots with legal owned parts through the workshop.
#### Scenario: Manufacture two instances
- **WHEN** an account uses a saved design to manufacture two robots in distinct paid transactions
- **THEN** each robot has its own stable identity and installed items; retrying a transaction does not charge again.
#### Scenario: Swap or reject a part
- **WHEN** a legal replacement is installed
- **THEN** the former item returns to that owner's available inventory and the replacement cannot simultaneously equip another robot.
#### Scenario: Invalid request or occupied machine
- **WHEN** a design is illegal, resources are insufficient, ownership conflicts, or the robot has an active assignment
- **THEN** the operation fails with a visible reason and preserves inventory, robot fit and balances.
#### Scenario: Reopen the workshop
- **WHEN** the owner signs back in and selects a manufactured robot
- **THEN** the workshop presents its saved fit and a matching preview with the same robot identity.

### Requirement: 制造前和实装时显示整机指挥点
机库 SHALL 让玩家在保存与制造前看到当前草案的最终出战指挥点，并可在自有机体上核实实际消耗。

#### Scenario: 换装战术目镜
- **WHEN** 玩家把基础履带气炮机的普通头换成战术目镜
- **THEN** 草案报价旁的整机指挥点从 2 更新到 3，制造后实装显示和出战清单相同

### Requirement: Preview fabrication cost and constraints while assembling
The workshop SHALL show the authoritative fabrication price and command cost of a valid current draft before saving and identify material, weapon recipe and hangar constraints before building.
#### Scenario: Compare a support fit and a light fit
- **WHEN** the player changes the hull or modules in the draft
- **THEN** the preview updates for that fit without mutating the account, a legal unaffordable plan can be saved, and an eligible saved fit can be built for the quoted price.

### Requirement: Review fitting an owned robot
The workshop SHALL let the commander review a saved design against a named owned robot and its actual parts before applying it.
#### Scenario: Confirm a reviewed change
- **WHEN** a commander reviews the slots and confirms an eligible change
- **THEN** the reviewed parts are applied atomically to the selected robot, or a changed plan is refused and can be reviewed again; a preview or cancellation moves no parts.

### Requirement: Compare a proposed part with the equipped machine
The owned workshop SHALL preview current and candidate maximum durability, movement speed and command cost from combat assembly rules before installing a single item.

#### Scenario: Compare a recovered reinforced boiler
- **WHEN** a player selects an owned reinforced boiler for a crawler with a standard boiler
- **THEN** the preview shows both sets of statistics before any inventory mutation, and confirming equips the matching machine configuration.

#### Scenario: Invalid fitting
- **WHEN** a selected item produces an illegal fit
- **THEN** the current statistics remain visible and the reason for rejection replaces the candidate statistics.

### Requirement: Recover an uncertain owned refit in place
The workshop SHALL visibly recover an interrupted single-part refit at its point of use using the persisted operation identity and a bounded automatic retry.

#### Scenario: Lost committed response
- **WHEN** the server installs an item but the first response is lost
- **THEN** the garage recovers the original receipt and authoritative fit without further player action or a second transaction.

#### Scenario: Repeated interruptions and initial read
- **WHEN** automatic recovery for a refit or the initial garage read is exhausted
- **THEN** the affected screen shows a reachable retry, retains any uncertain operation, and does not imply that stale or missing data is current.

### Requirement: Deliver complete workshop replies to the signed mobile client
The supported local Android release path SHALL deliver an authoritative garage snapshot and the original refit receipt after a single interrupted committed reply, without requiring a new item installation.

#### Scenario: Android garage receiving a full replay
- **WHEN** the original committed refit reply is cut and the next request presents the same key
- **THEN** the signed Android garage shows the verified authoritative fit without manual retry and the ledger retains one installation.

### Requirement: Show the installed chassis as equipped
The garage SHALL display an equipped state for the current chassis and show the transaction quote only for a different candidate chassis.
#### Scenario: Successful purchase consumes the remaining components
- **WHEN** a player refits and the selected preview now matches the equipped chassis
- **THEN** the garage shows the equipped state without an insufficient-stock warning or a further purchase quote
#### Scenario: Inspect another chassis
- **WHEN** the player selects a different chassis after the purchase
- **THEN** the garage shows its ordinary cost, compatibility and insufficient-stock feedback as applicable
