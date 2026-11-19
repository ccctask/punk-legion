## ADDED Requirements

### Requirement: Effective repair by an equipped robot

A player SHALL be able to acquire a repair part through normal private play, install it in a compatible functional slot, and deploy the equipped robot to repair damaged allies under authoritative battle rules.

#### Scenario: Old loadouts and exclusive slots

- **WHEN** an owner opens an older loadout or installs a physical repair part
- **THEN** the old loadout remains deployable with the optional slot empty, and the installed item occupies only one compatible slot on one robot.

#### Scenario: Attributing actual repairs

- **WHEN** an equipped robot repairs an eligible ally
- **THEN** its permanent identity receives exactly the effective repair output, the recipient receives the matching effective healing, and the timeline identifies both identities.

#### Scenario: Invalid or duplicate healing

- **WHEN** a full-health ally, enemy or out-of-range target is considered, or a completed report is redelivered
- **THEN** no extra healing or repair statistics are credited.

#### Scenario: Preserving source identity

- **WHEN** a commander orders a squad repair or a workshop repairs a robot after combat
- **THEN** those events remain distinguishable from the equipped unit's output.
