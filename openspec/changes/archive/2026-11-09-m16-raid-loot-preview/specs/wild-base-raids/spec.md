## ADDED Requirements

### Requirement: Current stock exposure in a raid warning
The warning SHALL describe eligible resources above each insured floor and the combined maximum loot from the owner's current stock, separately from any repair cost.

#### Scenario: Viewing and refreshing a warning
- **WHEN** an owner views a warning and then refreshes after a stock change
- **THEN** eligible amounts and the combined upper bound reflect the current stocks and existing loot cap, including zero at or below all floors, without charging the owner or determining the random outcome.

#### Scenario: After the raid
- **WHEN** the owner opens the settled defense report
- **THEN** the report shows actual losses from its receipt and the warning estimate is absent.
