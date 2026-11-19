## ADDED Requirements

### Requirement: Commission and display battle plaques
The profile service SHALL allow a player to spend four structure and one component to commemorate one owned robot in a settled recorded battle and freely display any owned plaque in their private base.

#### Scenario: Craft a first plaque
- **WHEN** an owner with sufficient material commissions an eligible record
- **THEN** the service captures its battle-time name and battle reference, charges once and displays the first plaque.

#### Scenario: Retry or invalid selection
- **WHEN** a request is repeated, concurrent, ineligible or unaffordable
- **THEN** duplicate deliveries and charges are prevented, and an invalid or unaffordable selection leaves stock and display untouched.

#### Scenario: Switch after a second battle
- **WHEN** the owner commissions another eligible battle and switches display
- **THEN** the previous collectible remains available, swapping is free, the choice persists after reopening the base, and combat stats are unchanged.

#### Scenario: Visit a friend's base
- **WHEN** an accepted friend visits the base
- **THEN** the visitor sees the currently displayed engraving and has no control over commissions or display changes.
