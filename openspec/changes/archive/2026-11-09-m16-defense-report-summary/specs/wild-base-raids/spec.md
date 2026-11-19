## ADDED Requirements
### Requirement: Outcome-first private defense report
A settled defense report SHALL present the authoritative outcome, actual loot debits and damage status before the defense roster, with optional details and replay available from the report.
#### Scenario: Return to a heavily defended base
- **WHEN** an owner opens a settled report in a compact landscape viewport with multiple platforms
- **THEN** the outcome and actual resource loss are visible without scrolling and the player can inspect the recovery interval, expand the full roster and replay the same raid
#### Scenario: Separate incurred losses from possible repairs
- **WHEN** the raid has zero loot or a guard or facility is damaged
- **THEN** the summary shows the actual loss including zero, identifies damage and keeps any future repair quotes distinguishable from charged resources
#### Scenario: Refresh an open report
- **WHEN** the owner expands details and refreshes the same receipt or starts its replay
- **THEN** the receipt and stock remain unchanged and a same-report refresh preserves the chosen disclosure state
