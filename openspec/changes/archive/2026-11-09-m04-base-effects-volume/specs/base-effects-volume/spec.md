## ADDED Requirements
### Requirement: Control battle effects from the base
The game SHALL share one locally persisted effects level between the base menu and range and apply a successful change to existing battle audio players.

#### Scenario: Silence before departure
- **WHEN** a player selects mute in the base menu and later starts a battle or restarts the client
- **THEN** the effects remain muted.

#### Scenario: Change volume during playback
- **WHEN** the player mutes active battle effects and later restores a nonzero level
- **THEN** active voices stop immediately and restoring sound does not replay earlier one-shot cues.
