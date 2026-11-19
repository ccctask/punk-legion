## ADDED Requirements
### Requirement: Reusable base art assets
The art pipeline SHALL provide an editable and reproducibly exported terrain tile, workshop building and fixed turret, rendered with the project style and placed through the normal base scene.
#### Scenario: Author and reimport
- **WHEN** an artist opens the saved Blender source and repeats export
- **THEN** Godot renders the same intended silhouettes, dimensions, materials and attachment orientation.
#### Scenario: Playable base
- **WHEN** the player places the workshop and turret on the base terrain
- **THEN** each model fits its footprint, leaves roads readable and exposes the turret pivot and muzzle for defense gameplay.
