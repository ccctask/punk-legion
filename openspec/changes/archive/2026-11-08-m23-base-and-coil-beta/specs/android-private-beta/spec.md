## ADDED Requirements

### Requirement: Distribute the base-first and two-camp client together
The signed closed-beta release SHALL enter the private base, route both public camps to their own authority and prevent previous clients that only address the default camp from performing territory operations on the new live service.

#### Scenario: Update the existing installation
- **WHEN** a commander upgrades a 1008 signed installation and logs into the migrated local service
- **THEN** their existing account and robots are recoverable from the base, and each map location opens its corresponding camp.

#### Scenario: An older client contacts its published address
- **WHEN** an old single-camp client uses its published profile address after cutover
- **THEN** the service returns an update requirement before the client can modify any territory data.

#### Scenario: Local service cutover
- **WHEN** the accepted build becomes the local beta
- **THEN** operators can verify the one live profile, the five real-time services and the original recoverable snapshot using the documented deployment and recovery procedure.
