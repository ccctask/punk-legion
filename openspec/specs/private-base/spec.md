# private-base Specification

## Purpose
为每个玩家保存独立经营的私人领地，支持建造和移动设施、检查道路与供能。服务器按版本记录布局与资源费用，袭击使用冻结时的位置，编辑可留给下一次防守。

## Requirements

### Requirement: Persistent private buildable territory
The server SHALL maintain a separate private grid for each account and validate placement, movement, necessary access paths and power connections.
#### Scenario: Build and reopen
- **WHEN** an owner places or moves a core, producer, warehouse, workshop, repair facility or fixed turret and signs in again
- **THEN** the saved buildings, footprints, roads and power state match the accepted layout.
#### Scenario: Invalid or conflicting change
- **WHEN** a change overlaps a building, crosses the grid boundary, seals necessary access or is stale
- **THEN** the owner sees a reason and the last accepted layout and costs are retained.
#### Scenario: Frozen defense layout
- **WHEN** defense captures a layout revision and the owner changes their base afterwards
- **THEN** the captured buildings and positions remain fixed for that defense while subsequent snapshots see the new revision.

### Requirement: 基地中的机器人军营与机库
系统 SHALL 允许玩家在私人基地实际建造可交互的军营机库，通过设施管理本人机器人和按方案制造实体，复用账号统一库存及机库容量。
#### Scenario: 建造后进入机库
- **WHEN** 玩家在合法相邻道路地块确认建造军营，重进基地后点选该设施
- **THEN** 原位军营可打开自有机库，显示机体状态，可切换已有制造界面按一份合法方案消耗材料，新机体拥有唯一身份。
#### Scenario: 旧账号与好友
- **WHEN** 玩家尚未建设军营、反复建造军营或好友从参观入口查看军营
- **THEN** 旧机库容量与已拥有资产保持，重复建楼不产生额外实体或容量，访客只能查看布局。

### Requirement: Readable private-base construction controls
The private base SHALL keep instructions, placement results and confirmation controls readable and reachable in the supported landscape viewport.

#### Scenario: Follow the build instruction
- **WHEN** the player opens the private base at 960×540 or 640×360 and selects a facility to build
- **THEN** the player can read the complete instruction, preview a tile and reach confirmation by vertical scrolling.

#### Scenario: Recover from rejected placement
- **WHEN** the player selects an invalid tile and then a valid one
- **THEN** the rejection reason is legible and a successful confirmation creates one facility and charges its cost once.

### Requirement: 首次探索胜利扩建私人基地
系统 SHALL 在玩家首次亲自打通锈轨回收场后免费开放一片相邻地块，保留既有基地布局和资产。

#### Scenario: 个人或队伍首次通关
- **WHEN** 权威房间确认玩家作为实际参战者胜利完成锈轨回收场
- **THEN** 该玩家回到基地即获得可铺路、可建造的新地，库存无扩建扣费

#### Scenario: 旧档及重投
- **WHEN** 有可核实胜利记录的老玩家重登，或同一胜利被反复投递
- **THEN** 相同新地仅解锁一次且原设施、道路、机体保留

#### Scenario: 尚未通关
- **WHEN** 玩家尚无符合条件的胜利或只进行了派遣
- **THEN** 基地展示解锁条件且服务端拒绝新区域建造

### Requirement: Plan a powered base across expanded land
The base SHALL compute supply coverage from the core and enabled relays within six Manhattan cells of the core footprint. Each connected relay SHALL extend coverage by six cells, without increasing the six-point supply budget or enabling other relays. Clients SHALL preview coverage and changes in operating state before accepting a layout edit.

#### Scenario: Establish an eastern production line
- **WHEN** an owner places a foundry beyond core coverage, then builds a reachable relay covering its nearest tile
- **THEN** the first preview explains why it will be offline and the committed relay starts production if capacity remains.

#### Scenario: Move or pause a relay
- **WHEN** the player previews and confirms a change to a core or relay
- **THEN** affected buildings are identified before spending, and subsequent production, repair capacity and raid defense use the confirmed operating state according to their existing timing and snapshot rules.

#### Scenario: Reach differs from budget
- **WHEN** relays overlap, a second relay lies only in another relay's area, or demand exceeds capacity
- **THEN** only directly linked relays extend coverage, total supply stays six, and the player can distinguish distance, manual pause and insufficient capacity.

### Requirement: Reconcile uncertain private base saves
The client SHALL query the signed-in owner's edit receipt and latest layout after an ambiguous save response while the editor is open. Reconciliation SHALL use only reads and SHALL distinguish a confirmed commit from another player's session changing the same owner's layout.

#### Scenario: A committed reply is lost
- **WHEN** a save commits but its reply is lost and a second window subsequently edits the base
- **THEN** the editor identifies its own committed revision and renders the latest layout without automatically submitting another edit or charging for it again.

#### Scenario: The original request did not arrive
- **WHEN** the receipt is absent and the original revision is still current
- **THEN** the player can retry the original operation with the same key and payload, while a changed revision instead requires a new preview.

#### Scenario: Confirmation cannot be read
- **WHEN** a read fails or the player leaves the page
- **THEN** the editor offers a read-only retry while open and stops scheduled checks after exit.

### Requirement: Southern factory land
A personal first factory escort completion SHALL permanently open two adjacent buildable rows south of the expanded home and preserve all previous placements.

#### Scenario: Build on recovered factory land
- **WHEN** a qualified owner returns, connects a road and places a powered production building on the new land
- **THEN** the ordinary build and production rules apply across the new border, the layout survives login, and another win grants no more cells.
