# Tasks

## 1. 运动问题调研

- [x] 1.1 只读核各模式模拟/广播/显示、路径及朝向，研究报告按源行区分事实与未测因果。
- [x] 1.2 读Godot、网络插值、NVIDIA赛车输入平滑及CMU Pure Pursuit原始资料，给出分阶段边界及几何安全/响应验收建议；root签研究design。
- [x] 1.3 在现有进度与文档入口登记研究结论及运动未实施状态；见root-research-review.md，本阶段勾选不代运动已修复。

## 2. Godot专项技术方案（研究交付，不是代码验收）

- [x] 2.1 核Godot4.6官方资料与1084实际调用链，明确物理/网络插值、AStar实际消费者与原生导航/车辆节点取舍；见research/godot-technical-review.md。
- [x] 2.2 明确Godot局部场景组合、默认本地直通、单一显示写入者和样本重置生命周期；root签技术方向见root-godot-review.md，具体代码准入另门。
- [x] 2.3 专职测试规划核现有Godot/GUT入口及自然ENet限制，列连续性/几何/响应/同版本恢复选集与预算草案；见research/godot-test-plan.md，未执行测试或资源。

## 3. 标准Solo自然基线与实施准入

- [x] 3.1 root已签verification/root-baseline-tool-review.md工具AR及新行为规格，固定标准Solo/两角色/原Owner/183秒总截止；研究6项不代本轮准入。
- [x] 3.2 工具源与开发实际两import/六GD解析已签，见verification/root-baseline-development-review.md；a2原解析失败保留，a3资源全清，未代自然基线通过。
- [x] 3.3 独立自然基线已签root-baseline-result-review.md（CV0.745595/周期比均6.58），原轨迹/三PNG/资源全清；产品参数与具体落位见root-presentation-implementation-review.md。

## 4. 标准Solo网络显示实现与验收

- [x] 4.1 开发实现局部motion_track场景与标准Solo-only接入，保Unit单一显示写入、其它消费者默认直通及静态净空fallback；结构与开发a2十二例/452断言已签root-presentation-development-review.md，非独立收益通过。
- [x] 4.2 测试代理独立验样本插值/角度、重复晚包/场次/后台/死亡重置、真实场景组合及非法切角反例；正式12/12、452断言已签root-presentation-a1-result-review.md，成功真实重连/Android限项保留。
- [x] 4.3 同路线自然Godot/ENet及补证已签root-network-presentation-exit-review.md；原逐postdraw CV门失败保留，按先签计时复审的旧新50ms补证签网络出口，非屏幕逐帧/Android/性能通过，资源终态已审。
- [x] 4.4 索引、测试文档与Space既有M04行/总览段已独立回读核范围，见root-presentation-final-review.md；本阶段13/13，原逐帧失败/补证限制/B/C未做及无新安卓包明确分列，最终计数按根签窄登记。

## 后续独立阶段

- B安全路径转弯与C权威轻惯性在本轮显示出口后各自评审，不把它们写成已完成。原6个勾选只代表研究/技术方案；当前标准Solo实现和实测以上述3/4节为准，不改M01归档或1084已发布原件。
