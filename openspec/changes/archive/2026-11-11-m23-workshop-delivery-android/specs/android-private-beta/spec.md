## ADDED Requirements

### Requirement: Signed release integrates bounded workshop delivery
The signed Android beta and its frozen profile service SHALL integrate the accepted bounded workshop write delivery policy and be verified together on fresh data before playable handoff.

#### Scenario: Confirm writes and return to the same workshop
- **WHEN** a new owner saves three successive design versions and manufactures their robots in the signed Android client
- **THEN** on-device confirmations agree with once-only receipts, actual robot identities and resource charges, including after a cold relogin.

#### Scenario: Replace the playable release
- **WHEN** the candidate passes independent package, live service and Android acceptance
- **THEN** the previous release's containers and dedicated network are removed, its named volumes are preserved, and the new playable version and evidence are recorded.
