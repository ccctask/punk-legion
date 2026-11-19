## ADDED Requirements

### Requirement: Signed Android cooperative lobby recovery
The signed Android beta SHALL deliver the reviewed cooperative lobby read recovery, protect actions requiring an authoritative snapshot, and preserve normal cooperative deployment and personal settlement on the matching local release.

#### Scenario: Recover or stop a failed lobby read
- **WHEN** a player opens a cooperative lobby before its first valid snapshot or encounters a temporary read failure, exhausted retries, or an expired session
- **THEN** Android shows the applicable recovery action, permits no dependent write before confirmation, uses at most two automatic read retries, and does not automatically resubmit writes.

#### Scenario: Background, return and close on Android
- **WHEN** the installed app actually enters the Android background, resumes, or leaves a lobby while a read is in flight
- **THEN** inactive lobby polling and old queued actions stop, return obtains a fresh confirmation, and leaving causes no invalid UI access or subsequent submission from the closed scene.

#### Scenario: A processed preparation loses its reply
- **WHEN** the service accepts preparation but Android loses the response
- **THEN** the installed client reads the authority to display the current state without another preparation POST, distinguishing an uncertain sent operation from one never sent.

#### Scenario: Ordinary release after fault verification
- **WHEN** temporary fault transport is removed and the signed client starts a cooperative expedition with another fresh account
- **THEN** both seats can authenticate, assemble, start, issue a valid command and obtain separate once-only personal settlements; the same task's confirmed state remains readable after a cold app restart before playable handoff.
