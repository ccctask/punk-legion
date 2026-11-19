## ADDED Requirements

### Requirement: Compare a proposed part with the equipped machine
The owned workshop SHALL preview current and candidate maximum durability, movement speed and command cost from combat assembly rules before installing a single item.

#### Scenario: Compare a recovered reinforced boiler
- **WHEN** a player selects an owned reinforced boiler for a crawler with a standard boiler
- **THEN** the preview shows both sets of statistics before any inventory mutation, and confirming equips the matching machine configuration.

#### Scenario: Invalid fitting
- **WHEN** a selected item produces an illegal fit
- **THEN** the current statistics remain visible and the reason for rejection replaces the candidate statistics.
