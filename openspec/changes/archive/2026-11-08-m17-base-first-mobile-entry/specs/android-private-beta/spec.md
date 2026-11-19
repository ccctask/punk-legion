## ADDED Requirements

### Requirement: Android opens on the private base
The Android beta SHALL open on the private base, allow a new player to name their first owned robot there, restore the returning player's own base, and place connection details and the test range in a menu.

#### Scenario: First visit
- **WHEN** a new player launches the app and completes registration in the base
- **THEN** the player can name the first owned robot there and see the accepted name on that same robot after relaunch.

#### Scenario: Returning commander and menu
- **WHEN** an existing commander signs in or resumes a valid session and visits the range or diagnostics
- **THEN** their base and previously named robots remain accessible and returning from the menu restores the same commander.

#### Scenario: Interrupted start or rename
- **WHEN** the network fails during launch or naming, or the required protocol is unavailable
- **THEN** the player can see the appropriate recovery or upgrade action, and retrying never grants another robot or overwrites another account's name.
