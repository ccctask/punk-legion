## ADDED Requirements

### Requirement: Optional consecutive cooperative sorties

A cooperative party SHALL allow members to finish one match, collect its normal results, and voluntarily prepare a second match without exchanging another invite code.

#### Scenario: Consecutive play and recovery

- **WHEN** both players remain after settlement, select available robots and prepare again
- **THEN** the same party enters a new match with new mission identifiers and separate charges, lock ownership and receipts, including after reconnect.

#### Scenario: Finishing for the day

- **WHEN** a player chooses to leave or declines a second sortie
- **THEN** the first reward remains accessible and the player incurs no new charge or deployment lock.

### Requirement: Team information and suggestions

The party SHALL show a concise role overview and support bounded, team-only tactical suggestions that leave each player's command authority intact.

#### Scenario: Receiving a leader suggestion

- **WHEN** the leader marks a destination or target
- **THEN** teammates see a time-limited suggestion and only the receiving player can issue orders for their units.
