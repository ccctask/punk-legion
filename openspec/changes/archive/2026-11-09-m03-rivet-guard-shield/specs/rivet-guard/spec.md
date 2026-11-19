## ADDED Requirements
### Requirement: Craft and equip a physical front shield
The workshop SHALL manufacture one identifiable rivet shield per paid craft and permit a crawler to mount it within its payload and command budget.
#### Scenario: Reuse a mounted shield
- **WHEN** a commander crafts a shield for three structure and one component, mounts and later removes it
- **THEN** the same physical part returns to inventory and the one-point surcharge is removed
#### Scenario: Unsupported frame
- **WHEN** mounting on a biped, a fixed platform or an overweight crawler
- **THEN** the attempt fails without consuming or duplicating a part
### Requirement: Directional combat protection
The battle authority SHALL reduce direct damage by forty percent inside the forward 120-degree arc and communicate the shield heading to the player.
#### Scenario: Compare attack bearings
- **WHEN** identical direct hits arrive from the front, side and rear
- **THEN** only the front hit is reduced and credited damage reflects the actual health lost
#### Scenario: Area impact or reconnect
- **WHEN** an area impact lands or the client resumes the same match
- **THEN** area damage retains its ordinary value and the client receives the current authoritative heading
