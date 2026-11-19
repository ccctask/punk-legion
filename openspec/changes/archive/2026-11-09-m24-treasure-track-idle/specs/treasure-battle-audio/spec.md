## ADDED Requirements

### Requirement: Treasure tracks stop while authority stalls
The client SHALL end the looping track audio once visible friendly crawlers have stopped at their last confirmed positions during a sustained gap in authoritative frames.

#### Scenario: Network stays connected but stops sending updated positions
- **WHEN** the moving robot reaches its last known pose and no fresh tick arrives for a sustained interval
- **THEN** the track loop stops, transient combat alerts are not replayed and movement can be heard again when subsequent frames resume travel.
