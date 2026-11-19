## ADDED Requirements

### Requirement: Protected next-action delay
The server SHALL permit normal movement during disruption, delay the next pending weapon and repair actions individually, and enforce one protection interval per target across all sources.

#### Scenario: Simultaneous emitters and moving target
- **WHEN** two allied emitters hit the same moving target with pending weapon and repair actions in one tick
- **THEN** the target continues moving, each pending action is delayed once, and the target shares one protection interval across both emitters.

#### Scenario: Reconnect during protection
- **WHEN** a client rejoins the same battle before protection expires
- **THEN** the restored target retains the original deadlines and service records credit only the effective application.

#### Scenario: Idle repair tool
- **WHEN** no ally requires repair until after the temporary disruption expires
- **THEN** the repair tool follows its ordinary schedule without a saved disruption penalty.
