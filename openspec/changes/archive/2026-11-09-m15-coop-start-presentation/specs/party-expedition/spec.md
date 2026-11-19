## ADDED Requirements

### Requirement: Command availability across the assembly transition
A cooperative expedition client SHALL enable a present active player's commands when the authority confirms combat has started, including when a movement update arrives before the phase confirmation.

#### Scenario: First combat update arrives ahead of the phase confirmation
- **WHEN** an assembling client receives the same mission's combat movement update before its authoritative start frame
- **THEN** it waits for confirmation and then displays active combat controls, applies subsequent movement updates, and can issue its own order.

#### Scenario: Assembly still pending
- **WHEN** no authoritative start has arrived
- **THEN** movement commands remain unavailable and the client displays the assembly state.
