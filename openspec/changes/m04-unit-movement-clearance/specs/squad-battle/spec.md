## ADDED Requirements

### Requirement: Atomic reachable formation destinations
The shared Godot battle simulation SHALL plan an entire eligible movement formation before committing its goals. Destinations SHALL be reachable, outside static obstacles, distinct and separated using the robots' existing body radii, while respecting live robots and destination reservations outside the commanded group. A formation that cannot be placed under this deterministic policy SHALL leave all commanded movement and target caches unchanged.

#### Scenario: Multiple robots approach an obstacle or boundary
- **WHEN** a legal group moves toward a landmark footprint, a map boundary or an occupied location with sufficient reachable space
- **THEN** its eligible robots receive distinct, separated reachable destinations and move through legal routes instead of collapsing onto the same projected cell.

#### Scenario: The formation cannot be placed
- **WHEN** the planner cannot allocate every eligible member a legal reachable destination
- **THEN** none of the group's previous goals, targets or route caches is partially replaced, and no authority sequence or successful-command participation is advanced for that rejected order.

### Requirement: Live robot clearance during shared automatic movement
The shared Godot simulation SHALL preserve robot body clearance during normal and automatic movement without changing weapon range, damage or movement speed. Normal newly created close placements SHALL be able to separate without teleporting or deepening existing overlaps. Dynamic obstruction SHALL use bounded per-step work, retain meaningful pending goals and remain cancellable through normal legal commands.

#### Scenario: A robot pursues past an arrived ally or enemy
- **WHEN** normal pursuit, guarding, retreat or escorting encounters a live robot along its movement segment
- **THEN** it advances only along a safe segment, approaches or reroutes within reachable space, and can still attack under the original range and visibility rules without entering that robot's body.

#### Scenario: A narrow passage remains obstructed
- **WHEN** no safe onward segment or detour exists in the current step
- **THEN** the robot waits without a busy loop, teleportation or a false arrival, and a subsequent legal command can replace the pending movement.

#### Scenario: Reuse a route while a distant segment is temporarily occupied
- **WHEN** an existing route remains suitable and its next actual movement segment is safe but a distant segment is occupied
- **THEN** the simulation consumes only safe actual segments without rebuilding the full reachable region solely because of that distant occupancy.

#### Scenario: Deterministic deferred automatic replanning
- **WHEN** automatic movement needs a new reachable-region query before its next per-robot planning deadline
- **THEN** it retains its pending goal and safe movement without a fabricated command rejection, and retries on or after its next deterministic 0.5-simulation-second-cycle phase; coarse or mixed step durations do not starve a phase.

#### Scenario: Preserve automatic planning decisions on current-version resume
- **WHEN** a newly created checkpoint is restored during a planning wait
- **THEN** its planning deadline and original nearby request are restored before continuation, with invalid or missing decision fields rejected rather than migrated or silently reset.

#### Scenario: Resume current-version movement
- **WHEN** a newly generated checkpoint is restored during movement, pursuit or obstruction
- **THEN** its saved positions and caches are not repositioned on load, and the same subsequent inputs and steps produce the same movement as the original instance.

### Requirement: Correlated nonfatal movement rejection feedback
An authenticated current player SHALL receive visible nonfatal feedback when a new movement order is deterministically rejected because its formation cannot be placed. Rejection feedback SHALL preserve the authority's committed sequence and distinguish the rejected attempt from later successful commands. An uncommitted save or unknown result SHALL NOT be represented as a rejected unchanged order.

#### Scenario: Reject one attempt and accept a later command
- **WHEN** a legal movement attempt is rejected and a later command succeeds
- **THEN** the player sees the rejection, can continue commanding without reconnecting or reusing the attempt number, and the rejected attempt is never shown as executed by the later cumulative sequence.

#### Scenario: Stale or unrelated rejection
- **WHEN** a rejection belongs to an old battle, an older superseded attempt or a departed scene
- **THEN** it does not clear newer pending input, revive an old warning or advance a successful receipt.

#### Scenario: Storage has an unknown or unsaved result
- **WHEN** an accepted order awaits persistence or an existing terminal or pending-checkpoint gate prevents further publication
- **THEN** the existing recovery contract remains authoritative and the client receives no fabricated formation-rejection response for that unknown result.

### Requirement: Selected visible robot information remains readable
The battle presentation SHALL keep the existing name and health information of a visible, living selected robot readable against scene geometry without changing its authoritative state, world position or model visibility. The health material SHALL be isolated from shots and other robot instances. Landmark captions SHALL remain spatially separate from nearby robot information in the normal camera.

#### Scenario: A selected robot stands behind a landmark
- **WHEN** the existing selected robot name or health marker intersects a foreground landmark in the normal view
- **THEN** its information is readable using the existing world anchors, while the landmark, robot body and shots retain their ordinary geometry and the body must still be distinguishable in the original visual acceptance scene.

#### Scenario: Selection ends or the robot dies
- **WHEN** the robot is deselected, dies or its scene is released
- **THEN** the selected information policy ends without affecting shots, another instance, simulation state or the existing visibility and death lifecycle; previously hidden information is not newly revealed.
