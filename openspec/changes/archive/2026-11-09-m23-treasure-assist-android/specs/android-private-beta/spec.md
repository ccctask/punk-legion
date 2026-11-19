## ADDED Requirements

### Requirement: Signed Android treasure assist history
The signed Android beta SHALL expose a robot’s credited treasure assist in its own combat timeline and allow the player to return to the same highlighted event after relaunch.

#### Scenario: Two allied robots contribute to one knockout
- **WHEN** a signed Android player finishes a newly generated treasure battle in which one owned robot damaged a target and another delivered the final hit, then opens both robots’ histories
- **THEN** the contributor shows one assist for that target and the finisher shows the knockout, matching the authoritative room settlement.

#### Scenario: Return to a saved assist
- **WHEN** the player saves the assist as a highlight and relaunches the signed app with the same newly created account
- **THEN** opening that highlight selects the same robot, battle, target and timeline event without duplicating the assist.
