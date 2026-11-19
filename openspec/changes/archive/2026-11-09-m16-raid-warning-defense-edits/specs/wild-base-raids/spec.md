## MODIFIED Requirements
### Requirement: Bounded authoritative wild raids on private bases
A private base SHALL receive advance warning of a wealth-scaled capped raid. The defense layout SHALL track committed base and platform edits during the warning, lock at the authoritative battle start, and settle a bounded outcome exactly once regardless of owner presence.
#### Scenario: Warning, defense and recovery
- **WHEN** an owner restores power or installs a module on a defensive platform before the attack begins
- **THEN** the warning and the battle use the updated layout with the original threat and schedule, powered fixed defenders act within their ranges, and the owner receives a report and a recovery interval
#### Scenario: Start deadline and replay
- **WHEN** a defense change takes effect at or after the start, including when the first post-deadline request is the edit itself
- **THEN** the current raid and its replay retain the last committed pre-start defense; otherwise-permitted changes still apply to the private base and in-use platform modules remain locked
#### Scenario: Bounded offline losses
- **WHEN** an offline owner loses a raid
- **THEN** protected resources and owned robots, equipped parts and blueprints survive, total material and repair losses obey their limits, and the same raid cannot be charged twice
#### Scenario: Current wealth and threat
- **WHEN** an owner dispatches robots or loses assets
- **THEN** deployed robots still count toward current wealth, enemy budgets remain capped and subsequent threat responds to the current account state

