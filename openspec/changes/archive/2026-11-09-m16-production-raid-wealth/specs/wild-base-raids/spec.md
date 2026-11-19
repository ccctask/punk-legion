## ADDED Requirements

### Requirement: Count completed private production once for threat
The server SHALL value completed, claimable private production at the same resource weights as stocks when freezing a raid warning. It SHALL apply the production limits at the scheduled warning and preserve both the frozen budget and the original stock-only loss rules.

#### Scenario: Same production with different claim timing
- **WHEN** two otherwise equivalent owners claim immediately before and after the warning boundary
- **THEN** their frozen wealth and enemy budget match, each resource is counted once, and subsequent real spending may reduce future wealth.

#### Scenario: Offline production and insured stock
- **WHEN** a warning is processed late while a production line partly or fully completes cycles
- **THEN** only claimable units completed by warning time within storage and offline caps affect threat, later production remains claimable on schedule, and a loss cannot debit unclaimed production.
