# squad-roles-and-orders Specification

## Purpose
玩家能为自有机体预设护卫、距离、索敌和回撤行为，在战斗中按职责指挥自己的存活机体。记录以永久机体编号为准，手动指令优先，重连后仍按实际席位限制控制范围。

## Requirements

### Requirement: Player-defined roles and bounded prebattle orders

Players SHALL be able to group owned robots as frontline, fire support or support, choose guard target, engagement distance, target priority and retreat threshold before a sortie, and select any such group in battle.

#### Scenario: Custom group across sorties

- **WHEN** a player renames or refits a robot or reorders the roster after assigning its group
- **THEN** that robot retains its chosen group and the group control selects only living units under that player’s control.

#### Scenario: Frozen behavior and manual commands

- **WHEN** a battle begins with a configured policy or a player reconnects
- **THEN** the authority uses the frozen rules and an explicit authorized manual command takes precedence at the time of issue.

#### Scenario: Supported defaults

- **WHEN** a player has old robots without policies, or a configured guard target is unavailable
- **THEN** the squad remains deployable with a documented fallback and no new resource charge.
