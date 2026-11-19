## ADDED Requirements

### Requirement: Confirmed installation advances first-fit guidance
The base guide SHALL recognize fitting at least one physical part through a confirmed workshop design application as completing the owning player’s first fit.

#### Scenario: Install a repair arm from a saved loadout
- **WHEN** a named starter receives an actual repair arm in its function slot through a confirmed design application and the player returns or logs back in
- **THEN** the guide credits fitting once and offers the next outstanding activity.

#### Scenario: Review a configuration without installing a part
- **WHEN** the player merely saves, previews or cancels a design, or completes an operation with zero parts installed
- **THEN** first-fit guidance remains at its previous state.
