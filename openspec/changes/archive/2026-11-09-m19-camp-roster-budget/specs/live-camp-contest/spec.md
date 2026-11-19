## ADDED Requirements

### Requirement: Visible camp roster capacity
The camp lobby SHALL show the current combined unit count and command cost before the player commits a garrison or starts a new attack, including the effective aid reserved for this camp and side.

#### Scenario: Choosing an affordable roster
- **WHEN** the player selects or deselects a robot, or marks one selected defender as stationary
- **THEN** the lobby immediately shows its actual mounted cost and combined occupancy against both limits; a stationary garrison uses its normal cost exactly once.

#### Scenario: Editing around another player's reservation
- **WHEN** a fresh overview includes accepted aid that takes the selected roster over either cap
- **THEN** the player sees the excess and can revise the roster; submitting a new over-budget force is unavailable, and returning to an existing seat remains possible.

#### Scenario: Public window is replaced before a pending attack starts
- **WHEN** the server replaces the camp window after issuing a pending attack seat
- **THEN** the obsolete reservation is unavailable for a new entry, an already-started fight remains reconnectable, and a new valid window uses only its applicable aid reservations.
