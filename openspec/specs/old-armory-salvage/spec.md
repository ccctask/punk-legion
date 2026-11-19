# old-armory-salvage Specification

## Purpose
玩家在开放南地后进入旧武器库，亲自清除守卫、回收武器箱并撤离，在私人机库接收和安装具有唯一编号的烟囱炮臂。机体可借预警落点攻击密集敌队，敌机在命中前移出范围即可躲避。

## Requirements

### Requirement: Personally recover the armory prize
An eligible commander SHALL be able to clear the guards, recover the cache and extract through normal play to obtain one physical chimney launcher.

#### Scenario: First clear with a full parts inventory
- **WHEN** the first successful retrieval settles with no space for its part
- **THEN** the owner can claim that unique prize after freeing capacity, and retries, failed outings and subsequent wins never duplicate it.

#### Scenario: Install a discovered part
- **WHEN** the owner fits the recovered part to a compatible machine
- **THEN** inventory, preview, command points and battlefield equipment reference the same installed item; unrelated expedition progression remains intact.

### Requirement: Telegraph a delayed area hit
The authoritative battle SHALL resolve a visible delayed strike against the enemies at the original marked position and grant each effective contribution once.

#### Scenario: Clustering and dodging
- **WHEN** two enemy machines remain within the marked radius and a third moves clear before resolution
- **THEN** the first two each take one hit, the third avoids it and a reconnect does not alter their outcomes or duplicate credit.
