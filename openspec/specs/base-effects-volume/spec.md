# base-effects-volume Specification

## Purpose
玩家可在私人基地或试车台调节本机战斗音效，正在播放的声音及时响应，重新启动客户端后保留设置。两处入口共用四档音量，玩家可以在出发前静音，也能在本地演习进行时改变音量。

## Requirements

### Requirement: Control battle effects from the base
The game SHALL share one locally persisted effects level between the base menu and range and apply a successful change to existing battle audio players.

#### Scenario: Silence before departure
- **WHEN** a player selects mute in the base menu and later starts a battle or restarts the client
- **THEN** the effects remain muted.

#### Scenario: Change volume during playback
- **WHEN** the player mutes active battle effects and later restores a nonzero level
- **THEN** active voices stop immediately and restoring sound does not replay earlier one-shot cues.


