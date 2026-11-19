## ADDED Requirements
### Requirement: Recover a lost defense read in place
The client SHALL retry transient failures of defense status and linked guard condition reads with bounded delays and preserve the intended target for manual retry.

#### Scenario: Temporary unavailability
- **WHEN** a defense read fails then the service recovers
- **THEN** recover the same view using GET requests with at most two automatic retries per failed read sequence.

#### Scenario: Settlement or guard registration has an uncertain reply
- **WHEN** the client must reconcile an ambiguous write result
- **THEN** any automatic recovery is read-only and cannot repeat a charge or guard assignment.
