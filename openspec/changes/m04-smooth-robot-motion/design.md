# Design

## Context

本阶段为负责人要求的赛车轻惯性调研，实际源与原始资料见research/motion-investigation.md。20Hz模拟与普通位置广播不同；追最新位置、瞬转朝向、四邻路径和恒速推进均有已证生硬因素，手机帧率/网络抖动尚未实测因果。

## Goals / Non-Goals

原研究阶段已完成。负责人2026-11-18授权开始研发，当前实现切片为标准Solo的自然Godot运动基线与网络显示平滑。先工具AR/独立基线，再参数与产品AR、组件/场景组合和同路线对照；不以一段lerp冒已解决实际运动。本切片不改服务器协议、权威路径/速度/盾向或数据格式，不重写其它地图/模式；原A/B/C后续阶段仍按各自边界评审。

## Decisions

root，2026-11-17，研究签收；未批准运动实现。

1. 先比较模拟进度、真实快照到达、渲染帧时、权威/显示位置与walking切换，区分实际卡顿和追赶观感；只看平均FPS或源门限不算测量。
2. A阶段评估有界时间样本缓冲、显示朝向过渡、移动动画连续性，归M04呈现。客户端不拥有碰撞/到达/盾向伤害；样本不足不无限外推，转角不能用曲线穿柱。具体缓冲时长由真实间隔确定。
3. B阶段可见直线段裁剪与有限前视/圆角归Sim/Field，必须保持身体半径、static sweep、safe_fraction、动态拥堵和0.5sim错峰重规划，不直接全换NavMesh或每tick重算。
4. C阶段轻加减速、转速和急弯限速是权威运动状态，需独立审批参数及同版本checkpoint/restore合同。履带低速可转身、双足敏捷、轮式连续转向作为感觉方向，不偷偷改最大速度/盾板减伤。
5. 每阶段锁实际允许入口、依赖和失败/重置生命周期后再派实现。M01现已归档，1084为后续客户端比较基线，旧后端镜像来源仍单列。状态缓存按场次/席位代次释放，不新增全局运动Manager。

### Godot专项技术决定（root，2026-11-18）

依据[Godot专项源码与官方资料评审](research/godot-technical-review.md)和[最小独立测试规划](research/godot-test-plan.md)。本节签收技术方向，不是生产代码或新测试工具的实施准入；原研究skip_specs保持，不把方向选择冒实际运行结果。

1. 固定现用Godot4.6.1/GDScript，不引PhysX插件、赛车轮胎物理或全局升级引擎。服务器仍由net的_physics_process驱动现有RefCounted Sim/Field；二维权威位置映射到三维Node3D显示，不为“原生方案”将全部机体改成VehicleBody3D或CharacterBody3D。
2. 网络显示使用Godot的_process、Time.get_ticks_usec、Vector2.lerp与lerp_angle表达有界时间样本插值；不是继续对最新点反复lerp(delta*k)，也不只打开全局physics interpolation。手动显示分支显式关闭自动物理插值，保持其它本地场景原配置。引擎reset_physics_interpolation仅清引擎缓存，场次/复连仍需清项目样本。
3. 场景组合方向为局部motion_track.gd/.tscn，Unit显式持子场景，默认不启用；网络宿主显式配置并传值拷贝。组件只维护派生样本，不拥有HTTP/RPC/伤害/路径/存档或独立每帧transform写入；宿主取样后沿现有Unit.sync唯一显示写入链应用。本地battle/exercise默认直通，不能因复用Unit增加网络延迟。具体接口与安全几何输入仍须在实现落位AR锁定。
4. Field已经使用AStarGrid2D；真实动态路径却主要走walk_region/region_path。首期复用原Field几何与Sim路径合同，不能只改diagonal_mode宣称已修动态寻路。NavigationAgent3D的导航地图/避让状态不是现有路径的开关，且不会自动移动节点；没有NavMesh走廊则不启用funnel重写，单独场景迁换另审。
5. 圆角与加减速由权威层分期实现；可用Vector2.move_toward/rotate_toward表达每秒速率乘固定delta，不能用Tween制造客户端越界滑行。新增velocity若影响后续决策必须进入同版本严格checkpoint/restore，测试从新数据开始，不做旧格式默认回填。盾向伤害、最大速度、净空、精确停靠与重规划预算仍是约束。
6. 先诊断探索消费者的实际服务器步进、接包与渲染共同时间轴，再定样本延迟/容量和连续性门槛。现稀疏delta缺角点历史；不能承诺端点lerp或Curve3D天然安全。仅已证明合法的段可插值，缺可信信息需保守处理；若需要服务端补轨迹，先复审M05发布与成本。未证明共同合同前不同时改camp/treasure，不宣称全模式改善。

生命周期按专项报告第5节：宿主创建/配置上下文，接受包后拷贝值，ACK同elapsed不重复入样；后台/断线/阶段切换重锚，不播放积压旧轨迹；HP/死亡/胜负不延迟，Unit销毁释放缓存。独立QA先用实际Godot规则与场景，再用最多server+render client的自然ENet切片。旧outing_ui_peer会停开服务器physics，不能冒自然20Hz；无运动测试组就不得列假命令，新增工具也先AR。合成采样不冒真实FPS或Android通过。

## Risks / Trade-offs

插值增加显示滞后；稀疏点直线也会切墙角；惯性会影响贴近钻头射程、出入口精确停靠和PVP到达时刻。验收必须分别记录连续性、响应、位置/朝向误差、几何安全与帧时，不能用视频好看替代规则正确。参数未测不承诺固定毫秒数；原118/1066ms长帧因果仍未知。

## Research acceptance

研究文档覆盖源码、原始赛车控制/网络插值/前视资料及适用推断、分阶段落位和可测指标。无资源运行。实际诊断/运动实施继续按独立准入，不把研究完成写成运动缺陷修复完成。

## 开始研发与本轮出口（2026-11-18）

原6项研究签收及当时零运行结论保历史。当前取消skip_specs，新增robot-motion-continuity行为要求和实现任务；“技术方向签收”不能替代本轮工具/产品的具体实施AR。

本轮出口：标准Solo自然服务器与渲染客户端的原始轨迹、实际新组件与显式场景组合、数值/生命周期和静态净空回归、独立真实ENet同路线对照及root结构验收。基线记录实际服务器步进、已接受包elapsed/接收monotonic、frame_post_draw可见pose/heading/walking；服务与客户端不同monotonic epoch不直接相减算单程网络延迟。QA admission oracle只为隔离网络诊断，不代表真实账户/经济验收。

标准Solo客户端已有RailSites共享静态地图定义，服务器Mission也使用同一AREA/obstacles。可复用该定义和Catalog身体半径，只有能证明静态显示段净空时插值；不是拿Mesh AABB代业务障碍。稀疏端点不能证明动态身体全过程，故不把呈现当碰撞权威；实际碰撞/到达仍归服务器。缺角点或安全信息须保守snap/hold，几何细节与性能成本在产品AR中固定。

运动改善以可见连续性、角差/停走、额外显示延迟与几何合法性分别判断。缓冲数值据基线后签，不先任定统一100ms或改发送频率。若正常服务器本身停步，不用缓动藏掉。B路径圆角和C权威惯性不得顺手并入；它们后续会改变到达/战斗/检查点，须各自规格与评审，本轮报告明确未实施。

## 首期实际结果与计时口径复审

实际实现、结构/开发与独立十二例见verification/root-presentation-development-review.md和root-presentation-a1-result-review.md。自然a1原逐postdraw CV0.2344超过.20，原门失败保留；依据Godot取样阶段与实际sampled_time证据，root在新增计算前签root-motion-measurement-review.md，对旧新同窗全完整50ms区间作同算法重建，检查150ms收包周期级连续性。该补证CV0.58077→0.02758，其它周期/响应/尾随/静态门通过，最终仅签标准Solo网络呈现出口，见root-network-presentation-exit-review.md。重建不是实际新屏幕帧，原慢帧/回调成本/权威半径风险和Android/性能/其它模式/B/C未验范围均保留，不以指标补证冒全场匀速或FPS改善。
