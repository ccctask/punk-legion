## ADDED Requirements
### Requirement: Readable private-defense service events
A stationed robot's personal battle timeline SHALL identify a repairing platform by its location during that raid, distinguish numbered wild opponents, and show the recorded repair and damage amounts without changing attribution or totals.
#### Scenario: Revisiting a saved defense
- **WHEN** a player opens a private-defense service event after the platform moves or its module is removed
- **THEN** the event shows the original repairing platform tile and the receiving robot at battle time, including the actual repair amount; a bookmark returns to the same numbered event.
#### Scenario: Reviewing damage and kills
- **WHEN** the guard's timeline contains combat damage or a wild kill
- **THEN** the player sees the recorded damage amount or the numbered wild opponent, and repairs received from a platform do not count as the guard's own repair output.
