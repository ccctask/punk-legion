# world-calendar Specification

## Purpose
规定公共区域地图的节点、归属与风险展示，以及服务器如何按开放窗口与截止时间授予、绑定及恢复真实营地战斗资格。组队探索与公开争夺分别进入。

## Requirements

### Requirement: 可区分玩法与风险的世界地图
世界地图 SHALL 展示不可占领的组队探索和可丢失的资源营地，以及占领营地当前归属和服务器日程。
#### Scenario: 从地图选择活动
- **WHEN** 玩家分别选中一个探索区和一个公共营地
- **THEN** 探索区可进入组队流程且无占领动作，营地显示归属、被夺取风险、开放窗口及停止新入场的时刻。

### Requirement: 服务器日程判断入场资格
服务器 SHALL 按持久化的日程版本和服务器当前时刻裁定新参战请求，并保留已获准场次的结算资格。
#### Scenario: 开放与截止
- **WHEN** 客户端更改系统时钟、切后台或在跨午夜窗口的开放和截止边界申请进入
- **THEN** 只有服务端判定处于可入场区间的新场次会被接受，在截止时刻拒绝新场次。
#### Scenario: 修改与重启
- **WHEN** 当前窗口的有效日程更新，或服务器在已获准场次进行中重启
- **THEN** 地图能够刷新到正确版本和状态，原有场次可以恢复并按创建时公布的规则完成，非法配置不会覆盖现行版本。

### Requirement: 公开营地的可参战能力
系统 SHALL 根据各节点的服务端能力区分可争夺营地和日程预览。
#### Scenario: 公开营地的可参战能力
- **WHEN** 选中已开放争夺的黄铜转运场或线圈港，或只供预览的节点
- **THEN** 两个可争夺营地按各自日程展示登记与指挥入口，预览节点仅显示日程且不能登记。

### Requirement: Two live camp entry points on server schedules
The map SHALL show the product and schedule of each live camp and route a qualified participant into the corresponding authoritative contest.

#### Scenario: Independent simultaneous windows
- **WHEN** both camps open in the same test window and distinct squads enter both
- **THEN** the server admits them to separate battles with their own objectives and settlement identifiers.

#### Scenario: Only one camp open
- **WHEN** the depot window is closed and the yard window is open
- **THEN** the depot shows its next schedule and the yard remains available under its own qualification rules.

### Requirement: Reach and identify a selected node's actions on mobile
The world map SHALL keep the selected activity actions visible on its supported landscape sizes and associate admission feedback with its originating node.
#### Scenario: Register and open a camp on a short screen
- **WHEN** a player selects either camp and registers on a 960×540 or 640×360 viewport
- **THEN** registration and the camp console are reachable without scrolling the schedule before or after the receipt, and the detailed risk and deadline remain readable.
#### Scenario: Change node during a pending request
- **WHEN** a player selects a different site while waiting for a registration or qualification result
- **THEN** that response cannot display the former site's confirmation or rejection under the new site, and the new site's actions refer to the selected site.

### Requirement: Public workshop card on an occupied camp
Any signed-in commander SHALL be able to open the current camp owner's public workshop card from the world map. The card SHALL show the commander's public name, current public holdings and their resources, and an optional explicitly displayed plaque inscription.

#### Scenario: Visit a stranger and return
- **WHEN** a non-friend opens the card from an occupied camp and returns
- **THEN** the visitor sees only the public display fields and returns to the same map selection; a neutral camp or cooperative point offers no owner card.

#### Scenario: Public display and ownership changes
- **WHEN** a plaque is shared, withdrawn or replaced, or the camp changes hands
- **THEN** refreshed cards reflect the current owner's holdings and permitted inscription, and never carry forward a previous owner's private or expired display.
