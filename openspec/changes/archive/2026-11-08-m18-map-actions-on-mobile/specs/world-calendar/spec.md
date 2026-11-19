## MODIFIED Requirements
### Requirement: 公开营地的可参战能力
系统 SHALL 根据各节点的服务端能力区分可争夺营地和日程预览。
#### Scenario: 公开营地的可参战能力
- **WHEN** 选中已开放争夺的黄铜转运场或线圈港，或只供预览的节点
- **THEN** 两个可争夺营地按各自日程展示登记与指挥入口，预览节点仅显示日程且不能登记。

## ADDED Requirements
### Requirement: Reach and identify a selected node's actions on mobile
The world map SHALL keep the selected activity actions visible on its supported landscape sizes and associate admission feedback with its originating node.
#### Scenario: Register and open a camp on a short screen
- **WHEN** a player selects either camp and registers on a 960×540 or 640×360 viewport
- **THEN** registration and the camp console are reachable without scrolling the schedule before or after the receipt, and the detailed risk and deadline remain readable.
#### Scenario: Change node during a pending request
- **WHEN** a player selects a different site while waiting for a registration or qualification result
- **THEN** that response cannot display the former site's confirmation or rejection under the new site, and the new site's actions refer to the selected site.
