## ADDED Requirements

### Requirement: Two public camps with independent stocks and garrisons
The game SHALL allow a player to hold both Brass Yard and Coil Depot with independent garrisons, production, capacity, and ownership, while enforcing one assignment per robot.

#### Scenario: Hold two camps
- **WHEN** the owner of both camps deploys distinct robots and collects from each
- **THEN** Brass Yard credits structure and Coil Depot credits components up to each resource storage limit, with excess held at its producing camp.

#### Scenario: Lose only the depot
- **WHEN** a different commander captures the depot and the outcome is retried
- **THEN** only its ownership, local stock and affected garrison change once, and the yard and private inventory remain intact.

