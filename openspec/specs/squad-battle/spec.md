# squad-battle Specification

## Purpose
验证有限编队在中继站的即时指挥、目标争夺与单局战绩结算。系统根据服务端可复用的统一规则模拟寻路、集火、维修和退出，并记录逐台机体的最终状态。

## Requirements

### Requirement: 即时小队战斗
游戏 SHALL 从通过校验的编队建立战场，支持选择、移动、集火、有限次维修与撤退。

#### Scenario: 路障与后排目标
- **WHEN** 玩家指挥小队经过障碍或集火敌人
- **THEN** 单位绕行可达路线，在有效射程攻击指定或自动选择的敌方

### Requirement: 明确终局
模拟 SHALL 只结算一次，记录个人战绩、经过时间、占领进度与结束原因。

#### Scenario: 占领、超时、撤退或全灭
- **WHEN** 满足任一结束条件
- **THEN** 停止模拟，返回明确胜负与单局战绩，显示重新出击入口

### Requirement: Evaluate the quantity and quality tradeoff using playable formations
A balance review SHALL compare legal equally budgeted player formations on the shipped public camp objectives and document how to reproduce the measurements.
#### Scenario: Compare quantity, quality and mixed squads
- **WHEN** a planner evaluates the 24-point and 12-unit trial limits
- **THEN** the evidence identifies each owned build, opposing sides, terrain, commands, capture result and survivor counts, and distinguishes measured tactical outcomes from player-experience assumptions.
