## ADDED Requirements
### Requirement: Bounded private raid recovery pressure
The service SHALL freeze a bounded recovery adjustment when scheduling each private raid warning. The normal warning screen SHALL show a positive reduction with its reason and resulting threat budget.
#### Scenario: Owner is recovering after a private defense loss
- **WHEN** the most recent settled private raid was a loss
- **THEN** deduct one threat point and deduct one more if its registered guard still needs repair, down to a final minimum of two; repeated losses do not stack.
#### Scenario: The situation changes after the warning
- **WHEN** an owner repairs, relogs, or reopens the replay after the warning
- **THEN** the displayed and simulated budget and roster remain the ones frozen for that encounter; a later warning after victory uses the normal wealth budget.
