# Godot专项研究与技术方向签收

root，2026-11-18。按负责人明确的Godot方向补充既有研究，已读两个研究子代理完整报告、当前Sim/Field/Unit及探索链，并实际查Godot4.6官方物理插值、AStarGrid2D和NavigationAgent文档。Godot专项稿SHA256 ffb6b62299d7ce002dbecd78107c3c43808a82f7897519a96ecb2b1d3d6612a4；当前被核17源与1084一致。初版已包含Godot基础，本次补到了具体API、实际消费者和场景生命周期。

签收design新增Godot技术决定：4.6.1/GDScript、局部.tscn、固定步权威与手动网络显示分离、显示分支避免双重插值、默认本地直通与单一transform写入者、复用真实Field/Sim几何、权威惯性而非客户端Tween。未引插件、VehicleBody、CharacterBody强迁或全局Manager。NavigationAgent可选且不会自动移动父节点，当前动态搜索并非仅AStarGrid2D.route，不能机械换参数。

接受测试规划的现状与限制：无已实现motion组，旧网络流程曾停开physics，旧P95不含逐包pose同轴；应先小型自然Godot/ENet诊断，不跑整套经济/Android矩阵。纯规则、场景生命周期、真实渲染/网络和Android分别记录，当前没有任何实际运行结果或资源收益。

本签是Godot技术方案与研究验收，非具体生产/测试代码准入。缓冲参数、安全角点输入与实际实施文件/API须在后续AR确定；规则变更时另更新行为规格。六项任务只为研究交付，未修运动、未生成新包、未部署或触碰手机/R2、无迁移。本轮研究零引擎/SDK/容器/临时服务，无待交接测试资源。

收尾：selected OpenSpec strict有效并明确skip_specs研究范围。root独立回读Space看板186138dc…0f7f/总览0add8244…c8a5，含Godot根签、6/6研究与运动未实施，和README一致；进度记录seq475/346。旧块/README原像先存progress-before，未重写M01事实。root核当前Sim/Field/Unit三关键SHA仍分别6b9568/b74a2e/f2523a，与1084相同。文档与技术方向收尾完成，无产品/测试代码执行通过声明。
