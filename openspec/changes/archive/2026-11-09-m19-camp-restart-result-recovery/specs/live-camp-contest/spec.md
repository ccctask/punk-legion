## ADDED Requirements

### Requirement: Recover a camp room from valid local evidence
After a restart the room SHALL prefer a valid terminal result for the same contest, otherwise attempt the last valid checkpoint, and permit normal expiry when neither can establish a result.

#### Scenario: Torn terminal write
- **WHEN** an incomplete terminal file accompanies a valid checkpoint for a live contest
- **THEN** the room recovers the correct contest under the ordinary clock and admission rules and submits at most one accepted settlement.

#### Scenario: Exhausted evidence
- **WHEN** both local records are unreadable or the service has already closed the contest
- **THEN** the room continues to serve other contests, stops repeatedly parsing the same invalid data, and preserves the authoritative settlement and loss bounds.
