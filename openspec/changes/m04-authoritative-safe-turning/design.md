# Design

## Context

主责M04、关联M14/M05/M06；动机见proposal。root已核Sim.command_move→_plan_group_move整组计划后提交，以及自动_walk_region→_install_walk_path→_walk；Field.walk_region用排除形状桶和四邻域树，实际移动复用safe_fraction/动态身体/本步已接受扫段，重规划为0.5sim错峰。SoloMission持checkpoint；Solo新建/_load选择真实Mission或Armory，Party复用父Mission.create。标准NPC原中心格可能仅留.5净空而半径.6。客户端A显示组件已签，不能用它替代本轮权威修正。

## Goals / Non-Goals

只让标准rustrail Solo的权威路径有完整半径净空和可证明安全的圆角，保持最终目标/动态避碰/指令提交。同源几何供规则与已签显示guard使用。B不加速度、不改射程/盾伤/经济/预算/时限，不把Party或其它地图默默启用，不升级引擎或引入NavMesh、车辆物理、全局管理器；C及安卓发布各自下一门。

## Decisions — 具体架构评审（root，2026-11-18通过，准许派实现）

| 本次职责与不负责的职责 | 文件/入口与放置依据 | 状态/生命周期与依赖 |
|---|---|---|
| 同源静态矩形、全半径排除形状与有界路径几何；不写Fighter/指令 | `game/battle/field.gd`，复用已有segment距离/净空helper与walk_region空间桶，避免每BFS边逐矩形扫描 | Field构造持不可变矩形副本；按实半径生成只读几何，地图销毁释放。圆角只在路径安装时处理，不每帧重规划 |
| 标准配置下的路径安装与实际推进；不识别HTTP/页面/结算 | `game/battle/simulation.gd`，原子command_move和自动_install_walk_path必须在原所有者合成；_walk保动态safe_fraction和escape/扫段 | Sim持显式默认关闭配置；Fighter仍持path/route_index/goals，新增几何配置不作为可变全局。每步推进在原Sim.step；无路拒绝或停步，失败组计划不部分提交 |
| 标准地图新建出生点和当前版本策略/路径checkpoint；不决定其它模式启用 | `game/net/solo_mission.gd`，场次拥有部署、Sim与磁盘值合同 | create/restore前显式配置。新建NPC优先保合法原点，不合法时确定性选最近完整半径合法点；只处理本轮新场，不在restore移动位置。策略marker启用时必须严格匹配，全部行验证后再应用 |
| 只有真实标准Mission工厂启用，复连沿同版合同 | `game/net/solo.gd`新建及_load两个实际工厂 | 依据当前工厂类型选择，不依赖deployment缺失的location；Armory与Party等不注入。复用原_commit成功后ACK/发布，失败/未知结果/终局合同不变 |
| 有界规则/当前版本恢复回归；不造第二套规则或资源所有者 | `tests/godot/test_authority_motion.gd`及`tests/godot/run.py`独占authority_motion组 | 复用GUT9.6.1与原Owner、真实生产类和五Autoload闭包；默认旧组不收新组，normal不启HTTP，原90+60+30预算预留Owner尾 |

配置可在新建/恢复前注入，场次运行中不切换地图策略；Sim.create重置本轮实例状态，再由Mission提供本场配置。纯几何处理输出独立PackedVector2Array，输入不回写；无事件总线/Repository/常驻Timer。共享Field增加几何方法因为已有同源地图与距离语义，Sim保规则及事务，两者不能因方便互相持有会话对象。

几何方案：静态矩形边界与外框的完整半径排除形状加入原规划exclusions，复用桶；静态capsule输入radius+2*GEOMETRY_EPS补偿原查询会减EPS，实际步仍用已有严格静态query，不能缩半径。先仅去同向且替代段合法的共线点；有空间的角用trim≤0.60m且≤相邻边45%的二次Bezier采样，按2/4/8/16段渐进检查，每角最多16段、弦长≤.12m、相邻及接入/接出非零弦角差≤15度，总1024点。实际消费的是逐段已证明净空的折线，不宣称数学连续曲率或固定车转弯半径。先证原路径及region.exclusions再加工；非法角保原已安全折线，超输出上限整体保原安全路径，连原路径超上限或非法时拒绝，不截断目标、不退非法中心线。实际动态身体与扫段仍按原safe_fraction裁剪，不把静态证明当动态保证。原有出生身体重叠只沿既有escape改善合同，不新增穿入。

checkpoint启用策略固定`rail-safe-turn-v1`，在新场写入；标准工厂恢复时缺/异策略拒绝，不补旧值、不迁移。配置关闭的其它模式沿其原格式；携带不相符启用标记要拒绝，不能误用。新增圆角路径仍由原path/index保存，恢复检查所有点/未消费段全半径净空及索引/最终目标一致性，状态不合法整场拒绝。无需每帧新状态或公共抽象。

root已独立核[具体调用/API勘查](../m04-smooth-robot-motion/research/b-safe-turn-preflight.md)与[测试预审](../m04-smooth-robot-motion/verification/bc-android-test-preflight.md)，签上述四生产文件及两必要测试文件的实现。Field接口采用static_capsule_exclusions/map_segment_clear/nearest_body_cell/rounded_path及只被后者调用的局部纯几何子函数；不增加公共导航框架。Sim默认off，Mission.configure_safe_turning在create/restore前配置；Solo两个工厂显式选择，未知显式location不启新策略。严格恢复验证应在应用saved字段前完成；恢复失败不修复或发布。不得修改其它消费者脚本或自动扩大默认启用。如实际需要跨出清单/改提交、协议、半径或0.5sim门，先回root复审。

测试新增独占authority_motion组，默认其它组排除、不起HTTP；实际用例数按真实方法锁定，复用原Owner/GUT闭包；closure函数原文本/AST保持，原预算内预留13秒Owner尾/准备末20秒inventory。开发完成先交前像/差异/来源与准确新run计划，root源审后才运行自测；正式测试另由test_lead执行。此评审准源码实现，不是准部署、改旧卷或运行无锁的新工具。

## 验收与失败

开发自测与test_lead独立规则测试分列：空旷90度和连续转弯含≥3个转向步、选定长边90度样例相邻方向变化<60度；每实际静态/动态扫段合法，窄道/门柱/贴边无法曲线时不缩半径；正常目标/4m采集/钻头真实射程保留，失败组指令不部分写入。四底盘/新NPC出生、实例隔离/非标准消费者off、0.5sim规划预算、12台拥堵及同版途中checkpoint继续等值；缺/非法字段/策略/几何拒绝，夹具均为本轮新数据。旧完整路径字节等值不用于新路径。

B不改网络格式，先以真实Godot规则/场次完成独立门，B/C合并后的自然ENet及Android放在C/发行各门，不机械重复两套相同自然路线。测试不得以合成delta证明FPS；报告实际耗时和查询数，不推性能收益。新工具源码先源审再运行；独立正式执行前提供实际源/argv/预算/资源Owner，失败保首错不原地重试，清本轮Job/端口。其它模式仅复用未变依赖证据并覆盖显式关闭，不重跑旧迁移/经济整矩阵。

## Risks / Trade-offs

全半径会选择更离墙路线，路程/接敌时间可合理变化；目标/射程不能放宽。新NPC出生位可近邻变化，必须保持地图阶段与可交互性。样条采样不是动态碰撞证明，逐步safe_fraction必须保留。圆角与额外形状的成本须实测，不能无限采样/查询。服务发布另用独立新卷/账号，不能把新策略套用户旧R2场次；旧试玩归属不明不停止。

## 发布安排

无数据迁移；本轮新场和当前版本严格恢复。C依本轮通过后另签，安卓及对应服务使用最终共同冻结源。是否替换现有试玩服务、保留手机旧包入口按实际活动与稳定操作台账核定，不凭版本旧批量删除。
