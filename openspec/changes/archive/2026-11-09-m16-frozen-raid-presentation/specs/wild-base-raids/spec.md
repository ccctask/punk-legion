## ADDED Requirements

### Requirement: Raid view represents the registered guard
The private base raid view SHALL hide the home showcase robot and its name while displaying a warning, live raid or replay. Only the registered guard from the raid may appear as a defending robot.

#### Scenario: Opening and leaving defense
- **WHEN** the owner opens a raid with or without a registered guard, returns home, and reopens it
- **THEN** the raid consistently shows exactly its registered defenders, and returning restores the current home presentation with the owner's named showcase robot when available.
