## ADDED Requirements
### Requirement: Show the collectible territory yield
The camp owner SHALL see the current collectible quantity, private free space for the local resource, and the amount left at the camp before collection.
#### Scenario: Partial transfer or uncertain acknowledgment
- **WHEN** the private warehouse has less room than the available yield
- **THEN** the partial transfer matches the authoritative receipt, the excess remains locally available, and an uncertain submission can recover its original receipt without a second credit.
