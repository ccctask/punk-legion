## ADDED Requirements

### Requirement: Action-linked mechanical sound cues

The client SHALL play distinguishable mechanical movement, steam-action and danger sounds for corresponding local or authoritative battle states, respect the player's saved mute setting, and bound simultaneous voices.

#### Scenario: Controlling a squad

- **WHEN** the player moves a squad, triggers a steam action and a friendly robot enters a supported danger state
- **THEN** the matching sounds can be distinguished in the normal battle and each danger transition produces one cue.

#### Scenario: Leaving and resuming

- **WHEN** repeated network snapshots arrive or the player exits and reconnects
- **THEN** ongoing sounds end on exit and already observed events do not cause repeated alert sounds.

#### Scenario: Playing muted

- **WHEN** a player mutes game effects, closes the client and returns
- **THEN** effects remain silent while the same controls, visible status and battle results remain usable.
