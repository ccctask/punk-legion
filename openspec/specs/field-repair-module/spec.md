# field-repair-module Specification

## Purpose
规定玩家从私人经营路线取得维修部件、装入兼容功能槽、部署机体支援队友的流程。在单人探索和跨账号合作中，权威结算分别记载施修机体和受修机体的真实耐久变化，并保留有限充能与重连去重规则。

## Requirements

### Requirement: Effective repair by an equipped robot

A player SHALL be able to acquire a repair part through normal private play, install it in a compatible functional slot, and deploy the equipped robot to repair damaged allies under authoritative battle rules.

#### Scenario: Old loadouts and exclusive slots

- **WHEN** an owner opens an older loadout or installs a physical repair part
- **THEN** the old loadout remains deployable with the optional slot empty, and the installed item occupies only one compatible slot on one robot.

#### Scenario: Attributing actual repairs

- **WHEN** an equipped robot repairs an eligible ally
- **THEN** its permanent identity receives exactly the effective repair output, the recipient regains the matching durability during play; only the actual repair output increases the source robot’s career repair total.

#### Scenario: Invalid or duplicate healing

- **WHEN** a full-health ally, enemy or out-of-range target is considered, or a completed report is redelivered
- **THEN** no extra healing or repair statistics are credited.

#### Scenario: Preserving source identity

- **WHEN** a commander orders a squad repair or a workshop repairs a robot after combat
- **THEN** those events remain distinguishable from the equipped unit's output.
