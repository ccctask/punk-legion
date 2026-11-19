## ADDED Requirements

### Requirement: Daily progress from collecting private production
The game SHALL count the first qualifying production claim or expedition of the current UTC day as the owner's completed daily, using the original receipt and actual credited items.

#### Scenario: A player finishes the day in the base
- **WHEN** an authoritative production claim deposits a positive amount in the owner's stock
- **THEN** the current daily shows completion, source, credited amount and receipt without a separate reward, including after reopening the base.

#### Scenario: Empty claims and daily rollover
- **WHEN** a claim credits zero or a prior qualifying receipt belongs to a previous UTC day
- **THEN** that receipt does not satisfy today's production goal; combat tutorial steps keep their own requirements.

#### Scenario: More than one qualifying activity
- **WHEN** the same owner later completes another qualifying activity that day
- **THEN** the earliest qualifying receipt remains the displayed daily result.
