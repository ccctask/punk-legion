## ADDED Requirements

### Requirement: Mount and recover an owned module on a stationary platform

The private base SHALL allow its owner to build a stationary platform, mount one compatible owned weapon or utility instance, and recover that same instance for future use.

#### Scenario: Reusing equipment

- **WHEN** an owner installs a compatible part and later removes it from an unlocked platform
- **THEN** that part is usable only by the platform while installed and the identical inventory instance becomes available again on removal.

#### Scenario: Atomic and exclusive use

- **WHEN** equip requests race for a part, an occupied platform is changed, or the request is retried
- **THEN** the part has at most one live assignment and stocks and charges reflect each accepted action once.

#### Scenario: Authoritative defensive behavior

- **WHEN** a wild raid locks a powered and armed or support-equipped platform
- **THEN** it remains stationary, its installed module determines its action, and reconnection or later loadout changes preserve the recorded raid's original configuration and outcome.

#### Scenario: Existing defense

- **WHEN** the player loads a base built before modular platforms
- **THEN** existing defenses and historical battles remain usable without creating repeatable equipment rewards.
