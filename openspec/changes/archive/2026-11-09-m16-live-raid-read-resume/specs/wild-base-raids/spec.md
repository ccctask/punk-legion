## MODIFIED Requirements
### Requirement: Recover a lost defense read in place
The client SHALL retry transient failures of defense status and linked guard condition reads with bounded delays and preserve the intended target for manual retry.
#### Scenario: Temporary unavailability
- **WHEN** a defense read fails then the service recovers
- **THEN** the client initially allows at most two rapid GET retries and preserves the view.
#### Scenario: Visible active raid outlasts rapid retries
- **WHEN** an open warning or live defense with a confirmed snapshot remains temporarily unreachable after the rapid retries
- **THEN** the client retains its last confirmed frame, permits manual refresh, and queries status once per ten seconds until a valid response, permanent failure, or departure, without repeating a write.
#### Scenario: Settlement or guard registration has an uncertain reply
- **WHEN** the client must reconcile an ambiguous write result
- **THEN** any automatic recovery is read-only and cannot repeat a charge or guard assignment.
