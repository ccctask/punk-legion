## ADDED Requirements
### Requirement: Recover the active dossier read
The ordinary commander dossier SHALL recover a transient profile read failure on the current account and expose a manual refresh after bounded retries.
#### Scenario: Temporary failure while entering from base
- **WHEN** the current commander opens the dossier and the first profile GET fails transiently
- **THEN** the same page fetches the same commander again, applies only a valid response and displays the correct fleet without repeating writes.
