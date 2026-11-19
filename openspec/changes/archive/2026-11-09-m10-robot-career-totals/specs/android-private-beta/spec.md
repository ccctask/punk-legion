## ADDED Requirements

### Requirement: Signed Android robot career totals
The signed Android beta SHALL expose the selected owned machine’s settled participation count, finishing kills and effective repair output.

#### Scenario: Inspect two machines
- **WHEN** a player opens two same-name machines, then relaunches and returns to the garage
- **THEN** the three authoritative values match each machine’s identity, including a new robot with three zero values.

## MODIFIED Requirements

### Requirement: Coordinated tactical content upgrade
The beta SHALL distribute an identifiable client and matching local services supporting playable chassis, squad orders, party continuity, disruption and owned robot favorites.

#### Scenario: Return from version 1007
- **WHEN** an existing 1007 player installs the signed update and enters the corresponding service
- **THEN** their original robots, parts, purchased capacity and applicable gameplay receipts remain accessible and new tactical features can be exercised through the normal Android client.

#### Scenario: Old client with incompatible gameplay rules
- **WHEN** a previous client cannot represent the new rules for an active service
- **THEN** the player sees the upgrade requirement before any new activity can consume inventory or enter a mismatched battle.

### Requirement: 安卓可核对合作探索机体服役记录
签名安卓内测 SHALL 按真实参战事实显示机体的参战场数。
#### Scenario: 一人作战一人缺席
- **WHEN** 一名玩家实际作战后撤退，而队友到截止仍未进入
- **THEN** 作战方在机库看到该机体参战场数增加一次，并在玩法回执中看到主动撤退，缺席方收到过期回执且机体参战数保持原值，双方机体都解除派遣。

### Requirement: 安卓基地防守与战后送修
签名内测 APK SHALL 支持在同一客户端从私人基地查看新场次的野生袭击记录，并按当前库存判断能否送修。
#### Scenario: 防守中受修后战损
- **WHEN** 玩家在新生成的防守中受到维修平台支援并产生战损
- **THEN** 正常安卓野袭回放可核对平台和战损，机况页可辨认受损机体；修理站能读出材料缺口，补足后正常送修。

## REMOVED Requirements

### Requirement: 签名安卓机体战报与累计战绩
**Reason**: 机体档案现仅保留三项累计及机体收藏。
**Migration**: 本轮以新账号验证；历史发行记录保留原版本说明。

### Requirement: Signed Android treasure assist history
**Reason**: 机体档案现仅保留三项累计及机体收藏。
**Migration**: 本轮以新账号验证；历史发行记录保留原版本说明。
