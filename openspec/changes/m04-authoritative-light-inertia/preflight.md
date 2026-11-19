# C 只读实现前建议（待 root 具体 AR）

motion_dev，2026-11-18。已核当前 B 源、C proposal/spec/design 草案及 B 出口消息。这里只定数学/生命周期候选，未写代码、测试或启动资源。

## 最小所有者与状态

三既有生产文件：Sim 持路径/运动与指令事务；SoloMission 持实例配置、终局及严格恢复；Solo 两工厂提供最终标准策略。按 root 最新边界，新增 `battle/path_motion.gd` 纯数学依赖隔离剖面与求根，`Dockerfile` 仅 COPY 该依赖；Field/B 几何与 Unit/A 呈现无需改，禁止 C 顺手搬新导航框架。

Fighter 只增加 `travel_speed:float=0` 和 `travel_direction:Vector2=ZERO` 两个决定字段。后者是当前行进速度向量的方向，不是瞄准/盾 `last_heading`；新令成功投影时可改变，实际接受位移后跟随该段切向。停止可清为 ZERO，必须在 AR 固定唯一合同。建议清速统一两者归零及 walking=false，减少恢复歧义。

**无需 Sim 额外时间 Map**：已核 step 的显式 move/guard/relay 各一次 `_walk`；_separate 只要调用 _walk 必返回 true，调用者 continue；_approach 的缓存 _walk 后 return，新规划分支也只调用一次。真实重复仅是 _walk 内安装/受阻重规划后的 continue。因此 `_walk` 局部 remaining_time=delta 足够，每次已接受推进扣真实用时，continue 不重新积分原 delta。B 的 query/扫段临时表生命周期保持。

## 推荐简式积分

设底盘最大速度 V，a=V/.25、b=V/.20。不要使用对新速度直接乘整个 delta，也不要每个 Bezier 小弦重复加速一个 delta。

1. 在局部路径值上计算后向速度上限：终点 q_last=0；其它 waypoint q_i=min(V,corner_cap_i,sqrt(q_next²+2*b*L_next))。不改变位置或路径，是本次 _walk 局部临时数值数组，不进检查点。
2. corner_cap 只限制行进速度。可用离散转角/相邻弦长估计曲率 k，再取 min(V,omega/k)，omega=2*PI rad/s 只是重量感参考，**不是攻击/盾朝向统一角速**。长边合法硬拐角不能拿很长边长稀释曲率，建议曲率计算长度上限 .60m、下限 .0001m；普通共线 k=0 则 cap=V。角速度或侧向力不是本项目新的车辆物理保证。
3. 当前弦距离 d、下个点允许速度 q，以加速/匀速/制动至多三个事件作解析积分。恒加速度 r 的子段：D=v0*t+.5*r*t²，v1=v0+r*t。加速到 V 的事件时间 (V-v0)/a；何时开始制动由 `v0*t+.5*a*t²+((v0+a*t)²-q²)/(2*b)=d` 的非负根决定；匀速剩余安全距离 `d-(v0²-q²)/(2*b)`，制动时 r=-b。每次只取“余时、达到速度界、到下个 waypoint、开始制动”中最早事件。
4. 到 waypoint 时解实际所需 t 并精确落在该点，扣该 t 后才换弦。正常末段 q=0，有限解析制动到目标，避免 sqrt 目标速度离散爬行或最后粗暴跳停；原精确钻头/到达容差不扩大。局部重规划也只消费已剩余的 time。
5. 事件数按 B 1024 点及本次最多一次重新安装封顶，建议 6*1024+8；不是按巨大 delta 无限 while 切微帧。正常每弦最多加速/匀速/制动三相。触顶视为异常安全停步并显式保意图，不继续危险余速；大 delta 不重复时间或任意截掉路径。

上述是少量局部数值 helper 的职责，不是新车辆调度器。若 root 选择更简单 sqrt 制动限速+move_toward，须明确最后目标硬截断可能不再满足 .20 秒制动斜率，不能同时承诺恒减速度与该离散近似。建议采用上述有限解析末段以避免该歧义。

每个 D 仍只沿既有当前小弦进入 B strict static→safe_fraction→escape 门；接受多少就只扣实际距离/真实时间，不额外写第二条 position。fraction<1/不可推进即清速，本次不继续用残余危险速度；允许沿原 B 条件尝试安装下一合法路径，但剩余时间安全停止，下一实际 step 再起步。

## 新令及完整生命周期

- 整组移动规划仍纯计划，全部成功后才在原提交块更新速度。建议新速度 `max(0,old_speed*dot(old_direction,new_first_direction))`，再按 V 及新路径制动可行界夹紧；反向为零，直角为零。保留方向仅在正速度有效，失败连速度/方向也全不改。自动合法重装同样只投影一次，等待不反复投影/续期。
- 合法 command_focus 原清路线处同时清旧运动，随后真实 _approach 新路径重新起步；非法 focus 不动。进入真实射程/guard不需移动/普通idle的当前 step 立即停，不沿旧目标滑行。显式新短目标若小于既有制动距离，接受指令时的可行速度投影是明确紧急减速，不伪称恒 .20 秒制动。
- 死亡在 Sim._hit 将 hp 置至非正后的同次处理中清该机；Sim._finish 清本实例全部运动。create/新场默认零，NPC spawn 维持零，运行时不热切策略。
- **Mission 终局不是都走 _finish**：实际 SoloMission.order 的 win/retreat、SoloMission.step 的 defeat、Solo._expire 的 expired、Solo._load 的磁盘终局覆盖，以及 restore 的 outcome 都直接赋 outcome。建议继承父类受限 outcome setter：赋非空值时仅在 C 已启用的 Sim 调 stop_motion_all。其它模式 off 时没有运动业务写入，所有真实直接赋值仍在原 owner，不新造状态机。恢复先验证终局记录速度/方向已零，再应用；setter不能拿来洗掉非法记录。checkpoint 读取绝无清速副作用。
- 原 `_turn` 的盾/瞄准函数本体不统一、不接 omega。C 移动调用的 seconds 应代表该接受位移真正用时，而不是旧恒速假设下的 travelled/V；这样原盾 degrees_per_second 仍按模拟时间工作。攻击时 `_turn(...,delta)` 及盾伤害规则保持。

## 同版严格恢复

标准最终策略 v2（建议 path_policy=rail-light-inertia-v2）；create/restore前显式配置，Sim.create 后重施 B+C 配置。Fighter 两字段逐个写入原 checkpoint whitelist。先验证全部行后应用：字段存在/精确 numeric 类型/有限；0≤speed≤对应 V；方向有限，正速度必须近单位向量且方向与当前可行路径切向相容，零速按已签 ZERO 合同；死机/终局/不可移动机不得正速度。不能 normalize 脏方向或 clamp 脏速度。缺字段/B marker/未知 marker 拒绝，不补零适配，仍本轮新场生成。

## 真实宏 step 观测

复用现 ObservedSim，在真实已接受段处记开始/结束位置、实际使用 time、该段前后速度与 travel_direction，单次 super；宏 step 外记 before/after/真实 delta。断言总接受路程≤V*delta、时间和≤delta、各局部速度界/积分/安全、最后速度及方向和实际最后段/当前停止语义一致。**不能把弧线路程当端点直线位移，也不能要求宏位移方向等于瞄准 last_heading；终点速度为0不等于本步位移为0。** 新令投影用同向/直角/反向固定例，失败原子含两字段；加速/转弯/制动各途中同版双实例后续状态完全等值。

是否采用解析三相、曲率具体式/常量、零速方向、受阻余时停止与盾的实际时间输入，均请 root 在具体 AR 锁定后派实现；当前没有 C 实现或通过声明。

## 最终可签纯数学接口（root 最新方向的具体化）

新增 `battle/path_motion.gd` extends RefCounted，仅静态值函数，无实例可变字段/Node/Timer/Fighter/Field/会话引用：

- `profile(points:PackedVector2Array,incoming:Vector2,max_speed:float,brake:float,omega:float)->Dictionary`：Sim 传“当前位置+尚未消费路径”的独立数值数组和实际前切向。返回 valid、各点上限、各弦上限、可行起速，无位置回写。零长段在 Sim 原 waypoint 消费门处理；输入非法值/超1024点拒绝，不修脏数据。
- `advance_segment(speed:float,limit:float,end_limit:float,distance:float,time_left:float,accel:float,brake:float)->Dictionary`：返回 valid/time/distance/speed/reached，内部最多三相，最多三个事件；只处理单弦数值，不认识路径索引/碰撞。Sim 拥有真实 pos、扣时、换弦、动态裁剪、失败/终局。它不能自行“消费”一个单位或设置速度。

剖面：a=V/.25、b=V/.20、omega=TAU。转角 theta 取相邻非零方向夹角绝对值，ell=clamp((L_in+L_out)/2,.0001,.60)，k=theta/ell，corner=min(V,omega/k)（共线为V）。这是离散曲率参考，不宣称折线拐点的精确有限曲率或约束战斗朝向。弦上限：B曲线短弦 L_i≤.12m 时 M_i=min(V,corner_i,corner_next)，长直段 M_i=V（不能因末端有弯而把整条长直道永久限速）；q_last=0，倒序 q_i=min(corner_i,M_i,sqrt(q_next²+2*b*L_i))。起点 incoming 为ZERO时不借瞄准方向臆造曲率；新令先投影到其新首段切向，再计算可行起速。

单弦解析：设初速v、弦限M、末限q、距离d。匀速到制动点时间 `(d-(v²-q²)/(2b))/v`；加速至制动点的正根使用 A=.5*a*(1+a/b)、B=v*(1+a/b)、C=(v²-q²)/(2b)-d，`t=(-B+sqrt(B²-4AC))/(2A)`。加速段到waypoint根用稳定式 `2*d/(v+sqrt(v²+2*a*d))`；制动段到waypoint根 `2*d/(v+sqrt(v²-2*b*d))`。按当前相位在余时、速度界、制动切换、到waypoint中取最早非负事件；每相都用 D/v 的解析更新，不离散Euler重复乘delta。分母/根号边界须明确有限验证和数值epsilon，仅消除舍入误差，不修复非法状态或放宽身体/到达规则。

Sim 局部事件预算建议固定 6*1024+8，涵盖原路径与原最多一次重新安装；每次 helper 返回的 time 只扣一次。fraction<1 的接受前缀可以保留，但本实例速度/方向/walking立即归零并取消本次余时，原条件可安装下一合法路径，不能再次花原delta继续惯性。正常到达/idle/真实射程停机也清两字段；接受新短令的速度可投影并按新剖面紧急截断，该取舍与平常.20秒制动分列。

Mission `outcome` 受限setter写原字段后，非空时调用 `sim.stop_motion_all()`，该函数只在C启用时清全部 travel_speed/travel_direction/walking；因此其它继承消费者 off 无新规则写入。Sim._hit死亡及_finish同次调用相应清零；所有已核直接赋outcome入口由setter覆盖。checkpoint只读，restore先拒绝终局带非零状态，再应用，不能靠setter“修好”坏记录。策略建议 `rail-light-inertia-v2`，必须两字段且有限/界内/方向合法、与剩余路径相容；拒B marker和缺字段。

Dockerfile 当前显式只 COPY field.gd/simulation.gd，因此新增 helper 必须同该行一同 COPY；不是允许构建/运行镜像。后续发行agent更新源闭包/42项映射并独立审实际镜像，当前不修改发行产物。上述隔离基于数学不变量和独立验证价值，不是脚本长度或猜想共享。
