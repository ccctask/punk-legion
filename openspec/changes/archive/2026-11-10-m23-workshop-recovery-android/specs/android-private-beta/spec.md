## ADDED Requirements

### Requirement: Signed Android workshop recovery acceptance
The signed beta SHALL verify bounded confirmation recovery for workshop design and build operations under controlled reply loss and connection failure, retaining one original operation and charge.

#### Scenario: Committed build response is lost
- **WHEN** the service commits a build but its response does not reach Android
- **THEN** the Android workshop retries its original key at most once automatically per round, shows unconfirmed feedback if still uncertain, and confirms the same robot and receipt after manual recovery or relogin.

#### Scenario: Ordinary release environment after injection
- **WHEN** temporary fault injection is removed
- **THEN** the installed signed APK confirms normal workshop reads and writes against the verified frozen services, and temporary resources are cleaned before handoff.
