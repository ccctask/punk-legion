# light-wheel-chassis Specification

## Purpose
让玩家用轻型轮式底盘在速度、耐久、载重和出战费用之间取舍，在基地和机库获得与工具接口匹配的引导，进入联机房间后保留原机身份、部件和车轮表现。

## Requirements

### Requirement: Light wheeled frame in owned workshop and combat
The player SHALL be able to manufacture, save and refit a light wheeled chassis with visible rolling wheels, a four-unit payload and two base command points.
#### Scenario: Legal equipment and cost
- **WHEN** a player fabricates a wheel chassis with a standard boiler, eyes and cannon
- **THEN** the workshop charges the quoted cost once and the resulting robot is selectable for a normal sortie
#### Scenario: Incompatible veteran refit
- **WHEN** an existing crawler carries a shield or utility part and the player attempts to switch to wheels
- **THEN** the transaction preserves the current frame, inventory and stock until the player removes incompatible parts
#### Scenario: Movement and durability
- **WHEN** crawler, biped and wheeled robots with identical basic parts move an equal clear distance
- **THEN** the wheeled robot arrives first, has 42 maximum hit points and retains its frame and identity on same-match resume
