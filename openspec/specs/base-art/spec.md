# base-art Specification

## Purpose
为私人领地提供可重新导出的 Blender 地块、工坊和固定炮塔。游戏从冻结的模型发布物构建实际场景，按格网足印放置建筑，并为防守行为保留炮口与转动枢轴。

## Requirements

### Requirement: Reusable base art assets
The art pipeline SHALL provide an editable and reproducibly exported terrain tile, workshop building and fixed turret, rendered with the project style and placed through the normal base scene.
#### Scenario: Author and reimport
- **WHEN** an artist opens the saved Blender source and repeats export
- **THEN** Godot renders the same intended silhouettes, dimensions, materials and attachment orientation.
#### Scenario: Playable base
- **WHEN** the player places the workshop and turret on the base terrain
- **THEN** each model fits its footprint, leaves roads readable and exposes the turret pivot and muzzle for defense gameplay.

