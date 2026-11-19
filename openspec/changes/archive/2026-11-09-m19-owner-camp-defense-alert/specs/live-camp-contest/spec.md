## ADDED Requirements

### Requirement: Discover and answer a live attack on an owned public camp
A player on the normal private base or public map SHALL see which owned camps are under live attack within five seconds on a healthy local connection, and SHALL be able to open that camp's existing defense console from the alert.

#### Scenario: Owner responds from home
- **WHEN** an adversary begins a real contest while the owner remains at the base
- **THEN** the owner can discover it without first selecting a camp, enter the same match and command the garrison.

#### Scenario: Two locations and a completed battle
- **WHEN** two owned camps are contested, either contest ends, or the owner returns to the foreground
- **THEN** each pending response refers to its own live location, a settled attack ceases to be offered, and another account cannot receive owner-only actions.
