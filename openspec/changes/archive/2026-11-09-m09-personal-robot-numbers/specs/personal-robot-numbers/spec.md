## ADDED Requirements
### Requirement: A free cosmetic number belongs to an individual robot
The garage SHALL let a commander preview, set or remove a two-digit number on an owned, available robot without consuming stock or changing gameplay attributes.
#### Scenario: Distinguish two identical machines
- **WHEN** the owner assigns 07 and 70 to two robots assembled from the same design
- **THEN** their bodies show the respective numbers, the original IDs are preserved and the loadouts and career totals stay the same
#### Scenario: Authoritative presence
- **WHEN** the machines deploy, are seen by another participant or resume the same room
- **THEN** their individual cosmetic numbers reflect the authoritative match snapshot
#### Scenario: Separation from blueprint and refit
- **WHEN** another machine is built from the same blueprint or its original owner swaps the numbered robot's chassis
- **THEN** the new machine starts unnumbered while the original robot retains its number

