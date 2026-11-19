## ADDED Requirements
### Requirement: Numbered fleet and shared chassis on Android
The signed Android client SHALL preserve per-robot hull numbers across sessions and display shared designs using the interfaces of the selected chassis.
#### Scenario: Return to a numbered machine
- **WHEN** a player saves 07 through the touch garage and reopens the game
- **THEN** the same robot displays 07 and a second machine built from its design starts unnumbered
#### Scenario: Receive a chassis design
- **WHEN** a friend shares a design with an optional part on a supported interface
- **THEN** the recipient sees that part and its ownership requirement and can save the design without receiving the sender’s parts or machine number
