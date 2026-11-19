# 模块职责与依赖边界

状态：生效的评审定位依据；2026-11-14；维护：主代理。编号/原名来自[研发路线图](https://chatgpt.com/space/page_4a8d0df5d3f481919df4dc6f25058920)seq61，由进度代理实际回读。当前入口来自[静态审计](architecture-audit-2026-11-13.md)，不是全量实现清单或全部合规证明。按[架构评审流程](architecture-review.md)核本次真实调用者、继承与状态写入；整改状态见[台账](architecture-remediation.md)。

## 职责定位

同文件可能承担多个模块的旧职责，以下路径只用于定位；不能仅依目录或编号判断影响面。领域边界是目标约束，现有偏差在审计/具体评审登记，不由本表自动修复。M05的正式标题是权威房间，兵力预算对照只是其相关验证内容。

| 模块（原名） | 当前代表入口 | 拥有的合同及跨界约束 |
|---|---|---|
| M00 工程盘点与技术基线 | [工程规格](../openspec/specs/engineering-baseline/spec.md)、[协作规则](../AGENTS.md) | 工程/评审/交接合同；不代替各业务状态权威 |
| M01 Godot工程骨架与最小构建 | [project](../game/project.godot)、[endpoints](../game/client/endpoints.gd) | 工程入口、配置、组合根；不把领域规则塞进启动器 |
| M02 Blender到Godot资产样板 | [履带宿主](../game/assets/steam_crawler/robot.gd)、[双足装配](../game/assets/steam_biped/assembly.gd) | 模型消费、模块包装/挂点；视觉子节点名不作为跨模块业务API |
| M03 模块数据与装配合法性 | [rules](../game/loadout/rules.gd)、[catalog](../game/loadout/catalog.gd)、[workshop](../services/profile/workshop.py)、[实际目录校验](../tests/godot/catalog_contract/README.md) | M03持目录语义/版本与可比装配合同；两现有表示由实际运行时校验保护，M09持真实实体/占用和事务。[目录/四例根签](../openspec/changes/archive/2026-11-14-m03-catalog-contract-check/verification/root-review.md)不豁免消费者执行差异或代DB权限 |
| M04 单机战斗与小队指挥 | [simulation](../game/battle/simulation.gd)、[unit](../game/battle/unit.gd) | 模拟/指令规则和表现适配；规则不依赖画面，不私自发经济奖励 |
| M05 双客户端与权威战斗房间 | [room](../game/net/room.gd)、[result outbox](../game/net/result_outbox.gd) | 权威席位、指令、快照和结果交付；客户端反馈不能替代持久提交或账本 |
| M06 手机表现与战斗规模验证 | [预算规格](../openspec/specs/device-battle-baseline/spec.md)、[实测索引](testing/runs/README.md) | 按目标平台/场景测量；结构整改不得推定性能收益 |
| M07 账号 机器人身份与持久化 | [account access](../services/profile/account_access.py)、[entry](../game/beta/entry.gd)、[维护应用入口](../services/profile/profile_maintenance.py) | 身份/认证/恢复与持久身份；页面不授予权限。请求维护由应用入口静态编排，server持连接/两个事务，领域持规则；[守恒合同根签](../openspec/changes/archive/2026-11-14-m07-profile-maintenance-boundary/verification/root-review.md)不消除全库扫描或经济环 |
| M08 资源背包与唯一结算 | [inventory](../services/profile/inventory.py) | 库存/收据及唯一业务键；跨域账务由明确用例在同事务编排 |
| M09 装配车间与实体制造 | [workshop UI](../game/owned/workshop.gd)、[workshop服务](../services/profile/workshop.py) | 制造、装卸、部件占用/费用；传输重试不能重新生成同一次写意图 |
| M10 机器人档案 三项服役累计 | [service record](../services/profile/service_record.py)、[profile](../game/profile/profile.gd) | 三累计归属与结算语义；从权威事实计数，不由视图推算奖励或战绩 |
| M11 私人基地网格与建筑 | [private base](../services/profile/private_base.py)、[base](../game/base/base.gd) | 布局/设施与供能；和生产/维修/袭击交叉写入需显式事务合同 |
| M12 生产 科技与离线收益 | [production](../services/profile/production.py) | 时间推进、仓储/科技影响；必须声明与库存/袭击的顺序，不隐式改其他领域策略 |
| M13 维修 回收与恢复保障 | [recovery](../services/profile/recovery.py)、[repair bay](../game/base/repair_bay.gd) | 机况、维修/回收报价及工位；统一费用/占用由服务入口处理 |
| M14 单人探索与掉落闭环 | [solo](../game/net/solo.gd)、[mission](../game/net/solo_mission.gd)、[expedition服务](../services/profile/expedition.py) | 单人会话/检查点/续接及战果；改变共享父类必须核组队/营地真实继承 |
| M15 组队PVE探索 | [party](../game/net/party.gd)、[party服务](../services/profile/party.py) | 队伍/成员、到场、个人入账；共享solo代码不代表两者提交语义可互换 |
| M16 私人基地野生袭击 | [raids](../services/profile/raids.py)、[raid watch](../game/raids/raid_watch.gd) | 预警/财富预算/防守结果；与生产/修复的时间和账务先后须登记 |
| M17 新手引导与轻度日常 | [onboarding](../services/profile/onboarding.py)、[guide](../game/onboarding/guide.gd)、[entry](../game/beta/entry.gd) | 引导和日常资格消费权威事实；引导页面不自造业务进度 |
| M18 世界地图与服务端开放日程 | [world calendar](../services/profile/world_calendar.py)、[world](../game/world/world.gd) | UTC日程/地点/准入；客户端展示不裁定开放与归属 |
| M19 实时营地攻防与归属转移 | [camp服务](../services/profile/camp.py)、[camp网络](../game/net/camp.gd) | 营地归属、守军及攻防；援军/派遣/生产协调经领域入口 |
| M20 好友 援助与派遣互斥 | [friends服务](../services/profile/friends.py)、[friends视图](../game/friends/friends.gd) | 社交授权/援军归属和占用；不能直接改其他玩法席位/战果 |
| M21 外观 商品与测试支付 | [storefront](../services/profile/storefront.py)、[store](../game/store/store.gd) | 订单、权益、模拟付款；UI确认不等于授予权益，真实支付另有范围 |
| M22 经济回归 可靠性与运营工具 | [operations](../services/profile/operations.py)、[交付维护](current-playable-delivery.md) | 受限运营入口/可靠性证据；运营授权不由客户端或测试工具隐式获得 |
| M23 安卓独立内测与后续渠道接入 | [export presets](../game/export_presets.cfg)、[内测交付](android-private-beta.md) | 构建/包内容/签名、运行来源与平台生命周期；测试包不代替正式发布证明 |
| M24 独立争夺秘宝 | [treasure服务](../services/profile/treasure.py)、[combat](../services/profile/treasure_combat.py)、[treasure视图](../game/treasure/treasure.gd)、[局部意图策略](../game/treasure/lobby_intent.gd) | 页面持视图/请求/生命周期，局部策略只处理传入值/原body；双方确认、战斗/货物仍由服务裁定。客户端不复活过期写；[A05限定签收](../openspec/changes/archive/2026-11-14-m24-lobby-intent-boundary/verification/root-review.md)不代表全项目网络重构或已进1077 |

## 跨层允许关系

页面呈现状态并提交业务意图；用例/会话协调已定义规则与持久化；领域规则裁定自身不变量；传输/文件/数据库适配器提供机制。场景组合上层提供引用并协调兄弟；局部视图不按内部路径取得其他领域写权限。公共定义可供多领域读取，可变状态只能通过其所有者入口修改。

跨领域原子操作允许统一事务编排，但必须列明参与领域、提交点、失败回滚与到期顺序；不能把所有请求的全域推进自动视为正确，也不能在未核语义时删掉它。现有全局网络生命周期、继承和多份规则均按具体评审登记例外及改动约束；新功能不能直接扩大历史耦合。

## 每项评审补充的边界清单

记录调用方→入口→状态所有者→提交/发布方→释放方；标明读是否推进状态、跨域写、消息/文件格式、重试业务号与队伍/会话代次。核继承者、调用`super`路径、信号连接和退出后的回调，不仅搜索同目录。规则相同与有意差异分开；修一个入口后用受影响断言核其调用者，不默认全项目复测。
