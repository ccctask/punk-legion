## ADDED Requirements

### Requirement: Three-hour formal raid warning
The server SHALL schedule private base raid combat to start three hours after the scheduled formal warning, using the same deadline for all sessions of that raid.

#### Scenario: Owner returns during the warning
- **WHEN** an owner returns two hours after the formal warning began
- **THEN** the base displays the remaining hour, the same encounter and its current material risk, and accepts otherwise valid defensive preparations until the scheduled start.

#### Scenario: Lock and offline settlement
- **WHEN** combat starts after the three-hour window and the owner is away
- **THEN** the last committed pre-start defense is locked for that encounter, and offline and later viewing paths produce one settlement.
