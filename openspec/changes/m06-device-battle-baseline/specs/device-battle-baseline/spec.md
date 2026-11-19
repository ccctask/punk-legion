## ADDED Requirements
### Requirement: Reproducible battle scale measurements
A debug build SHALL allow target-device testing with twenty-four visible runtime robots in legal squads and report the device, workload, rendering settings and reproducible observations.
#### Scenario: Compare scenes and controls
- **WHEN** a tester runs the standard camera and combat workload on a recorded handset
- **THEN** the report includes loading, frame time, memory, heat, control readability and the actual peak unit count.
#### Scenario: Verify mobile network recovery
- **WHEN** the same handset issues commands under baseline and impaired connectivity and reconnects
- **THEN** measurements report the conditions, observed command delays and authoritative recovery state.

#### Scenario: First Android emulator acceptance
- **WHEN** the team evaluates the local beta on an Android emulator before selecting a physical handset
- **THEN** the report identifies the emulator, host GPU, resolution, actual battle and sample length, measures rendered frame intervals and command response, records control visibility, and tracks physical touch occlusion, sustained heat and handset-specific budgets for a later named device.
