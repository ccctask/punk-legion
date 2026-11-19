## ADDED Requirements
### Requirement: Distinguish assembly exits in personal reports
The client SHALL identify voluntary withdrawal during assembly separately from a seat expiring before deployment in live and reopened personal reports.

#### Scenario: A commander exits before the squad starts
- **WHEN** a non-participating commander receives a retreat receipt
- **THEN** the summary and report identify withdrawal during assembly and show the recorded departure cost.

#### Scenario: A seat expires before deployment
- **WHEN** a non-participating commander receives an expired receipt
- **THEN** the summary and report identify assembly expiry without attributing a voluntary withdrawal.
