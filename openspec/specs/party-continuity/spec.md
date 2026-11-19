# party-continuity Specification

## Purpose
合作小队在每次出战之间保留独立身份。成员自愿留队、换机或离开；每次出击重新准备并独立扣费、结算。队长建议仅向同队提示。

## Requirements

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
