## ADDED Requirements

### Requirement: Visible command availability across exploration reconnects
The exploration client SHALL expose combat commands only after the current connection has received an authorized mission state, in solo, party and pump expeditions.

#### Scenario: Connection drops during play
- **WHEN** the transport is lost with the last mission snapshot still visible
- **THEN** the player sees a reconnect action and connection status, and battle HUD, field and minimap cannot issue orders or suggestions.

#### Scenario: Returning to the original mission
- **WHEN** the player reconnects and the server returns the current mission state or a final receipt
- **THEN** the relevant assembly, active, withdrawn or settled controls are shown; stale orders are never replayed.

#### Scenario: Another window has finished the expedition
- **WHEN** the original window reconnects with its admission after the other window has completed the mission
- **THEN** it receives its existing personal receipt without generating another outcome or unlocking combat; a seat transferred to another connected window cannot keep issuing orders.
