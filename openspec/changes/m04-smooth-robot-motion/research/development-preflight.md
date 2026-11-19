# 运动开发实施前核查

2026-11-18，motion_dev。状态：只读调查交root，不是实现准入。已读AGENTS、docs索引、模块边界、架构评审及本change提案/设计/两研究和测试规划。未启动引擎/SDK/容器/服务，未写产品或测试代码。

## 1. 首期建议落位

首期只启用标准Solo探索。`expedition.gd`是共享父页，party/pump/factory/armory也继承它；不能仅凭场景名统一启用。建议页面显式判断`party_mode==false`且当前admission没有old_armory location/其它activity，并确认`net==solo_session`，其余消费者沿原显示链直通。最终准确判断由root AR锁定；不能把`activity`缺省与未知自定义模式一并视为标准Solo。

建议允许生产文件：新增`game/battle/motion_track.gd/.tscn`，组合到`game/battle/unit.tscn`；`game/battle/unit.gd`只提供局部组件配置/入样/取样接口及手动分支插值模式；`game/expedition/expedition.gd`接入标准Solo上下文与呈现。若静态净空helper需要公共落位，另在原`battle/field.gd`增加纯查询，不改现有`walk_region/region_path/can_see`行为；AR明确这一个新增查询后再写。

推荐唯一写链：组件无`_process`、不写transform，宿主`_sync`向各view子组件传值拷贝，宿主`_process`取样到现有派生Fighter显示副本，然后原`Unit.sync`唯一写Node3D/Robot yaw。`net.state/targets`仍是最近接受的权威快照，不让显示采样回写这些字典。本地battle/exercise默认不启用网络延迟。

组件职责是有界样本时间线；不拥有HTTP、RPC、目标规划、伤害、费用、存档或全局时钟。接口候选为显式configure/reset/push/sample，不引Autoload或消息总线。samples只保存Vector2/float/bool等独立值；`Solo._delta`会原位修改state，不能存row引用。相同elapsed的ACK changed不是新位置样本。

## 2. 标准Solo同源几何与保守策略

标准任务与客户端已共享`res://expedition/rail_sites.gd`：`AREA`和`obstacles()`包括四岩体、采集物足迹与出口门柱。`SoloMission.create`用其构`Sim.Field`，`assets/salvage/yard.gd`也读它建立视觉；因此不用从Mesh AABB猜阻挡。角色半径可从`Sim.Catalog.CHASSIS[row.chassis].body_radius`读取。当前client actor.stats只有max_hp，不能误读其radius默认值冒真实半径。

首期显示guard采用这些静态矩形与真实半径作更保守净空证明，bounds也应计半径。可复用现有`Field.segment_distance_squared/segment_clear`作矩形边界胶囊距离查询，并明确端点在矩形内的拒绝；不复制整个Sim规划。新增helper若落Field，只是几何查询，不能安装路径、改命令或访问net。

**历史合同限制必须保留：** 当前`Sim._static_walk_segment`只检查端点圆整格及`Field.can_see`中心线；`_exclusions`的半径用于动态身体。例岩体`Rect2i(-14,-19,4,15)`按可视整数格边界下侧y=-19.5，合法邻格y=-20中心距0.5，crawler半径0.6有0.1名义半径重叠可能。这是源码几何推断，未跑实际路线；不能称历史权威静态点已全身净空。

按root消息决定：只有端点和整段都通过更保守guard时才作新插值；不通过则hold/snap到权威点，不缩半径、不修改权威中心线规则。QA分别登记“新插值段”与“权威原点历史重叠风险”，后者留B阶段。稀疏端点不能证明同时间动态身体轨迹，首期不把视觉插值冒作新的碰撞权威；若需要全轨迹安全证明，须由M05发布可信中间轨迹并另审，不在客户端寻路补齐未知事实。

## 3. 生命周期与应用边界

- 创建：标准Solo收到有效首帧后生成Unit，直接放首姿态再初始化时间线；不从原点飞来。
- 接样：宿主持mission/id、stage、session instance与本地连接代次；新elapsed入样，重复ACK不入样；输入必须finite。新阶段、重新连接、离线/终局、不同seat或mission重置。
- 运行：`Time.get_ticks_usec`只推进本地呈现时间，server elapsed是样本时间轴。样本延迟/上限由正式基线后root定，不先统一拍100ms。手动分支关闭Godot自动物理插值，不能叠加两次滤波。
- 规则：HP、死亡、收据和终局沿最新权威值立即处理，显示队列不延迟结算。盾板与攻击朝向须由root明确最大偏差；首期可保持盾板/实际攻击朝向直通，不暗改正面减伤。
- 缺样本/隐藏/后台：有界保持，不无限外推；恢复重锚到当前接受帧，不慢放后台积压；具体通知在页面既有`_notification`门接入，不另加Timer。
- 关闭：原`_release/_exit_tree`断信号、disconnect_mission；Unit销毁释放子组件。`_continue_party`原clear views/actors前需走组件清理，但非标准模式不能被误启用。网络晚包先沿原session门拒绝。

## 4. 首个自然基线工具

优先复用`tests/godot/process_owner.py::owned_run`作为唯一资源所有者、既有M04 source closure/project配置构造经验和`verification/testing/n_solo.gd`的准确admission oracle语义。不要原样运行旧`outing_ui_peer.gd/run.py`：它固定3角色且显式停开server physics，验证的是反馈/恢复，并非自然20Hz。新基线只需server+一个真实Windows GL渲染client两引擎。

窄QA脚本建议：一份server观察子类包裹真实`net/solo._physics_process`的super前后记录elapsed/pose/wall cost，包裹非RPC`_send_delta`记录发布时刻；一份SceneTree客户端实例化原`expedition.tscn`并正常configure两借用Session，以原`net.command`或页面`_field_tap`发真实move，经真实ENet/_order/Sim执行。client在原页面_sync连接后观察changed并立即拷贝数据，在`RenderingServer.frame_post_draw`记录最终view位置/yaw/walking/帧时。不得停physics、改pos/HP/地图或把同进程时钟差当单程网络延迟。

项目复制/导入、端口、独立userdata、新内存Mission/admission、公共截止和退出需root工具AR锁定；这里只给候选，不新增runner平台。小型固定2peer协调可直接复用OwnedJob；不会运行真实Profile账户/费用/掉落结算，必须把admission oracle与真实RPC/自然规则分开标记。

可供root锁路线的来源：标准Solo第一友机出生(-30,-18)，第一岩体使移到(-8,-18)产生真实绕角；仅为路线候选，需以实际正常指令结果验证，不能先改权威pos/Field制造弯道。正常全程可记直线、绕角、短距停止/反向；每段出站命令/ACK/首次权威移动/首次显示移动分别记。导入准备与实际30秒观察分预算，失败保首错，finally关peer和进程、核原Job/强身份/端口空，不碰用户六R2/手机。

## 5. B/C后续真实所有者

路径安装在`Sim._install_walk_path`及`order_move`，目前`Field.region_path`回溯原四邻格点。B阶段可在安装时做候选可见段裁剪，仍经现`_static_walk_segment`与动态safe_fraction/_escape_improves推进；不能每渲染帧重算或删除0.5sim错峰。圆角改变真实路径/到达，需独立AR和现M04规则/consumer测试；静态完整半径净空风险一并明确，而非渲染里偷偷修权威。

新增权威velocity/转向状态属于Fighter实例与Sim步进。实际持久化基础为`SoloMission.checkpoint/restore`的字段集合，Party `save_party/restore_party`嵌套该checkpoint；Pump/Factory在super后加自己的字段，Armory/Camp也复用基础checkpoint。不能只给Solo字段而让继承模式继续丢失速度；必要时首期惯性须显式按mode opt-in。严格恢复只验本轮新格式完整字段，缺失/非法拒绝，不适配旧档或迁移。当前`_turn`盾板180度/s还参与_hit减伤；不能把所有朝向挪成无权威的动画。

## 6. 当前核查锚点

生产源与1084的已签SHA继续以`research/godot-technical-review.md`为准。本次只读新增定位：`rail_sites.gd`完整定义；`solo_mission.gd:39-40,187-195,250-302`；`simulation.gd:192,612-630,640-729`；`expedition.gd:723-745,796-807,877-911,1039-1104`；`net/solo.gd:323-350,671-676,703-753`；旧`outing_ui_peer.gd:32-65,119-148`。本稿尚未核准生产或工具代码范围，等待root具体派单。
