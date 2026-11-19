## ADDED Requirements
### Requirement: Finite production and blueprint research
The service SHALL accrue three common resource types from eligible base facilities using server time, enforce storage and offline limits, and atomically record claims and finite blueprint research.
#### Scenario: Offline and capacity limits
- **WHEN** the owner returns after a short interval, 24 hours, three days or seven days
- **THEN** the claim matches the eligible production interval and capacities, without deterioration or banked overflow.
#### Scenario: Concurrent claims and production changes
- **WHEN** multiple devices claim the same interval or the owner changes power or facilities
- **THEN** production is credited once at the rates applicable during each interval.
#### Scenario: Research a blueprint
- **WHEN** the player purchases an available research once
- **THEN** the correct cost is recorded and its functional unlock becomes usable in the workshop.
