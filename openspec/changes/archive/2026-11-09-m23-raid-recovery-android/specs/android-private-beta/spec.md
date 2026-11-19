## ADDED Requirements
### Requirement: Mobile defense recovery after an extended transient outage
The signed Android beta SHALL automatically reacquire an active defense after connectivity returns while the tester stays on the defense page.
#### Scenario: Connectivity returns after the battle ends
- **WHEN** two fast GET retries are exhausted on a live defense and the service becomes reachable after settlement
- **THEN** the installed game retrieves the matching outcome without a refresh tap or repeated guard assignment.
