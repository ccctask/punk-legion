## ADDED Requirements
### Requirement: Protected treasure participation reward
The service SHALL award one common component for the first eligible personal settlement per account and UTC match-start day. The client SHALL distinguish actual cargo deposits and participation reward deposits and explain eligibility before entry.
#### Scenario: Eligible owner loses temporary cargo
- **WHEN** a player picks up an item successfully and later times out or becomes disabled
- **THEN** temporary cargo is lost and the eligible player receives the participation reward up to free warehouse capacity.
#### Scenario: Independent and bounded
- **WHEN** a teammate picks up an item, another result arrives that day, a receipt is reopened, or storage is full
- **THEN** only the actual picker qualifies, daily entitlement is consumed once even at capacity, extraction cargo is deposited first and totals match stock.
