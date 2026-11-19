## ADDED Requirements

### Requirement: Playable signed beta with live camp reconnect rules
The signed Android beta SHALL connect to release-matched camp and profile services implementing bounded attacker reconnect and valuation of completed private production.

#### Scenario: Disconnecting an installed mobile client on the core
- **WHEN** the attacker disconnects from a camp while its robot controls the core
- **THEN** the installed client can return to the original session within grace or retrieve the settled receipt after grace, the server freezes capture during absence, and the signed release exposes the corresponding defender outcome after expiry.
