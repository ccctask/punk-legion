## ADDED Requirements

### Requirement: Treasure combat assists belong to contributing machines
The treasure authority SHALL award one assist per defeated target to each eligible non-finishing robot that dealt effective damage, and record the finishing robot's kill in its own service history.

#### Scenario: Repeated attacks and a finishing teammate
- **WHEN** one robot damages a rival repeatedly and another robot delivers the finishing hit
- **THEN** the first robot has one assist for that target at defeat time, the finisher has a kill without an assist for that target, and the owner can mark the assist in its timeline.

#### Scenario: Normal room recovery and repeated settlement reads
- **WHEN** the room resumes after damage and the corresponding personal reports are read again after settlement
- **THEN** contributions are attributed to the same permanent robot identities exactly once.
