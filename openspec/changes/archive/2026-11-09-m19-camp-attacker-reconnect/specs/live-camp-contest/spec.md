## ADDED Requirements

### Requirement: Live attacker presence for earning or winning a capture
The public camp room SHALL retain earned attacker progress during the principal attacker's reconnect grace and resume capture only after that principal authenticates in time. Ordinary combat, defender capture, and the match clock continue.

#### Scenario: Dropping on the core
- **WHEN** the principal attacker disconnects with an attacking unit on the core, including when allied aid remains online
- **THEN** attacker progress does not increase and an unattended force cannot win by core control or timeout; reconnecting in time resumes the same progress and original remaining round time.

#### Scenario: Expiry and recovering a room
- **WHEN** the reconnect deadline or match deadline passes before authentication succeeds, including across a room restart
- **THEN** an absent attacker cannot recover a winning seat; surviving garrisons, the same unique settlement, and existing player ownership of robots are preserved.

#### Scenario: Local loss of room connection
- **WHEN** the connection is lost while the client holds a previous battle snapshot
- **THEN** the battle view indicates the interruption, offers return to the original room, and suppresses commands until the authenticated snapshot or final receipt arrives.
