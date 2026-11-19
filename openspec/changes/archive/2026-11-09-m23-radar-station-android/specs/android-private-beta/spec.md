## ADDED Requirements
### Requirement: Radar outpost and chassis feedback on Android
The signed Android client SHALL support the private base radar station, its server-timed intelligence and the garage's equipped chassis state.
#### Scenario: Inspect the station
- **WHEN** a player builds a powered station and opens it before a scheduled warning
- **THEN** the station shows the appropriate signal, later offers the formal raid details and returns the player to the same base after visiting the linked destinations
#### Scenario: Inspect a paid chassis
- **WHEN** the player inspects the current chassis after paying for a refit
- **THEN** the current chassis displays its equipped state while another candidate displays the applicable quote

