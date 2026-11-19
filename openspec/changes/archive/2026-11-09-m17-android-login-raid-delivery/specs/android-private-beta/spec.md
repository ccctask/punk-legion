## ADDED Requirements
### Requirement: Correlate Android login and raid polling delivery
The beta verification process SHALL distinguish a successful service response from a successful on-device login or raid read using fresh accounts, the same signed client and time-correlated evidence without credentials.
#### Scenario: Connection loss before or after the response
- **WHEN** a signed client reports a transport error during login or defense polling
- **THEN** the investigation compares matching service events and normal client behavior and records whether a bounded response-delivery change is warranted.

### Requirement: Bounded delivery for successful sign-in and private raid reads
The profile service SHALL allow a well-framed successful HTTP/1.1 session creation or private raid status read to use its existing bounded keep-alive window. Every request on a reused connection SHALL be authenticated independently.
#### Scenario: Normal client reads the result
- **WHEN** the Android client requests a session or a private raid on a connection permitting persistence
- **THEN** it can receive the complete response without an immediate server close and without automatically resubmitting a login; explicit close, errors and unrelated writes still close the connection.
