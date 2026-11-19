## ADDED Requirements

### Requirement: Friendly treasure battle cues
During an active treasure match, the client SHALL apply the existing mechanical sounds and saved effects level to visible friendly robots on the local seat’s side, and silence battle voices on disconnect, personal settlement or exit.

#### Scenario: Either starting side hears its own squad
- **WHEN** friendly and enemy units move, fire, or cross the danger threshold in view
- **THEN** only eligible friendly actions on the observing seat’s side produce the corresponding cues, with at most three simultaneous voices.

#### Scenario: Recover or end a session
- **WHEN** a seat disconnects, reconnects with a repeated snapshot, receives a personal result, or exits
- **THEN** stale alerts are not replayed and ongoing battle voices stop when the seat is inactive.
