## ADDED Requirements
### Requirement: Manufacture and refit owned robots
The service SHALL save account-owned versioned designs and atomically manufacture or refit uniquely identified robots with legal owned parts through the workshop.
#### Scenario: Manufacture two instances
- **WHEN** an account uses a saved design to manufacture two robots in distinct paid transactions
- **THEN** each robot has its own stable identity and installed items; retrying a transaction does not charge again.
#### Scenario: Swap or reject a part
- **WHEN** a legal replacement is installed
- **THEN** the former item returns to that owner's available inventory and the replacement cannot simultaneously equip another robot.
#### Scenario: Invalid request or occupied machine
- **WHEN** a design is illegal, resources are insufficient, ownership conflicts, or the robot has an active assignment
- **THEN** the operation fails with a visible reason and preserves inventory, robot fit and balances.
#### Scenario: Reopen the workshop
- **WHEN** the owner signs back in and selects a manufactured robot
- **THEN** the workshop presents its saved fit and a matching preview with the same robot identity.
