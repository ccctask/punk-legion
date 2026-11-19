## ADDED Requirements

### Requirement: Reconcile uncertain private base saves
The client SHALL query the signed-in owner's edit receipt and latest layout after an ambiguous save response while the editor is open. Reconciliation SHALL use only reads and SHALL distinguish a confirmed commit from another player's session changing the same owner's layout.

#### Scenario: A committed reply is lost
- **WHEN** a save commits but its reply is lost and a second window subsequently edits the base
- **THEN** the editor identifies its own committed revision and renders the latest layout without automatically submitting another edit or charging for it again.

#### Scenario: The original request did not arrive
- **WHEN** the receipt is absent and the original revision is still current
- **THEN** the player can retry the original operation with the same key and payload, while a changed revision instead requires a new preview.

#### Scenario: Confirmation cannot be read
- **WHEN** a read fails or the player leaves the page
- **THEN** the editor offers a read-only retry while open and stops scheduled checks after exit.
