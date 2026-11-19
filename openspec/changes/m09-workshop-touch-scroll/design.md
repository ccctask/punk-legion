# Design

## Context

见[动机](proposal.md)与[M23原始诊断根签](../m23-architecture-release-integration/verification/root-workshop-scroll-diagnostic-a2-result-review.md)。Shop STOP/RELEASE阻断滚动；Mode STOP/PRESS直接开Popup；Stock IGNORE可滚48。此为桌面原生GUI证据，不能外推Android唯一根因。M00原change明确排除工坊及OptionButton，故本change独立评审。

## Goals / Non-Goals

恢复M09同一滚动内容的自然拖动，短点保持原动作。只用原生属性，不新建手势状态机、基类、全局输入管理器或递归改属性；不改LineEdit、业务脚本/接口、布局、嵌入子场景、Popup内部、服务/费用/装配语义或资产。

## Decisions

### 系统性架构评审与精确落位

状态：**2026-11-16 root带约束通过，仅准以下生产场景实现；测试工具改动另审。** 已核真实workshop.gd/tscn、M00历史范围及[模块边界](../../../docs/module-boundaries.md)，执行[架构流程](../../../docs/architecture-review.md)。主责M09、关联M00/M23。

下列路径均相对 `HUD/Panel/Scroll/Body`，唯一可改生产文件为 `game/owned/workshop.tscn`：

| 职责/明确白名单 | 实现与放置依据 | 状态、生命周期及依赖 |
|---|---|---|
| 16个普通Button：Top/Back、ReadRetry、ClaimPumpArm、Shop、Draft/{Save,Build,Replace,Remove,CopyDesign,ImportDesign}、Garage/Pins/Favorite、Garage/{ApplyDesign,Install,RefitRetry,ApplyHull}、Retry | 各原静态节点仅加mouse_filter=1；它们共同属于该Scroll内容，已有RELEASE保持 | PackedScene创建/释放；原生Scroll拥有deadzone/拖动取消，原信号仍交workshop协调，权威费用/占用归服务 |
| 13个OptionButton：Mode、Draft/{Design,DraftHull,Core,Head,Weapon,Utility,Armor,Survey}、Garage/{Robot,Slot,Item,HullTarget} | 各原节点仅加mouse_filter=1及action_mode=1（RELEASE）；等待原生Scroll判拖动后才允许普通释放开菜单 | 引擎拥有press attempt/Popup，选项及busy/disabled仍原脚本所有；不加信号或本地选择状态 |
| Garage/Pins/OnlyFavorites CheckButton | 仅mouse_filter=1，保原RELEASE与选中意图 | 同一原场景实例生命周期；不改刷新/筛选规则 |

这30个直接控件共享同一Scroll/场景配置生命周期，原`_render`不重设filter/action_mode，无需抽象或脚本。Draft/Name与BuildName保持文本编辑语义；嵌入HullNumber/Orders及HUD旁支ApplyPreview不纳入，不把这次声明为全工坊重构。父Scroll边界及业务所有权不变。

官方依据：[OptionButton默认PRESS](https://github.com/godotengine/godot/blob/4.6.1-stable/scene/gui/option_button.cpp#L608)，[pressed直接切Popup](https://github.com/godotengine/godot/blob/4.6.1-stable/scene/gui/option_button.cpp#L182)，[BaseButton滚动通知取消press attempt与释放条件](https://github.com/godotengine/godot/blob/4.6.1-stable/scene/gui/base_button.cpp#L141)。PASS+RELEASE为待验证方案，不能据源码称已成功。只PASS仍会按下开Popup；换文字起点仅绕过玩家问题；复制drag handler会多一份生命周期，均不采用。

创建→运行→离页/销毁仍完全由现PackedScene/原业务协调；无新状态、请求、重试、事务、清理者或外部借用。点击仅产生原意图，不代表服务成功；busy/disabled及未知提交的既有恢复不得变动。无数据结构变动，不迁移数据。

### 验证与整合出口

开发交前像、精确diff/SHA及静态白名单核查，未经另门不运行引擎/资源。root源审后，测试代理用现probe/Owner准备最小正例：Shop拖动滚且零pressed/新实例短点一次；Mode拖动滚/全过程无Popup/选择不变，短点释放后开菜单并用真实Popup输入选另一项一次；保Stock滚动对照。禁用行为沿原依赖复用并源核不改，不能用旧负例当新产品通过。

新正例的工具适配、真实Popup输入/观测、20秒共同界是否足够须先交root准确方案；不得强制scroll、直接emit/select或调用业务handler冒真实输入。原失败/负例可复用，不机械重跑旧三代表矩阵。通过桌面后M23冻结新APK、复用未变服务镜像证据，再在独立新号/新卷经营链覆盖实际Android滚动/选择/Name编辑/BACK/制造与基地操作。未覆盖的嵌入UI和完整业务保原出口，不据此新增矩阵。

## Risks / Trade-offs

- 下拉框从按下开菜单改为释放开菜单：用实际短点/真实选项一次验证；拖动不能误选。
- 桌面触摸仿真不代Android：M23新候选实际复验后才签平台行为。
- 默认LineEdit仍会处理编辑手势：保原编辑，这是有意边界，不写全控件可拖动的过度承诺。
- 源变动要求新客户端：先限定源/GUI验收，再一次整合构建；1077/r2不提前替换。关键边界已定；若原生属性不足，保失败回root评审，不自行加handler。
