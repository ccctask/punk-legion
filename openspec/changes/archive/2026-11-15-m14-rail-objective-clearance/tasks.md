# Tasks

最新：已获[V a5六图/清理根签](verification/root-readability-v-a5-result-review.md)，结合[POST](verification/root-exit-post-a1-result-review.md)及[正常Scrap/Party](../../m04-unit-movement-clearance/verification/root-exit-post-natural-a1-result-review.md)，当前5/5待规格同步归档；下文V a2–a4失败保留为历史，不覆盖当前通过。Android/整局/性能及官方1077/r2不变。

当前：三产品文件已实现，已获[源码范围签收](verification/root-source-and-test-development-review.md)及[R a1限定结果签收](verification/root-rules-a1-result-review.md)。[COVER a2实际绕行签收](verification/root-cover-a2-result-review.md)已补2.1剩余断言，此前4/5（V a4后新增门柱侵入修复已获[源码限定签收](verification/root-exit-post-source-review.md)，实际执行/最终图义未通过，不新增玩法）。[V a2六图根签](verification/root-readability-v-a2-result-review.md)采证与清理通过，但多机同落点/敌我近叠令名字HP不能逐台辨认，2.2可读性不通过；已按[M04共享移动](../../m04-unit-movement-clearance/tasks.md)完成获准修订并取得规则/正常路线/消费者及部分联机限定证据；新源[V a4实际根签](verification/root-readability-v-a4-result-review.md)已通过22组件/名字HP布局与五图限定可读，scrap-multi后排身体仍被高门架挡住，不关闭2.2或冻结新候选。现官方1077/r2不变，1078为历史候选。开发静核、独立执行与root签收分别登记。

## 1. 关卡定义、导航与局部呈现

- [x] 1.1 按已签design实现三站共享定义、原公开别名、base地图障碍及合法守卫出生，yard复用定义并调整标签；交实现差异/来源哈希、必要性说明及必要开发自测，root静态核允许范围、依赖和无附带规则变化。
- [x] 1.2 按已签恢复合同实现rail-only新检查点几何校验，合法瞬态原值保留、非法值拒绝且不触及派生布局；交对应真实类自测证据和生命周期说明，root审查。
- [x] 1.3 按V a4实体侵入补审仅在Sites声明两根Exit柱脚足迹并合入rail障碍副本，保门心/4m/视觉、三站与ROCKS/派生合同；交准确差异、所有者与未运行项，root源审后正式验证另门。

## 2. 独立验证与签收

- [x] 2.1 test_lead交选集/省略理由、真实入口和资源预算，root签工具与运行门后验证三站路线/点地/LOS/交战/采集、标准Party、合法恢复/非法拒绝及四派生地图；报告保留原失败、来源与清理证据，由root独立签收。
- [x] 2.2 验门柱阻挡/门洞通行及同轮检查点合法等值/非法拒绝和受影响正常Scrap链，在受控实际Godot渲染核原六图机体/名字/耐久与标题可辨；交原图、实际状态/相机、清理与复用依据由root签，不冒充Android完整链或性能。

  当前失败依赖：[M04机体移动占用提案](../../m04-unit-movement-clearance/proposal.md)，来自V a2同落点/自动交战近叠的真实证据。共享移动/失败合同已在独立M04评审与实现，当前保持其真实源冻结；原M14三文件许可不授Simulation/Field额外修改，不能在此项下顺手改公共规则。新源正常三站/COVER动态证据按M04自然A/B根签复用，不机械重跑。V a3后已完成只读图/标签深度输入，并在[M04信息补审](../../m04-unit-movement-clearance/verification/root-selected-information-development-review.md)明确两个文件与材质生命周期；两源已在M04完成并获[源审](../../m04-unit-movement-clearance/verification/root-selected-information-source-review.md)，V a4实际信息层已限定通过，原M14许可不自行扩到其它Unit/模型改动；已确认Exit门柱实体侵入，按[门柱补审](verification/root-exit-post-development-review.md)仅准Sites物理足迹数据实现；原门洞/4m/姿态/六图条件不变，未准新运行。

## Workflow follow-up

- 所有任务通过后同步规格并按模块归档；进度代理更新原资料页，保持开发/主验/实际试玩版本分开。
- 后续整合生成独立新源快照、APK与受影响服务镜像，再由M23验真实完整玩家链及受影响联机，M06验帧预算；本change局部通过不能替代这些出口。
- 真机及听感：完整可玩版交付后负责人终验，未执行。
