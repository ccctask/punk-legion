## ADDED Requirements

### Requirement: Cold start a saved base from the signed beta
The signed Android beta SHALL restore the saved private base from the matching local release service after process death.

#### Scenario: Enter a previously built base
- **WHEN** the tester cold starts the signed client with a valid session on the available release stack
- **THEN** the current revision and built structure appear without manual reconnect, and loading performs no additional construction charge.
