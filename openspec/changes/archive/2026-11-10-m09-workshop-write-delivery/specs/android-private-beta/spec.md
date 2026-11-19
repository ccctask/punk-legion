## ADDED Requirements

### Requirement: Bounded delivery for successful workshop writes
The profile service SHALL permit well-framed successful HTTP/1.1 workshop design and build requests to use the existing bounded six-second idle keep-alive window, while preserving original-key receipts, charges and per-request authentication.

#### Scenario: An unchanged Android client confirms a write
- **WHEN** the Android client saves a design or builds a robot with a complete supported request on a connection permitting persistence
- **THEN** it can receive the complete framed result without immediate server closure, and repeating the original key returns the same receipt without an additional charge.

#### Scenario: Persistence boundaries remain enforced
- **WHEN** a request explicitly closes the connection, uses HTTP/1.0, fails authentication or business validation, is outside the selected routes, or the idle window expires
- **THEN** the original close behavior remains, and every request received on a persistent connection is authenticated independently.
