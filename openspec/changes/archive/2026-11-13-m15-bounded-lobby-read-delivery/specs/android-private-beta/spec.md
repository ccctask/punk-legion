## ADDED Requirements

### Requirement: Bounded delivery for successful cooperative lobby reads
The profile service SHALL permit well-framed successful HTTP/1.1 GET requests for the party, pump and factory cooperative lobby snapshots to use the existing six-second idle keep-alive window. Each request SHALL be authenticated independently, and snapshot protection, read retry limits and write submission semantics SHALL remain unchanged.

#### Scenario: Read a changing cooperative lobby
- **WHEN** the Android player reads a cooperative lobby while another legitimate member leaves and rejoins
- **THEN** complete framed snapshots expose the current membership while preserving the player's valid selection and permitting preparation only after a confirmed read.

#### Scenario: Persistence remains bounded and scoped
- **WHEN** a lobby request uses HTTP/1.0, explicitly closes, has unsupported framing, fails authentication or business processing, targets an unselected route, or exceeds the idle window
- **THEN** the existing closing behavior remains, no previous request's authentication is reused, and reads cause no entry charge or deployment.
