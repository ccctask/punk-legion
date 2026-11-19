# 私人基地、回收场与公开营地美术

适用于 Godot 4.6.1 与本机 Blender 5.0 资产库。冻结版本生效；建模维护者维护可编辑源件与发布配方，游戏美术维护者核对版本、运行时组合和移动端表现。

| 用途 | 冻结资源 | 游戏消费 |
|---|---|---|
| 履带基础机体 | PL_SteamCrawler r07-mobile-optimized，runtime_lod1 | [机器人场景](../game/assets/steam_crawler/robot.tscn)直接引用现成低面GLB；当前1075已使用，默认双目＋气炮7,000三角，完整换装8,564三角，四动作与接口保留 |
| 玩家可更换双足底盘 | PL_SteamBiped r11-mobile-reviewed，LOD1 | [游戏装配与真实挂点](../game/assets/steam_biped/assembly.gd)，四动作及步态音效随底盘选择 |
| 基地地块、装配车间、固定炮塔 | 已发布的 PL_MeadowYard、PL_BrassWorkshop、PL_PuffSentry | 保留地块、炮塔轴向和原部件动画 |
| 私人防御平台 | 原有 PL_PuffSentry 固定底座、PL_HeavyEscortKit 的 MedicRig | 空台隐藏炮身，已装气炮保留真实炮口，维修型显示吊臂和青绿维修束 |
| 军营机库 | 复用已冻结的 PL_BrassWorkshop 与 PL_SteamCrawler，带停驻履带机的两格机棚 | [军营组合](../game/assets/base_art/hangar.tscn)，复用游戏已导入资源 |
| 核心、冶炼、仓库、修理 | PL_ArcDynamo、PL_CoalFoundry、PL_BinDepot、PL_HookGantry，均为 r01-yard | [设施场景](../game/base/building.tscn)，按服务端 2×2、2×2、2×1、1×2 占地定位。停电标签沿用权威布局状态 |
| 地面轨道、料斗掩体、废轨矿车、储能井、铜线圈、出口、巡查信号与熔炉入口 | PL_RailSalvageKit，r01-yard | [回收场组合](../game/assets/salvage/yard.tscn)引用独立网格和已有权威位置，轨道与分段掩体按实例批绘 |
| 秘宝争夺的双侧撤离门与五段轨道 | PL_RailSalvageKit 的 Exit、Track，共用原珐琅材质 | [秘宝场景](../game/treasure/treasure.tscn)的 Landmarks 下可选择每座门、门牌与轨道；Objects 由权威物资快照驱动 |
| 泵站双阀、共享物资箱、个人出口 | PL_RailSalvageKit 的 Fuel、Coil、Scrap 和 Exit | [泵站场景](../game/pump/outing.tscn)组合储能井与线圈作为阀体，场景状态跟随权威双阀、开箱及个人撤离进度 |
| 巡查甲、双罐维修吊臂、双烟囱首领 | PL_HeavyEscortKit，r01-yard；底盘沿用 PL_SteamCrawler 既有四段动画与装备 | [敌方挂件](../game/assets/salvage/kit.gd)跟随机体朝向，阵营圈、血条和攻击射线由原战斗视图管理 |

建模时先检索网页、核对真实冻结版本和预算。PL_SteamBiped 的现有双足动作与本场履带地形动画不同；该场使用已验证的履带底盘，配合三套独立工装。现有森林与沙漠源件可校对植物配色和风格；已建成的 PL_MeadowYard 保留此前从冻结森林提取的草丛。工业地面使用少量固定轨枕和弯叶，保持主路径与采集指令可见。

2026-11-11按负责人提醒核对既有低面履带资产：工作树与1075冻结的`game/assets/steam_crawler/model.glb`均为883,204字节、SHA256 `813c3b377b7e379125ad29fe0c5675c9a22e1131588b05b7a54495ac00283b31`，与模型库r07的`robot-runtime-lod1.glb`相同。它是全距离基础模型，不是仅远处换用；Godot可在其上再选导入器生成的索引LOD。此前1036试验调整的是此低面模型上的`lod_bias`，不能解释成低面版未接入。源GLB默认7,000三角/31个primitive，相同系列运行时标准版为25,156三角；不能据源几何数推断每帧实际提交数或30FPS达标。发布端`game_ready=false`仍保留，实体设备/最终性能尚未齐备。[可重算核查](../openspec/changes/m06-device-battle-baseline/verification/current-crawler-asset.py) · [当前资产证据](../openspec/changes/m06-device-battle-baseline/verification/current-crawler-asset.json)

同日1075正常UI三席短基线保持此模型：两场18友机＋6守卫的保守交火支持4.38/4.08秒，P95为34.13/41.18ms，未达到33.333ms预算，不代表整场/真机通过。没有模型前后A/B，不能据与旧轮次差异宣称几何优化收益。[基线主验与收尾](../openspec/changes/archive/2026-11-11-m06-current-pump-frame-baseline/verification/root-review.md)

六套新增可编辑源件分别位于同级 Blender 工程 `assets/buildings/资产ID/` 或 `assets/scenes/资产ID/`，各目录下含同名 .blend 和 publish.json。[建模配方](../../blender/朋克军团/scripts/playable_zone/build.py)使用项目资产模板，并按回收场模块保留独立根节点。每件设施导出一个材质面段；关卡套件八个面段，工装套件三个面段，均共用一份顶点色材质。按[模型库发布规范](../../blender/朋克军团/docs/本地模型发布规范.md)更新时，使用新的 release 标识。

在桌面运行 Godot `--path game res://expedition/tests/zone_art_bench.tscn`。同一脚本展示六种建筑、断电标签及三友三敌的首领镜头，预热 24 个绘制帧后采样 150 帧，写出首帧、帧间隔、绘制调用、可视几何与内存。Android 使用同一诊断场景的独立调试包，普通游玩按[组队入口](party-expedition.md)或[单人入口](solo-expedition.md)进入。

[移动端首领点选、对照测试与限制](../openspec/changes/archive/2026-11-08-m02-playable-zone-art/verification/report.md)


## 黄铜转运场与线圈港

两处公开营地沿用已有 r01-yard 冻结模型。黄铜转运场以货车、堆料仓和吊臂形成装载线；线圈港使用成对绕线架和检修信号，侧面留出与可行走战区分离的放线工位。场内四处设备仅占原权威阻挡，中心圈、出击区与行走路线沿用原战斗规则。地图指挥台和实战实例引用同一布景。[黄铜转运场](../game/camp/brass_yard.tscn) · [线圈港](../game/camp/coil_quay.tscn)

游戏复用 PL_RailSalvageKit 的 Scrap、Cover、Track、Coil、Signal；黄铜场另用 PL_HookGantry 和 PL_BinDepot。三个 GLB 的来源和版本由资产库 release 清单维护。两处地坪使用普通地面顶面的 Godot 材质绘制平轨、装载标线或电缆沟纹样。修改可视器材摆放时，以各处 Godot 场景指定的位置、朝向和尺寸为准，并复核与战区的边界。

Blender 5.0 布局工程包含两个可编辑场景、冻结组件与参考相机。使用 `blender -b --factory-startup --python <layout.py> -- <游戏仓库根目录> <输出.blend>` 可从游戏内冻结的 GLB 与场景摆位重新生成。地坪材质、HUD、占点环和在线单位在 Godot 中检验。[组合工程](../../blender/朋克军团/reports/public_camp/PublicCampLayouts.blend) · [重建脚本](../../blender/朋克军团/scripts/public_camp/layout.py)
## 秘宝场地的识别地标

战斗以权威房间的地点 ID 实例化对应 PackedScene。铜管洼地两岸是带薄荷绿手轮、压力表和回水弯头的双联泵；旧吊车台用检修吊臂、钢材仓和黄线泊位；雾钟岔道用悬锤道钟与岔轨。三处都保留原有中央五件物资、两侧撤离门和可走地面。固定地标设在横向指令边界以外。切角底座与工区地坪是场景本身的编辑节点；地坪纹样在固定正交镜头下展示，哑光平印材质不接动态投影。场内机体与旧料件仍使用原有游戏材质。[铜管洼地](../game/treasure/sites/copper_lowland.tscn) · [旧吊车台](../game/treasure/sites/old_crane_yard.tscn) · [雾钟岔道](../game/treasure/sites/fogbell_junction.tscn)

PL_TreasureWaysideKit r01-wayside 是两种设施合用的 Blender 源件；发布 GLB 含两个独立面段，复用珐琅顶点色。吊车台沿用 PL_HookGantry、PL_BinDepot；轨道与门来自 PL_RailSalvageKit。修改泵组或雾钟模型时先开源工程并依规范发布新版本，改摆放时编辑相应游戏场景。布景分别使用 Godot 的模板地台与平面贴图，模型的正版来源及当前版本由网页清单维护。[可编辑模型](../../blender/朋克军团/assets/scenes/PL_TreasureWaysideKit/PL_TreasureWaysideKit.blend) · [冻结版本](http://127.0.0.1:5180/api/v1/assets/PL_TreasureWaysideKit/releases/r01-wayside/manifest)
