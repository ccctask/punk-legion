# cooperative-ruins Specification

## Purpose
定义限时世界遗迹的准入与合作目标、逐人撤离、真实战报及按日有限的个人材料收益，让玩家可独自或与好友完成一次不会转入 PvP 的探索。

## Requirements

### Requirement: 服务端限时的独立合作遗迹
世界地图 SHALL 向所有玩家展示同窗同位置的不可占领 PvE 遗迹，允许 1 至 3 名玩家进入自己的实例。
#### Scenario: 活动跨窗
- **WHEN** 玩家在窗口关闭前后尝试开始新场
- **THEN** 开放期成功出发的实例可继续，关闭后停止新场并公布下次开放时间。

### Requirement: 双阀校准与撤离
已到场玩家 SHALL 可用自有机体清理两处守卫、分别校准、获取物资并撤离。
#### Scenario: 单人和队友配合
- **WHEN** 单人依次处理两处装置，或两名玩家分头处理
- **THEN** 权威服务器按相同目标顺序开放箱与出口，准确结算各人结果，缺席者保持零参战。
#### Scenario: 队友先后撤离
- **WHEN** 一名队员开启公用物资箱并抵达出口，另一名已参战队员仍在远处
- **THEN** 先到者确认个人胜利，另一位继续操作直至亲自撤离、全灭、撤退或超时，结算与发奖按个人结果执行。

### Requirement: 有限的个人遗迹收益
档案 SHALL 按实际胜利与该场次所属 UTC 日限制个人材料奖励。
#### Scenario: 首胜和随后的协助
- **WHEN** 玩家当日首先获胜并再次协助好友获胜
- **THEN** 第一场至多入库两份通用零件，随后同日不额外发放；两场真实参战均可在机体历史查询，锈轨专属进度保持原值。

### Requirement: 泵房固定地标采用可编辑的 Godot 场景组合
泵房客户端 SHALL 在 Godot 场景层级中定义两阀、箱与出口的固定节点并使其与服务端交互位置相符。
#### Scenario: 载入泵房
- **WHEN** 编辑或运行泵房战场
- **THEN** 可在场景结构定位四个有名地标，运行时各自绑定对应外观、交互位置及状态。

### Requirement: 合作泵房的满编移动端取样
容量验收 SHALL 核实真实房间内各方部署、安卓实际呈现及输入，不把单人轻编队样本泛化到三人满编。
#### Scenario: 三席全员满编
- **WHEN** 三位玩家分别派出 6 台轻机，房间依到场规模生成 6 名守卫
- **THEN** 验收记录安卓端操作、样本时间、实际存活数、可见范围和稳定性指标或其不可测原因。

### Requirement: 泵房密集交火时按小队选择显示身份
客户端 SHALL 在泵房保留可辨认的阵容、地标与指挥入口，按玩家选择显示身份。
#### Scenario: 多台机体聚集在西阀
- **WHEN** 玩家选中多台聚集的机体
- **THEN** 可见选中数量和选中标识，机体头顶不堆叠一组名称。
#### Scenario: 玩家单选并切回全队
- **WHEN** 玩家只选中一台自己的存活机体，随后切回全队或该机体退场
- **THEN** 单选可辨认该机名称，选中状态改变后移除过期身份显示，原有战斗指令继续可用。

### Requirement: 泵房个人首通回收维修部件
首次亲自成功撤离雾钟泵房的玩家 SHALL 获得一件可装入机体功能槽的维修臂，按账号保存回收状态，并在战果和常驻机库给出实际结果。

#### Scenario: 首胜回营装配
- **WHEN** 玩家首次参与泵房并成功撤离且有部件仓位
- **THEN** 私人背包增加一件带独立编号的维修臂，战报说明获得情况，玩家可将该实体装机

#### Scenario: 满仓保留回收物
- **WHEN** 首胜时仓满，之后腾出仓位并在私人基地机库领取
- **THEN** 领取在活动关闭后仍可进行，重复点击或重试至多获得一件

#### Scenario: 合作个人归属
- **WHEN** 两人结算结果不同或重投旧结算
- **THEN** 只向本人实际参战并成功撤离的席位发首胜奖励，单人、合作与不同日期共享一次资格

### Requirement: 泵房首通战报标明功能槽
泵房首通实物已入包的个人战报 SHALL 写明「可装入 AUX 功能槽」，首通部件编号可辨认。
#### Scenario: 回看首次撤离结果
- **WHEN** 玩家打开已直接入包的首次成功撤离战报
- **THEN** 战报展示维修臂编号及与准备页一致的功能槽用语

### Requirement: Readable recovered item ID on pump preparation
The pump preparation page SHALL render the recovered repair arm identity as a readable equipment label on Android.
#### Scenario: Returning after recovery
- **WHEN** the player revisits a pump outing after receiving their first clear part
- **THEN** the status identifies the same short part ID as the receipt and renders cleanly through its final character.
