## ADDED Requirements

### Requirement: Remember a robot and a battle event
The owner SHALL be able to favorite a persistent robot and bookmark a recorded event in its battle timeline, then retrieve either from the normal client after logging in again.

#### Scenario: Refit a favorite robot
- **WHEN** the player renames and refits a favorite robot
- **THEN** the favorite leads to the same robot and its saved historical event retains the original battle context.

#### Scenario: Retrieve and remove a highlight
- **WHEN** an owner opens a saved highlight beyond the first timeline page and later removes the bookmark
- **THEN** the client opens the exact original event, and removal preserves the timeline and lifetime statistics.

#### Scenario: Prevent cross-account changes
- **WHEN** another account references the same robot or event identifier
- **THEN** the service refuses to expose or alter its private record.
