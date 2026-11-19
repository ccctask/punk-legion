## ADDED Requirements

### Requirement: Public workshop card on an occupied camp
Any signed-in commander SHALL be able to open the current camp owner's public workshop card from the world map. The card SHALL show the commander's public name, current public holdings and their resources, and an optional explicitly displayed plaque inscription.

#### Scenario: Visit a stranger and return
- **WHEN** a non-friend opens the card from an occupied camp and returns
- **THEN** the visitor sees only the public display fields and returns to the same map selection; a neutral camp or cooperative point offers no owner card.

#### Scenario: Public display and ownership changes
- **WHEN** a plaque is shared, withdrawn or replaced, or the camp changes hands
- **THEN** refreshed cards reflect the current owner's holdings and permitted inscription, and never carry forward a previous owner's private or expired display.
