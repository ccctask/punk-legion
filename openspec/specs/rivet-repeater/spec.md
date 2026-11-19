# rivet-repeater Specification

## Purpose
Define the cost, fit, combat behavior and fixed-platform use of the lightweight rivet repeater so players can trade firing range for payload when assembling a scouting robot.

## Requirements

### Requirement: A buildable lightweight rapid-fire tool
The game SHALL support a one-mass ARM tool with individually resolved short-range shots in the workshop, shared designs, authoritative battles and compatible base defense platforms.
#### Scenario: Assemble a scouting loadout
- **WHEN** a commander crafts the repeater and equips a wheeled frame with a standard boiler and tactical visor
- **THEN** the complete loadout fits four payload, quotes the correct materials, preserves the robot identity and shows a distinct toy arm in the garage and battle
#### Scenario: Compare direct fire
- **WHEN** a repeater and a basic cannon engage identical targets at close and intermediate distances
- **THEN** the repeater fires more frequently for lower damage per hit at close range and the cannon alone reaches a stationary target at four metres
#### Scenario: Share and deploy
- **WHEN** a friend receives the design or the machine joins a room and reconnects
- **THEN** the same part definition is preserved and the recipient requires their own parts
#### Scenario: Install a defense weapon
- **WHEN** an owner installs the physical repeater on a powered compatible platform and later removes it
- **THEN** the raid resolves the fitted weapon and the owner recovers that same item
