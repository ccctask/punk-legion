## MODIFIED Requirements
### Requirement: Shared robot fits identify each slot
The recipient SHALL see the hull, each equipment slot supported by that hull, its installed part or empty state, and their own new-install deficits in workshop terminology before saving a shared fit.
#### Scenario: Distinguish support roles
- **WHEN** the recipient selects a shared repair, jammer or empty-utility fit on a frame with a utility interface
- **THEN** the selected fit identifies its utility or empty slot and lists missing parts with quantities, and saving preserves that definition without transferring parts.
#### Scenario: A shielded crawler and a light wheel
- **WHEN** a recipient inspects the two shared definitions
- **THEN** the crawler details identify its front armor and the wheel lists its three supported interfaces; neither shows unsupported interfaces as vacant slots
#### Scenario: Save a shield design after obtaining a spare
- **WHEN** a recipient owns a free shield, opens the shared shielded crawler and saves its definition
- **THEN** that shield is absent from the deficits, the saved definition retains the armor and both players retain their original parts

