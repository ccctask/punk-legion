## ADDED Requirements

### Requirement: Plan a powered base across expanded land
The base SHALL compute supply coverage from the core and enabled relays within six Manhattan cells of the core footprint. Each connected relay SHALL extend coverage by six cells, without increasing the six-point supply budget or enabling other relays. Clients SHALL preview coverage and changes in operating state before accepting a layout edit.

#### Scenario: Establish an eastern production line
- **WHEN** an owner places a foundry beyond core coverage, then builds a reachable relay covering its nearest tile
- **THEN** the first preview explains why it will be offline and the committed relay starts production if capacity remains.

#### Scenario: Move or pause a relay
- **WHEN** the player previews and confirms a change to a core or relay
- **THEN** affected buildings are identified before spending, and subsequent production, repair capacity and raid defense use the confirmed operating state according to their existing timing and snapshot rules.

#### Scenario: Reach differs from budget
- **WHEN** relays overlap, a second relay lies only in another relay's area, or demand exceeds capacity
- **THEN** only directly linked relays extend coverage, total supply stays six, and the player can distinguish distance, manual pause and insufficient capacity.
