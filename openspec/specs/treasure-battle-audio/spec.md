# treasure-battle-audio Specification

## Purpose
秘宝争夺为左右两边的玩家播放与己方机体动作相符的机械音效，并在席位失效或个人结算时停止。每位玩家的低耐久提示依据本席可见友军的真实耐久变化，同时遵守本机保存的音量设置与三声部预算。

## Requirements

### Requirement: Friendly treasure battle cues
During an active treasure match, the client SHALL apply the existing mechanical sounds and saved effects level to visible friendly robots on the local seat’s side, and silence battle voices on disconnect, personal settlement or exit.

#### Scenario: Either starting side hears its own squad
- **WHEN** friendly and enemy units move, fire, or cross the danger threshold in view
- **THEN** only eligible friendly actions on the observing seat’s side produce the corresponding cues, with at most three simultaneous voices.

#### Scenario: Recover or end a session
- **WHEN** a seat disconnects, reconnects with a repeated snapshot, receives a personal result, or exits
- **THEN** stale alerts are not replayed and ongoing battle voices stop when the seat is inactive.

### Requirement: Treasure tracks stop while authority stalls
The client SHALL end the looping track audio once visible friendly crawlers have stopped at their last confirmed positions during a sustained gap in authoritative frames.

#### Scenario: Network stays connected but stops sending updated positions
- **WHEN** the moving robot reaches its last known pose and no fresh tick arrives for a sustained interval
- **THEN** the track loop stops, transient combat alerts are not replayed and movement can be heard again when subsequent frames resume travel.
