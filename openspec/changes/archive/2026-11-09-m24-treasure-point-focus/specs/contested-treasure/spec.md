## ADDED Requirements
### Requirement: Direct target selection in contested treasure
The treasure battlefield SHALL let a player issue a focus command to a particular visible living enemy by tapping or clicking it with their current selection.
#### Scenario: Pick a farther support unit
- **WHEN** a player selects their fire support group and taps a support enemy behind another enemy
- **THEN** one command targets the tapped enemy using the selected owned robots and the server reflects that focus.
#### Scenario: Ground and shortcut actions
- **WHEN** the player taps empty terrain or presses the nearest-target button
- **THEN** terrain orders movement and the shortcut still selects the nearest eligible enemy.
