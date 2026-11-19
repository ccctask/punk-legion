# playable-chassis-choice Specification

## Purpose
规定玩家如何制造双足或履带机体、在现役机体上换底盘，以及费用、指挥上限、服役记录和移动属性的一致性。

## Requirements

### Requirement: Two distinguishable and interchangeable playable chassis

The workshop SHALL let players obtain, manufacture and refit owned robots with crawler or biped chassis through private progression and apply the selected chassis's compatible interfaces, command cost and combat attributes.

#### Scenario: Refitting a named veteran

- **WHEN** a player legally switches the chassis of a named idle robot
- **THEN** the robot keeps its persistent identity, its three career totals and favorite status remain attached to it, and costs and removed parts are accounted for once.

#### Scenario: Illegal or stale request

- **WHEN** a chassis is unavailable, the existing parts exceed a limit, or the robot is deployed
- **THEN** the service rejects the change and preserves the existing equipment and stock.

#### Scenario: Actual presentation and authority

- **WHEN** both chassis enter a normal match
- **THEN** the player sees their distinct locomotion and silhouettes and the authoritative simulation and budget match the selected build; older robots and missions continue to use the crawler definition.
