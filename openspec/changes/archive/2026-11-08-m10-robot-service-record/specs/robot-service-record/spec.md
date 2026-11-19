## ADDED Requirements
### Requirement: Durable owned robot service history
The server SHALL attribute authoritative battle statistics and ordered events to the persistent identities of the robots actually deployed and expose paged account-owned records.
#### Scenario: Rename and refit after battle
- **WHEN** a robot changes its name or loadout after a recorded battle
- **THEN** its previous report keeps the original display snapshot and remains accessible under the same robot identity.
#### Scenario: Effective repairs and unique outcomes
- **WHEN** a server battle includes kills, assists or repair and the result is redelivered
- **THEN** history and totals count each battle once and distinguish effective in-battle output, received healing and post-battle workshop repairs.
#### Scenario: Review service events
- **WHEN** an owner opens an individual robot record
- **THEN** the player can view its participation, outcome, and paged chronological events without altering underlying totals.
