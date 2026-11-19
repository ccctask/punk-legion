## ADDED Requirements

### Requirement: Verify a lost save response in the signed client
The signed Android client SHALL automatically read the committed edit receipt after losing a successful build response and show the saved revision and charge in the private base editor.

#### Scenario: Receive a receipt without a second tap
- **WHEN** the server accepts a base construction and the phone does not receive the response
- **THEN** the player sees the matching receipt without touching the screen again, the service records one build and one charge, and reopening the base shows the saved structure.
