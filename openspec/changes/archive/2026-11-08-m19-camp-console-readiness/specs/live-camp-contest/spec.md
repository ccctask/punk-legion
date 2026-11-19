## ADDED Requirements
### Requirement: Show reliable camp actions during overview loading and recovery
The console SHALL show the selected territory immediately and offer camp actions based on its authoritative overview or a valid battle seat.
#### Scenario: First read is delayed or fails
- **WHEN** a player opens either camp and its initial overview is delayed or unavailable
- **THEN** the player can identify the camp, read its loading or recovery status and return to the map without being offered attack, garrison or claim actions.
#### Scenario: Overview arrives or is recovered
- **WHEN** the server supplies the camp overview after a delay, changed ownership or a failed read
- **THEN** the console exposes the actions for that player's current role, retains valid selection, and normal successful polling leaves usable controls stable.
