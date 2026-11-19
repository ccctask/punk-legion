# Spec Delta

## ADDED Requirements

### Requirement: Durable acknowledgement of solo commands
The solo authority SHALL acknowledge an accepted command only after its complete checkpoint is saved. A failed save SHALL preserve the current in-memory mission while suspending further commands, simulation and publication until recovery or terminal resolution. This contract does not require every periodic movement frame to be durably saved.

#### Scenario: Save fails after accepting a command
- **WHEN** a legal command changes a current-run mission and its save fails
- **THEN** the authority sends no success acknowledgement or affected full/dynamic state, does not execute another command or simulation step, and retains that mission and command sequence for bounded retry.

#### Scenario: Storage recovers before expiry
- **WHEN** the retained mission is successfully saved before its original deadline
- **THEN** current authorized seats receive the recovered authoritative state with the accepted sequence, and the original command is not executed again.

#### Scenario: Disconnect or seat transfer during a failed save
- **WHEN** the player disconnects or another authorized connection takes over while a checkpoint remains unsaved
- **THEN** the retained mission is not replaced by an older checkpoint and no connection receives its uncommitted state; recovery preserves the current seat's authority.

#### Scenario: Recovery occurs after the deadline
- **WHEN** storage recovers after the original mission deadline
- **THEN** the deadline remains unchanged and the mission resolves through the existing terminal rules before active play can resume.

### Requirement: Immutable solo terminal delivery
The solo authority SHALL preserve a durably recorded terminal result as the immutable delivery payload, even when its subsequent checkpoint fails. An older checkpoint SHALL NOT be combined with terminal flags and published as a recovered mission. A previously committed profile receipt remains authoritative and cannot be replaced by a conflicting late result.

#### Scenario: Terminal evidence succeeds but checkpoint fails
- **WHEN** terminal evidence is durably written and the following checkpoint cannot be saved
- **THEN** delivery uses that original terminal payload and never reconstructs its combat facts from the older checkpoint, including after a same-version restart.

#### Scenario: The first terminal write fails before expiry
- **WHEN** the mission has already reached a terminal outcome but its first terminal write fails and storage recovers after expiry
- **THEN** it preserves that outcome, original finish time and combat facts rather than replacing them with a later expiry outcome.

#### Scenario: Recorded terminal evidence cannot be read
- **WHEN** terminal evidence exists but is unreadable or structurally invalid
- **THEN** the solo authority does not restore active play from an older checkpoint or overwrite the terminal evidence, and retains the task for bounded recovery or diagnosis.

#### Scenario: The profile already committed a different expiry receipt
- **WHEN** delivery receives a result conflict for a solo-hosted timed activity
- **THEN** repeated automatic submission of that payload stops, its evidence is retained, and an authenticated recovery receives only the existing matching profile receipt; neither rewards nor damage are applied a second time.

#### Scenario: No authenticated player is available after restart
- **WHEN** conflicting terminal evidence exists without valid current-session credentials
- **THEN** the authority retains it for the next legitimate reconnect, does not resume active play or invent credentials, and makes no guarantee of unattended receipt retrieval; a restart can attempt the original payload again without changing it.

#### Scenario: A late authentication response arrives after terminal resolution
- **WHEN** an earlier in-flight admission request returns active deployment after that mission has become terminal or settled
- **THEN** it does not recreate an active mission, publish a mixed checkpoint, or regain command authority.
