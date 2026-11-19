# Design

## Context

本文件是C预评审草案，**B独立出口未签前不得实现**。主责M04，关联M14/M05/M06；B的Sim/Fighter仍是权威运动所有者，Field仅供几何，Mission及Solo工厂持配置与严格检查点。A显示缓存不影响服务器规则。

后续当前状态（2026-11-18）：[B独立出口](../m04-authoritative-safe-turning/verification/root-b-exit-review.md)已签。以下历史候选保留为决策来源，实际实现以本文末尾root签定的具体合同为准。

## Goals / Non-Goals

只加轻微起停/转弯重量感，仍沿B已证明的路径逐段推进，不引车辆漂移、轮胎物理或客户端假滑行；不把加减速塞进Unit/Autoload。保持新指令响应、动态裁剪、精确射程、盾转向/减伤、0.5sim重规划与其它消费者off。

## Decisions（待B出口后由root逐项签定）

候选为Fighter独立的当前行进速度及最后行进方向，明确与瞄准/盾last_heading分离；速度只影响原_walk的距离预算，所有段仍严格静态query+safe_fraction，不增加绕开路径的第二位置写入者。短时加速、制动距离和曲率限速在Sim规则内，几何曲率数据复用B路径，不由Field拥有速度策略。新指令先整组规划，成功后才更新速度/方向意图；反向不继承逆向余速，阻挡/死亡/终局清零。实例配置在创建期注入，无运行中热切换。

待锁参数候选：达到底盘最大速度约0.25秒，正常制动约0.20秒，急弯以安全路径曲率主动限速。它们是计划值不是已通过参数；root需在C实现前结合B实际路线与测试反馈定明确公式和数值，禁止观察结果追绿调参。精确到达要用剩余路径长度的制动上限，不能靠扩大到达判定；大delta分段处理有界，碰撞立即取消不安全余速。

新增决定字段与策略版本必须在Mission严格checkpoint中一并校验：当前新版本生成后相同输入/delta恢复等值；非有限/负/超上限速度、非法方向/不匹配策略/缺字段拒绝，不补零适配B或旧版记录。Solo工厂须开启最终标准实例策略，Party等依旧不注入。新增源范围预期只在Sim/SoloMission/Solo的现B入口及authority_motion既有测试文件，Field若需新几何函数另核具体职责。

参考Godot4.6 [Vector2](https://docs.godotengine.org/en/4.6/classes/class_vector2.html)的有界move_toward/rotate_toward；已发行开源游戏[Mindustry UnitType](https://github.com/Anuken/Mindustry/blob/master/core/src/mindustry/type/UnitType.java)将移动速度、加速度/阻力和旋转速率作为分离参数。本项目只复用参数职责分离与响应取舍，不搬其逐帧单位/数值或另一物理引擎。这些是技术/体验参考，项目精确公式仍以C root签为准。

## 验收与工具

沿B真实GUT独占组补起步、制动、转弯、短指令/反向、阻挡/死亡/终局、盾/钻头、完整同版恢复与非法字段。B/C最终源一次自然20Hz ENet+真实渲染验证，复用A原路线/原Owner及只读采样，必要观察速度/路径实际扫段先签工具增量；不可用A的显示CV冒惯性正确性。测试全部本轮新场，保首错/真实源/参数与资源终态。

## Risks / Trade-offs

路径变化和加减速会合理改变接敌时间，应报告而不偷偷放宽射程；短路径不能进入无限低速爬行。用速度标量沿安全路径而非漂移可保持可控，反向/阻挡的紧急清速规则需显式签定。屏幕逐帧/Android性能不由数学插值通过推定。

## 发布安排

无迁移。C通过后与A/B一起冻结新客户端和服务器，新卷/新账号。当前不派任何C代码，B结果到位后root补充具体实现落位清单、完整生命周期/失败及通过签字。

## C实现架构评审与落位（2026-11-18 root通过）

已独立核[具体API/解析公式与实际调用](preflight.md)、B最终源与出口，锁以下合同，准派源码实现；本文早先“待B/不派代码”是当时草案状态。本签不授权引擎/服务/发行运行。

| 当前职责/不负责 | 实际文件/为何同处或分离 | 状态与生命周期/依赖 |
|---|---|---|
| 纯路径限速剖面和单弦解析积分，不持单位/地图/位置 | 新`game/battle/path_motion.gd`，RefCounted静态值函数；数学不变量/求根与战斗决策变化原因分离，有当前隔离和独立验证价值，不是按行数拆或猜共享 | profile/advance_segment只接独立数值/路径返回独立值，无实例状态/Node/Timer/会话。Sim显式组合，不依赖Field或上层 |
| 行进速度/方向、原子换令、唯一权威位置推进与安全 | `game/battle/simulation.gd`，原Fighter和_walk/step/command_move/_install_walk_path/_hit/_finish持这些规则，数学委托helper，场次/经济不进入此层 | 只增travel_speed float与travel_direction Vector2两决定字段；默认C off。create零、运行_walk局部remaining_time，重装路径/新令成功后投影，blocked/idle/死亡/终局清零，销毁随Sim |
| 当前版本配置/决定状态严格恢复和真实终局清理 | `game/net/solo_mission.gd`，原场次拥有checkpoint及outcome，全部现有直接写终局必须由该owner收口 | create/restore前configure_light_inertia，仅标准实例有C且须B已开。outcome受限setter赋非空时委托Sim.stop_motion_all（C off无业务写入），覆盖order/step/Solo过期/磁盘终局。checkpoint只读，恢复先全行校验再应用，不能setter洗脏字段 |
| 标准工厂启用最终策略，其他实例不注入 | `game/net/solo.gd`既有新建/_load同一工厂 | 标准缺location或rustrail启B+C；Armory/Party/未知及其它消费者仍off，原提交成功后ACK/发布保持 |
| 补齐真实服务依赖 | `Dockerfile`仅原battle COPY行增加path_motion.gd | 规则服务器也预加载Sim，必须显式COPY。发行映像映射随实际依赖41→42，当前不构建/部署 |
| 数学/状态与现规则组合回归、最终自然观察 | `tests/godot/test_authority_motion.gd`、`tests/godot/run.py`仅EXPECTED/必要实际闭包；A工具`openspec/changes/m04-smooth-robot-motion/verification/testing/motion_solo.gd`仅_poses只读新增travel字段/启用策略 | 复用真实生产helper/Sim/Mission、既有GUT/Owner。默认组/HTTP/物理/路线不改；自然wrapper每方法一次super，不加生产trace或资源Owner |

Field/B几何、Unit/A显示、Catalog及经济/协议禁止附带修改。需要额外状态、全局Map、第二推进器、缓存或跨模块依赖先回root复审。已核Sim.step所有实际调用链每unit一次_walk：_separate后continue，_approach后return，其余互斥；因此不造每单位时间Map，只在_walk初始化一次remaining_time=delta，内部replan不能重复积分原delta。B query/扫段生命周期不变。

### 锁定公式与有界数值

固定a=V/0.25、b=V/0.20，V取该机当前原stats.move_speed；omega=TAU仅行进曲率参考，不是攻击/盾统一角速。采用preflight明确的后向q上限与单弦至多三相解析积分，不用sqrt目标速度的Euler爬行：D=v*t+.5*r*t²，速度v+r*t，到速度界/开始制动/下一waypoint/余时取最早事件，稳定求根按preflight，有限舍入epsilon不放宽半径/射程/到达判定。单弦返回valid/time/distance/speed/reached，Sim只扣一次实际time并在到点时精确放waypoint。非法数值拒绝/安全停，不修脏状态。

profile接当前位置+未消费独立路径、incoming实际行进方向；终点q=0，非零弦转角theta，ell=clamp((Lin+Lout)/2,.0001,.60)，corner=min(V,TAU/(theta/ell))，共线为V。短弦≤.12的巡航上限取相邻正corner上限，长直弦仍V；倒序q_i=min(corner_i,M_i,sqrt(q_next²+2*b*L_i))。孤立终点/硬折返的零节点限速只要求顶点停，不得把整条非零弦M设零而冻结；近180度硬折返须顶点归零后再起步。零长段沿原waypoint消费门处理，数学输入≤1024，非有限/无效V/a/b拒绝。

局部事件总封顶6*1024+8，涵盖原路径及原最多一次重新安装，不按巨大delta无限切微帧；触顶异常安全停并保意图。实际每段仍B strict静态/safe_fraction/escape/扫段检查；受阻接受前缀可保，速度/方向/walking同时归零，取消本次余时，可依原门安装下一合法路径待下步，不重花原delta。速度不会驱动离开安全路径漂移。

数学接口细化复审（root通过）：safe_fraction截断时真实时间并非full_time*fraction，不能把求根复制进Sim。准advance_segment额外返回最多三条纯数值phases，helper提供time_for_distance(phases,accepted_distance)反解原预算内接受前缀用时；仍无单位/碰撞/持久状态。非法phases/距离须明确无效（valid/time或负值哨兵并在Sim拒绝），接受距离须在预算内；Sim在提交pos之前核时间有限、非负且≤原time。前缀正确用时给原盾_turn，仍取消本次余时而不重复积分。纯控制覆盖加速/制动前缀，不用比例近似冒真实时间，helper内部三相/上限不变。

剖面几何细化复审（root通过）：不能把当前半弦剩余长度当作原转角几何长度，否则每step限速与途中恢复会随取样点漂移。准profile额外接最多两个原几何前缀点（path[index-2:index]的值副本），仅恢复原当前完整弦长/原起点corner；剩余制动距离仍严格从当前位置算。数学仍全在helper，Sim只传已有path/index派生值，不另存缓存或抄曲率。前缀有限/有界、当前点与原当前弦相容须验证，零长沿原消费门处理。局部profile在路径未变时复用其此次返回的后续各点限速，内部真正重装才重新生成；不因每条小弦重用delta。增加同一原弦不同采样位置的κ/M及后续q一致、剩余距离对应可行起速改变的实际数值反例；v2决定字段不变，无新持久状态。

新移动令原子计划完成后才更新两字段：old_speed*max(0,dot(old_direction,new_first_direction))，并按V/新剖面起速可行界夹紧；反向/直角不继承旧余速。短新目标的即时可行截断明确属于紧急指挥，不冒正常.20秒制动。失败组令两字段也不变；合法focus清旧运动、非法focus不动。到达/真实射程/idle/死亡/终局清两字段为0/ZERO且walking=false。移动_turn传真实已消费时间以保持原盾每秒速率，函数体/攻击_turn和盾减伤不统一或修改。

### 严格当前版本恢复

最终C marker为rail-light-inertia-v2，B-only仍可生成当前v1规则夹具，实际标准工厂只接v2；不做v1升级或默认补字段。C两字段仅启用时写入；缺/类型错/非有限/负/超V/非法方向或与当前路径不相容拒绝，零速方向严格ZERO，死机/终局/不可动机禁止非零。C off记录不得带C决定字段。所有行验证后才应用，终局setter不能洗掉坏档。数学剖面由当前path/index/pos及固定策略重算，非新增需保存的决定缓存。无旧档/库导入、回填或迁移。

### 独立出口与工具门

真实GUT需新增纯数学三相/大delta与分割等值/硬折返/短末段有限到达，Sim宏step路程≤V*delta、接受time总≤delta及真实速度起停/弯道降速，不能用端点弦长代实际路程。验证新令投影、失败原子含两字段、阻挡/idle/死亡/所有终局直接写同次清零、盾原每秒速率、钻头真实射程、加速/转弯/制动三途中同版双实例后续完全等值及坏字段拒绝；B原十例按未变B-only合同保留。

开发先交源/前像/实际API与准确自测计划，root源审后一次自测；test_lead独立GUT后最终一次原四目标自然20Hz ENet/渲染（原170+13=183预算），新源锁重封，不复用A旧源锁或调180ms参数。server_poses只读两决定字段/启用与policy，原before/after/path/index可核宏步；有重规划无法唯一还原段时明确缺证据不猜。最终自然门：标准C真启用、起步/制动/弯速可证、路径/扫段严格净空、原权限/ACK、显示首可见≤400ms且停止尾随≤400ms、原十周期/计时复审50ms连续性同口径保留；400ms来自150ms发布+180ms缓冲+一个50ms模拟步及采样裕量，新增物理加速另列不伪作零延迟。真实宏步转向与成本保原数据，不宣称全局角速/FPS/Android。产品源/工具/API越出本表先复审，未过C不冻结最终包。
