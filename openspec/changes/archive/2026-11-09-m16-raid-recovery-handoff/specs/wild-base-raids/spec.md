## ADDED Requirements
### Requirement: Inspect the damaged guard from a settled raid
A settled raid SHALL distinguish loot debited by settlement from the guard's subsequent repair charge and allow the player to inspect the current condition of the exact damaged guard.

#### Scenario: Inspect a damaged guard after defense
- **WHEN** the player opens a settled raid with guard damage and selects the guard's condition
- **THEN** the current condition or an explicit unavailable state is shown for that guard without charging or selecting another robot.

#### Scenario: Reopen a past defense
- **WHEN** the guard has already been repaired
- **THEN** the report retains its original loss while the linked condition shows the current state.
