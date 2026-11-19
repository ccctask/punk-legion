# 首期标准Solo网络呈现API草案

2026-11-18，motion_dev。状态：待root根据正式自然基线签具体产品AR；本稿不是代码准入。仅离线源码分析，无产品变更或引擎运行。已完成的开发prepare-only与正式基线分开，后者由testlead独立执行。

## 1. 实际职责与唯一写入链

候选生产文件限定新增`battle/motion_track.gd/.tscn`、修改`battle/unit.gd/.tscn`、`expedition/expedition.gd`及`battle/field.gd`一个新的纯几何query。原net/Solo/Mission/checkpoint、其它模式、模型动画资产不改。

MotionTrack是无_process/Timer的Node子场景，在Unit场景显式组合、默认disabled。Unit持它的实例与释放，Expedition持会话上下文和调用顺序。可由Unit明确公开`network_motion`只读子组件引用，宿主直接调其稳定API；不另造一层只透传的管理器/Autoload，也不让页面按内部NodePath找子节点。

`_sync`读取net已接受状态，向组件push值拷贝；`_process`读取sample，将pos/walking写入原客户端派生Fighter副本，仍由现`Unit.sync`唯一写Node3D.position及Robot.rotation.y。不写`net.state/targets`，不额外接第二套_process/Tween。

保留派生Fighter.pos作为显示位置很重要：现相机中心、裁剪、_unhandled_input的屏幕选取、battle_audio的可见/移动判断都读actors.pos。若首期让actor.pos突然改为最新权威点却单独移动view，会导致这些消费者与画面脱节。该副本不是服务器Sim实例，最新权威位置仍在net.state.units；因此保留原呈现所有权，避免顺手改声音/点击/相机多条线。

## 2. 组件候选API

参数数值由root据基线锁定；以下仅名字/类型与语义，不拍缓冲毫秒数。

```
configure(delay_seconds: float, max_gap_seconds: float,
          capacity: int, segment_guard: Callable) -> bool
reset(context: StringName, server_time: float, pos: Vector2,
      heading: Vector2, walking: bool, arrival_usec: int) -> void
push(context: StringName, server_time: float, pos: Vector2,
     heading: Vector2, walking: bool, arrival_usec: int) -> bool
sample(now_usec: int) -> Dictionary
clear() -> void
```

`configure`只接受有限正值、有效容量/Callable，启用派生显示采样，不访问业务对象。`reset`清旧样本并建立当前权威首姿态与本地单调锚点；首帧直接出现，不从原点飞来。`push`仅存独立float/Vector2/bool，不保row/mission字典引用；过期时间拒绝、同elapsed同pose的ACK不入样。若同elapsed却有实际权威姿态修正，应reset而不是制造零时长插值段。跨context直接reset。

`sample`返回小型姿态值：`{pos, heading, walking, sampled_time, kind, reason}`；kind明确`interpolated/hold/authority_snap/disabled`。它不保存HP/shot/收据等业务状态，不自行设置任何Node transform。无样本/无效输入保持失败可见而不把NaN写Node；guard失败使用最新已确认权威点并标authority_snap，不能偷偷走旧lerp。`clear`关队列，供退出/不适用模式使用。

服务时间用于样本排序；本地Time.get_ticks_usec推进呈现游标。锚点仅在reset建立，不能每来一包都重置到包时间而把网络抖动重新映入显示速度。队列边界外不无限外推；正常端点保持，超过max_gap或恢复/切场后重锚。渲染游标保持单调，不能因一迟到包倒放。队列容量和丢弃策略要在root AR中确定，避免“长度有界但丢掉当前包围样本”。

## 3. 宿主opt-in与上下文

首期显式仅标准Solo：`net==solo_session`、`party_mode==false`，没有old_armory location且页面是标准Expedition；Pump/Factory/Armory子类、party及camp/treasure不启用。建议用现页面覆写点或明确的`_network_motion_applicable`小方法，而非靠运行时类名字符串猜模式；具体标准判定由root AR锁实际admission字段。

上下文为`Session instance id + page-local connection generation + mission id + stage`，不含secret。generation在_join及断开/释放时变更，同mission重连也不能接旧缓存。页面继续持原changed连接，ACK更新UI不强制push新时间。所有视图都只从同一已接受state取值。

新Unit创建后setup，再reset首姿态并正常Unit.sync(delta=0)放到出生点。新阶段/终局、重新连接/离线、应用后台/隐藏→恢复、死亡、退出或再次出征都clear/reset；后台期间不把堆积样本留着慢放追赶。`_release/_exit_tree`在原断changed之前清组件，本地Unit queue_free最终释放，不新建后台订阅。

手动呈现分支的Node.physics_interpolation_mode显式OFF，且不全局开/关引擎插值。不适用的本地battle/exercise与其它远端模式保原默认配置和原4参sync行为。

## 4. 盾向、Attack/Death与显示朝向

建议宿主仍将u.last_heading保为当前权威heading，只用sample位置/walking驱动显示副本。Unit.sync新增**可选第五参**`visual_heading: Vector2=Vector2.ZERO`，旧四参消费者不变；Unit在自己的既有朝向应用处选择最终方向。

移动且无攻击动作的普通机体可采用sample的最短弧heading；带rivet_shield或当前Attack窗口仍用u.last_heading直通，保画面盾向/开火方向贴近现权威。Unit原0.32秒Attack窗口逻辑在同处复用，不在Expedition复制一份武器/动画计时规则；_last_heading缓存指实际已应用的方向。Death/HP/last_shot/维修等沿最新权威字段立即处理，死亡时snap到当前权威位置并清队列，不能让尸体继续慢放旧路径。

这一选择只平滑可平滑的显示朝向，不改变Sim._turn或_hit，不修改盾板180度/s、武器冷却或伤害。Unit.sync仍是唯一写入者，motion组件不直接旋转Robot。

## 5. Field新增纯query

候选签名：

```
static func segment_has_static_clearance(
    start: Vector2, finish: Vector2, body_radius: float,
    area: Rect2i, obstacles: Array[Rect2i]) -> bool
```

只读输入，不改AStarGrid2D、Sim、路径或单位；拒绝非法有限值和负半径。area是整数格中心范围，其几何边界为position-0.5、end-0.5，先按半径收缩外边界。各阻挡矩形同样按整数格占用边界解析。可复用现Field.segment_distance_squared/segment_clear检查线段与矩形四边的半径距离，加端点在矩形内部拒绝，避免另复制寻路或用视觉AABB。查询是静态几何意义，不声明动态身体、门口目标或权限。

Expedition组合根绑定标准RailSites.AREA/obstacles()及Catalog.CHASSIS[row.chassis].body_radius作guard Callable，组件不preload地图或目录。不同底盘半径应分别绑定；静态数组不跨实例变更。只在新样本候选段/真正改变采样段时做必要检查，不在每个空闲渲染帧全图扫描。

守卫应同时检查当前显示点→候选显示点与包围样本段，不能只检查两个端点。任一不满足则authority_snap/hold并记录原因。最新权威点本身历史半径风险继续单列；不能把authority_snap的跳变连线当“系统生成了这条物理插值路径”，也不能声称该权威点已被新的严格半径query认可。B阶段才复审现权威静态中心线与完整半径合同。

## 6. 进入产品实现AR前仍需root锁定

- 独立自然基线的发布间隔/速度CV/帧时、可见响应与几何分账结果，随后定delay、max_gap、capacity及改进/延迟门槛。
- opt-in准确布尔条件、same-time correction与断线/后台重锚的完整触发点。
- Sample游标/包围样本丢弃策略及Field query数值边界，严格静态安全与authority_snap计数口径。
- GUT新小组/真实场景接入与同路线自然ENet对照选集；已有安全/本地消费者哪些逐断言复用，哪些因Unit可选参数变化必须补验。

不因此修改当前1084包、旧M01归档、用户六R2/手机。首期不加权威velocity、checkpoint字段、网络包或其它模式；B/C需要另一份实际AR，不能沿本稿顺手扩大。
