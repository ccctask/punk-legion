## Purpose
让移动端玩家在有限兵力内按实际机体身份自由编队，能够在同一场战斗中反复选中跨职责的小队，并继续使用已有移动、集火或维修指令。

## ADDED Requirements

### Requirement: Create and recall mixed combat groups
A commander SHALL be able to edit, save and recall two personal groups of individually selected controllable mobile units while an eligible battle is running.

#### Scenario: Move a mixed squad
- **WHEN** a commander recalls a saved mixed-role group and issues an ordinary movement order
- **THEN** recall alone leaves the battle unchanged, and the order carries only the current eligible members of that group.

#### Scenario: Lose or restore local selection
- **WHEN** a group member is disabled or command rights change, or the commander reconnects to the same contest
- **THEN** recall filters unavailable members, preserves the remaining original identities and cannot select another player's units; a different match starts with empty groups.
