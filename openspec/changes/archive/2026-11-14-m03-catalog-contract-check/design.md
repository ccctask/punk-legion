# Design

状态：2026-11-14主代理已**6/6限定签收**，见[根签](verification/root-review.md)。下文保留最终AR与实施合同，唯一正式运行已完成/门已关闭，未来复验须新锁新run。主代理维护；按[架构评审](../../../../docs/architecture-review.md)签收后派单。

## Context

必要性见proposal。已有正则check_catalog、Godot规则用例及隔离staging/OwnedJob机制；[精确输入](../../../../build/architecture-review/a04-contract-slice-input.md)已核生产接口及四样例。此次新增价值是实际运行时来源与严格递归比较，不是再建断言框架。

## Goals / Non-Goals

固定M03的目录一致性合同及可比装配/编队边界，为后续定义变更提供可重复的小入口。只签版本/底盘/部件及四可比样例，不签制造配方、DB拥有权、完整战斗轨迹、结算、Android或性能。

## Decisions

### 状态与依赖所有者

M03拥有目录语义，两份现有生产表示暂保留；M04/M16/M24消费定义，M09拥有实体解析/占用及事务，M10拥有三累计。测试适配仅连接生产输入字段，不重新计算合法性/CP。工具拥有本轮导出/报告和临时进程，不写生产资源；不建立运行时规则桥、Autoload或公共管理器。独立导出脚本只加载生产RefCounted目录/规则，不依赖游戏场景树。

### 比较及失败合同

实际Godot加载冻结Catalog并导出VERSION/CHASSIS/PARTS；Python读取冻结JSON并核workshop.CATALOG实际消费来源。对象键集合必须全同，数组有序，布尔/字符串/null严格类型和值；有限数字允许int/float同值，禁止NaN/Inf及宽容epsilon。差异报告首个完整字段路径、两侧类型/值、生产源与导出哈希。数据缺失、入口解析失败、引擎错误、零样例或未完成导出均失败；进程exit0本身不代表通过。

比较器用本轮内存副本的单数值差和布尔变数字作拒绝控制，不改生产目录。四样例直接用生产Godot validate_unit/validate_squad及Python validate_fit/robot_points/deployment_for：轻轮+boiler+visor+rivet_repeater合法且3CP；仅cannon替换超重；同一机体重复明确选入双方拒绝但保各自错误码；九台合法3CP机体共27CP明确selected整队拒绝。Python自动选队selected=None语义不同，不可拿其截队充当拒绝。

2026-11-14主代理核[Godot4.6 JSON官方说明](https://docs.godotengine.org/en/4.6/classes/class_json.html)：导出使用full_precision保证数值可回读；引擎会把NaN转成null，因此必须在序列化前递归检查原目录浮点为有限值，不能只靠Python读取导出后检查。Python侧也拒非有限值；不增加平衡epsilon来掩盖漂移。这是工程导出保真约束，不改生产数值。

### 工具组合与允许范围

候选在tests/godot现有机制中新增小型导出/四例脚本与tests侧Python比较/编排入口，文档写入docs/testing。精确文件、缓存来源及源锁由开发/test_lead最终预选后根审；禁止改game、services生产目录/模拟/定义、现有大回归主入口或打包配置。隔离工具不进入正式发行包；不整套导入check_workshop/check_chassis，更不执行旧schema夹具。复用原机制而非另引插件/框架。

启动先锁源/核资源，独立不存在工作目录，缓存只用代码/UID/class元数据，不复制用户数据。先确切入口解析检查再实际导出，按依赖有效性复用已有导入缓存，不能用--import成功代入口可解析。引擎/协调器有界OwnedJob，失败保原日志；成功/失败/超时均收清本轮子进程，保JSON/样例输出。精确预算待test_lead，不开DB/HTTP/ENet/容器/模拟器，不触当前试玩。

### 消费者差异与有限历史例外

本切片不把平台气炮6写成两份目录9的比较豁免；它是M16离线消费者覆盖，原平台设计保防守基线且主规未要求与移动每击同值。保现值只是本次不改玩法的有限历史例外，不确认其最终平衡；负责人M16，触及平台平衡/定义来源/跨玩法同值要求即复审。

Treasure固定步长、钻头间隔量化及空间模型由M04/M24登记执行差异，目录相等不代表实测射速相等。触及武器时序、锁定、遮挡/射程或可比较部件体验时必须行为评审及代表性验证。维修有效输出归属、干扰不阻移动/一次延后/目标保护期、三累计及唯一结算仍按生效规格，不受执行差异豁免。此处保留限制，A04全部能力行为出口仍需原证依赖核查或后续必要代表性验证。

## Risks / Trade-offs

- 两份表示仍可漂移：用精确键/值及生产SHA的实际加载证据保护，不声称已变单一物理来源。
- 语言函数输入/错误码不同：只比较同一明确输入意义，保差异；合成可信rows不冒充真实制造/归属。
- 工具假绿：校验真实完整导出、四个具名样例、拒绝控制及错误退出；原结果和资源终态须独立测试/root审查。
- 范围蔓延：只执行已签目录/四例合同，消费者差异另行评审；不得为求目录绿灯改平衡或忽略未知差异。

## Delivery

无生产发布或数据迁移。开发实现与必要工具自检、test_lead独立执行、主代理签收分开；通过仅签本合同及工程入口，1077/r2保持原版本。

## 最终AR签收

2026-11-14，主代理：带约束通过任务1.1。维护入口已6/6签收归档，当前无其运行资源；根核[独立精确预选](verification/test-plan.md)及[四源快照](verification/test-plan-source-snapshot.json)，四个当前生产SHA一致，拟工具目录尚不存在。所有者/输入层次/依赖/失败和消费者例外按上文，不把合成实体当成DB拥有权、目录同值当成战斗全等；例外并未核准最终平衡。

固定允许工具为tests/godot/catalog_contract/{export_catalog.gd,contract.py,run.py,README.md}及tests/godot/README.md真实入口说明；开发证据和自检编排放本change verification/development。docs/testing的正式选集/报告由test_lead后续维护。禁止改game/services的任何生产源/目录、现有通用runner/插件或打包配置；原生产文件集合/哈希及11当前交付保护须冻结。没有数据库/账目事务或游戏场景创建/释放：工具只拥有隔离stage、原导出/报告和有界子进程。

采用无import/无旧缓存最小stage，只含原Catalog/Rules、新导出脚本及project配置；不执行旧check_workshop/check_chassis或其schema夹具。Godot直接加载真实常量与Rules，Python直接消费workshop和原JSON；共同fixture只适配输入，不重新实现合法性/CP。GD原字典序列化前finite、full_precision、Python严格类型/数值及第一差异路径均为必要门，不能用epsilon或值转字符串绕过。

开发自检限两项：新stage的确切GD入口check-only（不实际导出四产品样例），Python语法及必要比较器内存拒绝控制；最多30秒工作加10秒清理，单刻一引擎，使用既有OwnedJob及精确实例账目。交原日志/输出/源和资源终态，不代正式验收。开发可写自检薄入口，不能为它堆叠第二套断言框架或正式矩阵；发现要改生产或补import/资源依赖须先退根审。

test_lead最终正式选集沿预选：check-only最多20秒、实际导出最多30秒、compare-only缺文件控制最多5秒，均服从统一60秒工作软截止，另15秒清理/总硬75秒，不能把各段上限相加后延长总预算。实际owner/一个同时引擎或短Python控制分别记录PID/创建身份，开始核内存/既有实例，成功/首错/超时均收清本轮Job并保原证。真实导出仅一次，四具名产品样例与工具拒绝控制分列，0HTTP/DB/ENet/Android/Docker或现行服务操作。冻结工具/生产闭包及夹具后根另审唯一执行门；当前不批准正式导出/验收，不重跑原G2/A01或旧GUT整组。
