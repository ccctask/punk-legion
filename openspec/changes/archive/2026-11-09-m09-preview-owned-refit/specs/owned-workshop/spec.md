## ADDED Requirements
### Requirement: Review fitting an owned robot
The workshop SHALL let the commander review a saved design against a named owned robot and its actual parts before applying it.
#### Scenario: Confirm a reviewed change
- **WHEN** a commander reviews the slots and confirms an eligible change
- **THEN** the reviewed parts are applied atomically to the selected robot, or a changed plan is refused and can be reviewed again; a preview or cancellation moves no parts.
