## ADDED Requirements
### Requirement: Recovery interval follows the private raid outcome
The private raid authority SHALL schedule the next formal warning at least 48 hours after a loss and 24 hours after a win, preserving the existing owner-return protection. The defense report SHALL explain the applicable recovery interval.
#### Scenario: Recover from a loss
- **WHEN** the owner returns before the 48-hour recovery period ends, including after a loss with no exposed stock
- **THEN** the next warning keeps the same deadline and no new raid or debit occurs before that deadline
#### Scenario: Return after the recovery period
- **WHEN** the owner remains offline beyond the deadline and later returns
- **THEN** the authority grants the existing 24-hour return interval and never settles missed raids in a batch
#### Scenario: Successful defense
- **WHEN** the player wins and returns before the recovery period ends
- **THEN** the protection timer continues toward the original 24-hour deadline
