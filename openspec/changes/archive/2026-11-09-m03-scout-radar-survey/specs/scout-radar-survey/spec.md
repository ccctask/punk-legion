## ADDED Requirements
### Requirement: Equip and field a survey scout
The workshop SHALL let a commander manufacture a physical survey radar, install it only on a compatible survey socket, and share and deploy a valid four-mass wheeled scout.
#### Scenario: Build a complete scout
- **WHEN** a player fits a survey wheel with a boiler, eye, rivet repeater and survey radar
- **THEN** the assembly has 38 maximum durability with the standard boiler, costs three command points, shows the radar, and keeps the same installed items and entity on reconnect
#### Scenario: Incompatible refit
- **WHEN** a player attempts to change to a standard wheel while its radar remains installed
- **THEN** the quote identifies the incompatible slot and a rejected transaction preserves stock and installed items
### Requirement: Scout sealed field supplies together
The treasure authority SHALL keep two sealed crates identifiable by proximity and share discoveries only with the discovering side through the rest of the match.
#### Scenario: Scout ahead of a teammate
- **WHEN** a living deployed radar carrier approaches within five metres and the opponents remain beyond their own detection ranges
- **THEN** both teammates see the revealed contents, opponents still see sealed crates, and reconnect restores each side’s knowledge
#### Scenario: Retrieve a crate without radar
- **WHEN** a regular robot reaches a sealed crate within 1.7 metres and picks it up
- **THEN** its side learns the contents and extraction credits the original contents under the existing personal limits
