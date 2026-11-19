## ADDED Requirements
### Requirement: Preview the incoming raid path
The private raid warning SHALL show the entry direction and the incoming path used by the authoritative simulation for its current defense layout.
#### Scenario: Preparing a branched defense
- **WHEN** the commander sees a warning and commits a layout change that redirects the approaching robots before battle
- **THEN** the same warning reflects the new ordered path to the core and distinguishes that path from unused roads.
#### Scenario: Viewing the actual defense
- **WHEN** the warning ends or the commander returns to the base
- **THEN** preview markers leave the view and the battle follows the last accepted pre-start layout.
