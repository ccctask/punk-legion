# Design

2026-11-15出口：按[收益签收/撤销AR](verification/root-benefit-result-review.md)和[恢复签收](verification/root-withdrawal-review.md)，候选未过收益门，生产精确恢复b0f；历史候选实现许可已结束，不得据下列第二门重新加入。后续性能切片另评审，完整候选预算保持。

## Context

见[proposal](proposal.md)与[原生热点/源码输入](../m06-current-release-native-profile/verification/native-hotspot-source-input.md)。真实CPU只定位到动画祖先，未提供实例/轨道ID，尚不能证明隐藏武器轨道的占比。当前unit变化门和离屏暂停已有实现，不能重复造setter或可见性管理器。

## Goals / Non-Goals

仅验证并可能消除履带机已隐藏武器专属Attack动画写入，保持所有玩家可见行为与模拟结果。GLB/导入发布、其它底盘/武器类型、Idle/Move/Death、共同父轨道、net/sim和G3宿主不在候选实现范围。没有真实收益前不能扩大此候选以凑性能达标。

## Decisions

### 系统AR：root带约束通过（2026-11-15，仅轨道调查与最小自测工具）

**归属。** M06拥有测量与收益判断；M02的robot.gd是实际model/player/挂件组合根，拥有视觉配置及资源生命周期。M03只给已合法化的装配选择，M04/unit只驱动动作，不获得动画资源写权限。未来若修改应放robot视觉包装层，不放网络会话、simulation、导出脚本或共享资产定义。

**现入口。** 模型实例→取得AnimationPlayer→装配变体可见性→set_motion/play_action→既有离屏暂停/恢复→模型切换/free。Attack源含气炮/钻头各自动态子树，但真实导入可能骨骼折叠或重命名，因此第一门仅读取实际引擎Animation轨道/目标、共同父轨道和现挂件依赖；保原源/GLB哈希，不能从GLTF名字直接写生产过滤器。

**状态与共享。** 候选开关只属于单个model/player实例及本次装配，不得修改共享Animation/Library。若真实路径资格通过，后续AR须固定精确允许路径和实例私有Attack及其library隔离方法；保持共同资源只读、其它实例/clip不变。无需全局缓存/事件总线/新manager。只在创建/配置变化时绑定，运行帧不扫描轨道；同配置幂等。

**完整生命周期。** 创建与配置后才绑定当前player；切底盘先丢旧绑定，模型free一并释放私有资源；切回crawler按新player重新建立。暂停/恢复沿现callback/积累时间/advance，不重置播放位置。Attack→Idle/Move/Death及死亡优先级不变。未知路径、非目标配置和其它底盘保持原行为并报告调查限制；不得为了凑匹配扩大隐藏前缀或关闭父轨道。

**第一门范围。** 原dev可在本change verification写最小真实导入调查工具和必要开发自测；生产源、GLB、.uid、导出配置与现旧锁不改。可用既有Godot4.6.1在独立QA目录按哈希复制必要资源，最多一项headless开发调查（含必要一次import，合计最多60秒/OwnedJob；先记录资源/可用内存，失败保原件不自动重复）。只读引擎实际导入轨道及两实例资源共享/目标信息，不启动ADB/AVD/容器/账号/网络战斗/符号。收尾提交所有创建进程身份及最终空树，不在game工作目录写导入产物。

root根据实际导入路径、挂件依赖与隔离证据复审第二门后，才允许生产改动。若无可安全停用的独立轨道，关候选而不是改模型、放宽过滤或先写完补评审。

### 第二门AR：root带约束通过（2026-11-15，仅任务2.1候选生产范围）

root已审[第一门报告](verification/track-investigation-development.md)、真实引擎track-report/result及原OwnedJob：5.345秒/exit0/无超时/最终树和同身份存活空，原源不变。实际Attack157轨、144单key；两实例默认Library/Attack共享，所有目标解析。只准报告中五条精确path+type，不按易变index/笼统前缀匹配：共同前缀`ROOT_PL_SteamCrawler/ROOT_Waist/ROOT_Boiler/ROOT_Weapon/`后，Cannon的`ROOT_Weapon_Cannon/CTRL_Cannon_Recoil`位置、其`CTRL_MuzzleFlash`位置/缩放；Drill的`ROOT_Weapon_Drill/CTRL_Drill_Recoil`位置及其`CTRL_Drill_Spin`旋转。保另外152轨，特别共同ROOT_Weapon位置/旋转；不裁144个单key轨、不改骨骼或资产。

允许唯一生产文件`game/assets/steam_crawler/robot.gd`增加实例局部策略。仅运行时crawler+has_weapon且普通气炮/钻头应用停用：气炮停两条Drill、钻头停三条Cannon。slots缺武器、其它武器/底盘恢复五轨原enabled状态；未知路径/type/重复匹配/原始状态不符时不部分裁剪，保原行为并只在配置时给有限诊断。编辑器预览不实施该运行优化，避免@tool把局部资源写回场景。

资源组合按每个model/player一次绑定：建立私有默认AnimationLibrary，保其它clip引用只读，仅复制Attack资源后修改这五轨。不得直接修改共享资源，不能只事后设置local_to_scene来假装已隔离。绑定须发生在新player开始播放前；相同player重复配置不重建资源、不逐帧扫描。模型/底盘切换丢旧引用、新player重新绑定，非crawler不沿旧缓存写资源；释放随模型生命周期。无需网络/模拟/外部manager参与。

当前player仅调整私有轨道开关时，必须保持当前clip/位置/速度/播放与暂停状态、离屏pending delta及原callback；重新启用的可见支路在出现前取得该逻辑时刻正确pose，不能重启Attack或把过时pose亮一帧。任何必要零时间应用只用于本transform clip，不引入事件重发。不能把现旧离屏逻辑全面重写；发现无法在此边界保持时先回审。

开发验证使用真实完整robot组合，先保前像/精确diff，确认当前所用API/引擎行为，再用必要小场景自测：两个相反配置/共享原件不变、连续切回与幂等资源身份、精确5轨与其余152轨/其它clip不变、无武器/烟囱/连发器/轮式/双足保原、播放中换装与离屏恢复/Death。源资产与其它生产文件不改。自测资源受原AGENTS约束并保终态；正式测试/Android/收益对照由test_lead另选集，不在本门启动或重签包。若场景证明这项候选没有足够收益，保证据并停止扩大，不能用CPU祖先比例为收益背书。

**实际API补注。** 首次开发自测因C++方法is_valid未以同名绑定给GDScript而失败，原件保留。root核[Godot4.6.1官方实现](https://raw.githubusercontent.com/godotengine/godot/4.6.1-stable/scene/animation/animation_player.cpp)：该方法实际绑定名为is_animation_active，直接查询playback.current.from，pause保留、stop清空。优先使用该已有查询，不新增current_animation_changed/animation_started影子播放状态及信号生命周期。原wheel→非wheel已重建player，不为不存在的同player路径增加额外资源复制。

### 独立验收与性能去向

**a4退修AR补充（2026-11-15 root）。** [真实raw根签](verification/root-independent-a4-result-review.md)确认full-clip非rest时旧隐藏Drill子树复制带错旋转。允许仅robot.set_chassis旧模型交给biped.assemble之前，复用现配置/同时间seek恢复五轨，随后复制/free；此为视觉组合根的交接责任，不把恢复放assembly或网络/模拟，不新增状态管理器。原clip/时刻/暂停/速度/离屏pending和资源私有性不变；不能为绕过真实失败缩短动画或放宽比较。初始ready、轮式和双足重建同样守原合同。新源需独立四组验证后才定收益。

test_lead先审开发差异和最小选集。若后续实现获准，真实场景至少覆盖气炮/钻头同时存在、不同实例互不污染、重复配置与切回、无武器/其它武器保原策略、双足切换、共同轨道保留、Attack/Move/Idle/Death与离屏恢复。测试可以共享此真实场景入口；开发自测不代正式签收。

性能采用既有同站点/同初始规模/同视角的有效短选集，先提出最小A/B与可比性/资源预算，再由root签。只有短选集显示可核改善且行为保持，才并入M23最终候选；无收益可撤销候选生产改动，证据保留。不机械再次完整9分钟通关或CPU全采样，更不能删慢帧凑数。最终完整候选仍须原33.333ms预算验证。

### 收益工具AR：root带约束通过（2026-11-15，仅工具实现/文件准备）

依据[test-benefit-method](verification/test-benefit-method.md)及a5行为根签，允许test_lead仅在verification/testing增加bench.gd及薄run_bench.py和必要记录，不改生产/四组工具/共享runner/旧锁。M06测试夹具拥有呈现输入与计时，当前Catalog/Rules/Sim.Fighter拥有真实字段与定义、Unit.setup/sync及Robot拥有实际动作/姿态；不得镜像实现新的动画过滤或战斗引擎。

主负载24台普通气炮(18友/6敌)，依据a8真实生成器及Pump样例；本轮新Fighter/真实unit.tscn，baseline只替Robot为真实b0f前像。1Hz代表连续交火上界、Attack后>.32切Motion经真实Unit.sync驱动。每等量块前半6台walking、后半0，其余18静止，明确只是首尾快照代表而非精确战斗重放。all-visible/无死亡为固定规模上界，不冒原场同屏事实；不运行full2秒Attack作主判。

两边同固定dt1/60、手动callback且每tick恰一次advance，通过真实SceneTree process_frame边界覆盖自然消息/transform flush周期，不每tick强制getter/信号/额外观察子节点。资格阶段原Skeleton3D.skeleton_updated见证与visible普通mesh/project interpolation/default identity源合同说明须分观察/推断/未覆盖；bone pose getter会自行更新，不当自然完成证据，信号不冒GPU/skin上传完成。资格后断开信号；缺关键刷新见证时按未证报告，不凭局部无差异宣称真实场景无收益。

每块新建等量24单位，构造/私有复制和释放成本另计并保资源数，预热120tick后计300tick；8块顺序A B B A A B B A，每块同一预先声明输入序列/姿态初始条件及预热，不运行后调次数。块间销毁并跨帧完成原释放，再建下一块，不能累积48/72台或把初始化藏进稳态。所有输入/源码/资产保持同锁，只有候选Robot相对于真实前像不同。

分开报24次advance批量调用wall微秒和跨完整SceneTree周期的块wall/每tick成本；计时区不输出日志/断言，原块全保、不扣任意常数/删慢样本。它们都不是进程CPU、GPU或FPS。阈值预先锁定：按邻近配对(A1,B2),(A4,B3),(A5,B6),(A8,B7)，d=1-B/A；median(d)>=.05且median(d)>2*median(abs(d-median(d)))，两ABBA循环各自median(d)>0，方记该代表负载有筛选信号。不是统计显著性证明或新包帧预算；local advance单项改善不能代整体场景信号。无信号/资格不足保限制再由root决定范围，不擅裁轨或补轮追显著。

**QA节流前置。** 两边记录并设置Engine.max_fps=0、OS.low_processor_usage_mode=false及OS.low_processor_usage_mode_sleep_usec=0；仅临时项目的application/run/frame_delay_msec=0，命令无frame-delay覆盖。依据[4.6.1 OS实现](https://raw.githubusercontent.com/godotengine/godot/4.6.1-stable/core/os/os.cpp)650–696，不能绘制时仍会取sleep_usec，因此只关low-processor布尔不足以排除headless帧延迟；[脚本属性绑定](https://raw.githubusercontent.com/godotengine/godot/4.6.1-stable/core/core_bind.cpp)779–785可核sleep值。此为测量进程条件，不修改生产帧策略。未确认去除节流即主wall资格不足，不以被固定等待锁平的数据判无收益。

准备85工作/内OwnedJob90/外120，收益45工作+15清理/内60/外75，终止8+空5另列，单引擎/free>=2GiB；超限保首错/部分raw，不减次数重跑。工具冻结后交确切命令/源码与完整输入/11保护锁，root另签真正执行；本门不运行Godot或qualification，不启Android/服务、重录、签包或更换试玩。实际平台比较和M23最终源接纳仍后置。

## Risks / Trade-offs

- 动画祖先不等于隐藏轨道为主因 → 第一门真实路径与资源核，保假设/证据区别，不承诺收益。
- 私有资源复制成本及重入污染 → 第二门明确只复制必要Attack/Library、每player生命周期一次，真实多实例验证。
- 隐藏父节点承载其它挂件 → 只精确独立支路，保共同父轨道，关联消费者不清即停。
- QA耗时超过候选价值 → 复用未变规则/资产/符号证据，先headless合同及小型可比收益门，收益不足不扩范围。
