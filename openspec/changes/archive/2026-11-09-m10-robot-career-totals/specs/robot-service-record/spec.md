## ADDED Requirements

### Requirement: Permanent robot career totals
The service SHALL retain and expose exactly three career statistics per owned robot: settled battles actually participated in, enemies defeated by its finishing hit, and effective durability restored to other friendly robots by its own repair action.

#### Scenario: Zero totals and persistent identities
- **WHEN** an owner reads a new robot or switches between identically named robots after a battle
- **THEN** each robot shows its own three totals, including zero; renaming or refitting preserves them under its permanent identity.

#### Scenario: Credit once after real participation
- **WHEN** a deployed machine participates and its result arrives repeatedly, or a registered seat never participates
- **THEN** the participating machine receives its authoritative contributions once; a canceled or absent seat receives none. Assists, healing received, overheal, commander or platform repairs and post-battle repairs do not increase its three totals.

#### Scenario: Minimal career storage
- **WHEN** a match settles and its receipt is subsequently reopened
- **THEN** deduplication and feature-specific receipts remain available without writing or exposing a per-machine battle history, event timeline or event bookmarks.


### Requirement: Favorite a persistent robot
The owner SHALL be able to favorite, filter and unfavorite their own robot by permanent identity.

#### Scenario: Reopen the garage
- **WHEN** the owner logs in after renaming or refitting a favorite
- **THEN** the same robot appears under the favorite filter; another account cannot read or modify that private favorite.

## REMOVED Requirements

### Requirement: Durable owned robot service history
**Reason**: 机体档案现仅保留三项累计及机体收藏。
**Migration**: 本轮以新账号验证；历史发行记录保留原版本说明。

### Requirement: Remember a robot and a battle event
**Reason**: 机体档案现仅保留三项累计及机体收藏。
**Migration**: 本轮以新账号验证；历史发行记录保留原版本说明。

### Requirement: 探索战报对应机体实际参战
**Reason**: 机体档案现仅保留三项累计及机体收藏。
**Migration**: 本轮以新账号验证；历史发行记录保留原版本说明。

### Requirement: Readable private-defense service events
**Reason**: 机体档案现仅保留三项累计及机体收藏。
**Migration**: 本轮以新账号验证；历史发行记录保留原版本说明。

### Requirement: 按机体统计各类战斗结果
**Reason**: 机体档案现仅保留三项累计及机体收藏。
**Migration**: 本轮以新账号验证；历史发行记录保留原版本说明。

### Requirement: 从探索战报查看机体本场时间线
**Reason**: 机体档案现仅保留三项累计及机体收藏。
**Migration**: 本轮以新账号验证；历史发行记录保留原版本说明。

### Requirement: Treasure combat assists belong to contributing machines
**Reason**: 机体档案现仅保留三项累计及机体收藏。
**Migration**: 本轮以新账号验证；历史发行记录保留原版本说明。
