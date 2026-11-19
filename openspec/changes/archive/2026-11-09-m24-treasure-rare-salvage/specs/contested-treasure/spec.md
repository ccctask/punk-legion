## ADDED Requirements
### Requirement: Bounded rare salvage from personal extraction
The service SHALL provide one independent personal rare-part opportunity per UTC match-start day when the player extracts cargo, and show the odds, guarantee progress and outcome before and after play.
#### Scenario: Eligible personal extraction
- **WHEN** a player extracts at least one cargo item on their first eligible settlement for that match-start day
- **THEN** they get a 20 percent chance for a usable reinforced boiler, guaranteed after two misses, even when resource storage is full; issuing the part clears the personal guarantee progress.
#### Scenario: Capacity and isolation
- **WHEN** the free part warehouse is full on a winning roll, or a player leaves without cargo, or only their teammate extracts
- **THEN** a full warehouse retains a guaranteed next eligible opportunity with no material grant, while an ineligible player spends no opportunity and changes no progress.
#### Scenario: Replay and daily bound
- **WHEN** the client reconnects, repeats extraction, or extracts again on the same match-start day
- **THEN** the earlier receipt stays stable and no extra part or progress is awarded.
#### Scenario: Review a full parts warehouse before entry
- **WHEN** the player reviews the opportunity with no free part storage
- **THEN** the lobby explains that a successful roll cannot deposit a part, consumes that day's opportunity and preserves the next guarantee.
