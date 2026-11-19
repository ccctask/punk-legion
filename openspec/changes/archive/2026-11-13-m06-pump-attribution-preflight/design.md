# Design

## Context

见proposal的当前帧预算问题。输入固定为archive/2026-11-13-m23-lobby-delivery-service-bundle/verification/runtime-r2/test：whole-raw.json.gz（SHA0f9f3b…e887，481poll/11clock/host样本）、frame-report.json、touch.jsonl、launch与两观察员/全局receipt；只读本轮已签记录，不载入游戏存档或写任何数据库。完整分母248.344951秒/7368间隔，原全场P95 77.4546ms、满编80.8106ms及M06未通过保持。

已有纯Python analyze.py（m06-full-pump-playtest-readiness/verification/runtime）提供Clock/pairs/stats；源码无资源启动，可按显式路径及SHA加载。旧client_phase_probe.gd及instrument_client.py存在，但当前expedition._process音效条件已变，旧替换锚点不全适用，旧driver操作路径也不能直接沿用。

## Goals / Non-Goals

交付一个小型一次性离线分析入口、可复核分组和下一测量决策。关联结果只说明同一时间出现；不作“采样导致卡顿”、GPU/单线程CPU归因或性能通过。保持原字节/分母/慢帧，不对外发布新的FPS。无新运行环境、构建、服务改动或迁移。

## Decisions

### 1. 锁定原始输入与原统计

工具位于本change verification/tools，输出显式--out且只允许build/qa内全新目录。输入manifest列每个文件/原统计源的路径与SHA，运行前全核；首次独立实际分析交test_lead执行。直接复用已核Clock/pairs/stats，按原时钟锚范围和原起止交集选择帧，必须重现原all的间隔数/分位/最大值和慢帧数量后才产生新描述。该一致性检查是本次分组分母守卫，不新增实战或重跑旧完整矩阵。

不复制或修改原算法，不用统计脚本重写旧报告；旧代码/帧原文保持。程序只读JSON/gzip/JSONL与明确源码，不能运行历史构建器、ADB、Docker、Godot或访问业务端点。标准库足够，不另装框架/依赖。

### 2. 先描述观测扰动窗口

对raw.polls的host_before/after、visibility_checks的utc_before/after及touch中实际snap/输入操作建立区间，裁到原整场。数字等待步骤单列不当作截图/输入成本，snap记录是含辅助检查的操作窗口，不称纯截图CPU耗时。报告各类窗口数、时长、区间并集占比及合并窗口；重叠窗口不重复累计。

帧原始BOOTTIME间隔用于分位，UTC仅关联。沿原Clock最大pad（本轮约61.476ms），对于每个确定事件窗[L,R]：可能重叠为u-pad<R且v+pad>L；确定重叠采用更保守u+pad<R且v-pad>L；无可能重叠为确定不重叠，其余标不确定。事件先并集，边界使用严格正时长重叠，分组三类互斥且总数等于原全部间隔。保留每组样本数、>33.333/>50/>100计数及描述性分位；不将分组结果当作剔除测量开销后的新性能基线，不作p值/独立样本假设。

### 3. 总主机压力及明确缺口

Windows GetSystemTimes相邻样本以Δ(kernel+user-idle)/Δ(kernel+user)计算汇总CPU忙比例，验证单调/分母；报告样本数、P50/P95/最高及可用内存范围。[Microsoft文档](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getsystemtimes)说明kernel包含idle，超过64处理器时计数范围受processor group限制；原样本未证明逻辑核心/分组信息，所以标为API计数范围内汇总，不武断称覆盖全部核心。没有每核心/每进程/GPU利用率；低均值不能排除单线程瓶颈，不能将host busy等同游戏CPU成本。数据无效需单列，不能编造缺失观测。

现有阶段统计/存活规模只作背景，alive18+6不是实际同屏数。当前画面、宿主服务与截图操作相互关联，单场无法因果分离，因此不在本阶段盲改动画、阴影、LOD、分辨率或渲染后端。

### 4. 为下一次具体探针作出口评审

开发交付probe-reuse-review：逐项核旧instrument_client替换锚点在当前/frozen1076源的适用性，列_sync/_process/机体循环/音效/绘制信号的准确含义与缺失。已有GPU全零来自旧GLES转译器实测，不把0当零耗时；RenderingServer头less计时为dummy。官方[CPU优化](https://docs.godotengine.org/en/4.6/tutorials/performance/cpu_optimization.html)提醒剖析可能扰动且等待未必计入；[渲染服务](https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html)说明headless dummy，绘制信号不等于GPU完成。主循环分段的嵌套区间不相加，idle前空隙包含未知引擎/调度工作，不直接名为OS等待。

root根据结果只选择一个后续具体测量问题：若时间窗关联强但不确定，优先验证采集扰动；若未能解释，优先适配已有分段探针核主循环/提交边界。两者均须明确可回答的问题、不能回答的因果、开启/关闭扰动评估、最少样本/资源预算及停止条件；另立或更新具体运行方案后才授权资源。此change不把新APK/真实运行藏在“分析”任务内。

## Risks / Trade-offs

窗口高覆盖或pad过大可能大多数不确定→如实报告，不缩pad/删帧求解释。全区间相交分组存在长度选择偏差，长帧本身更易相交→分组P95差或慢帧比例不能单独作为关联强度/因果证据或确定优化目标，下一次需要独立对照。单场相邻帧非独立、host计数聚合→仅描述关联/压力，原因未定位仍写未定位。源/输入漂移→启动前拒绝并保首错，不另找旧数据补数。原源/探针存在不代表当前可运行→锁版本并列真实锚点缺口，不执行旧脚本试错。
