## ADDED Requirements
### Requirement: Bounded authoritative wild raids on private bases
A private base SHALL receive advance warning of a wealth-scaled capped raid, defend from a locked layout, and settle a bounded outcome exactly once regardless of owner presence.
#### Scenario: Warning, defense and recovery
- **WHEN** a raid is announced, the owner edits their base, and the battle resolves
- **THEN** the locked layout governs that battle, powered fixed defenders act within their ranges, and the player receives a report and a recovery interval.
#### Scenario: Bounded offline losses
- **WHEN** an offline owner loses a raid
- **THEN** protected resources and owned robots, equipped parts and blueprints survive, total material and repair losses obey their limits, and the same raid cannot be charged twice.
#### Scenario: Current wealth and threat
- **WHEN** an owner dispatches robots or loses assets
- **THEN** deployed robots still count toward current wealth, enemy budgets remain capped and subsequent threat responds to the current account state.
