## Purpose
让玩家在私人基地通过道路、用电与独立研究站解锁单件战术目镜的制造方式，随后可以把有独立编号的成品装到已有机器人上，保留机体身份与累计战绩。

## ADDED Requirements

### Requirement: Research the standalone visor blueprint
Commanders SHALL be able to build, power and select a private research station to acquire a permanent personal blueprint for crafting standalone tactical visors.

#### Scenario: Research at an available station
- **WHEN** an owner with sufficient stock requests optics research at a connected powered station
- **THEN** the service charges the stated cost once, teaches the blueprint once and returns the original receipt to an identical retry.

#### Scenario: Reject unavailable research
- **WHEN** a station is absent, unpowered or cannot reach the road, or the owner lacks materials
- **THEN** a new research request cannot spend stock or unlock the blueprint and the client shows the applicable reason.

### Requirement: Fabricate and fit an individual visor
The learned blueprint SHALL produce one owned visor per successful craft and allow the normal workshop to mount that physical instance on an existing compatible robot.

#### Scenario: Keep the blueprint when the station loses power
- **WHEN** an owner crafts after learning optics and the station has since lost power
- **THEN** one inventory slot and the displayed materials produce one visor; full inventory or insufficient materials cause no deductions.
