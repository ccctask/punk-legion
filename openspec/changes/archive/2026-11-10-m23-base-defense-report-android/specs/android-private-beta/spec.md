## ADDED Requirements

### Requirement: Android base defense return
The signed Android client SHALL show the settled private raid outcome, actual loot, guard and facility damage, and applicable recovery period in the initial report view.

#### Scenario: A returning owner inspects a defeat
- **WHEN** the owner opens the settled raid from their private base and revisits the report after inspecting the guard
- **THEN** the summary agrees with the original receipt, guard inspection targets the same robot, and viewing details or replay leaves the settlement and inventory unchanged.

#### Scenario: Return after extended absence
- **WHEN** an owner first returns after the original 48-hour loss protection has expired while offline
- **THEN** the service grants the configured 24-hour return period and subsequent logins retain the same deadline.
