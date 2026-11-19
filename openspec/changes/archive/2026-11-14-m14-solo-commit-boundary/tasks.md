# Tasks

M14/A01、架构G1；主责/依赖及事实源见proposal/design。1.1、开发2.1/2.2及正式3.1–3.4已限定签收，8/8；候选e873已由[总签收](verification/root-review.md)签收，现1077/r2未包含。总签核对将原规格已有的实际重启要求明确登记为3.4，保已通过选集，不新增玩法或重跑无关测试；旧签收中的5/7为当时历史计数。

## 1. 架构与独立测试准入

- [x] 1.1 主代理完成发布入口/终局/鉴权代次与派生影响的最终AR签收，test_lead交有界选集和新数据来源；见[根签](verification/architecture-review.md)及[独立预选](verification/test-plan.md)，允许文件/例外/提交合同已定。A05执行终态并root释放冻结后才派实现。

## 2. 实现与必要自测

- [x] 2.1 开发代理在已签范围接非终局保存屏障，覆盖order/tick/join/peer_left及期限；见[开发报告](verification/development/report.md)及[根审](verification/root-development-review.md)，一次7例142断言与实际资源终态；替身调用不冒充真实RPC。
- [x] 2.2 原开发代理接不可变terminal优先、部分提交交付、冲突停车及RAM授权核receipt，核晚回调/释放并提供同版本新目录自测；见[源锁](verification/development/static-source-lock.json)/精确diff及根审，原静态退回记录保留，开发结果不代正式3.1–3.4。

## 3. 独立正式验证

- [x] 3.1 test_lead在当前源上用新目录/新任务执行针对性保存故障/恢复/到期/终局部分提交与新Node冷扫描选集，见[根签](verification/root-files-acceptance.md)：独立6例171断言/12快照、真实rename与限频证据/资源已清。新Node扫描与发布观察不冒充真实进程重启或RPC，实际跨进程要求在3.4验证。
- [x] 3.2 test_lead用真实新库/当前合法机体验证原terminal与先提交到期receipt的唯一账目、占用释放及Armory冲突核对，见[根签](verification/root-service-acceptance.md)：三新号3例180断言/32 HTTP记录/8 RO快照，真实200与两409分证；端口原探针限制及只读补证保留，资源已释放，不冒充真实ENet或进程重启。
- [x] 3.3 test_lead完成最小真实ENet与party/camp实际继承合同，见[正式根签](verification/root-enet-acceptance.md)：A1原工具失败/局部证据保留，A2新数据补旧peer拒控/迟canonical及两派生持久化/恢复/实际delta，复用原import而未重复物理障碍；9份A2 Job及权威端口/凭据终态已清，不冒充Android/数字ID复用/两派生完整结算。
- [x] 3.4 test_lead补原有same-version restart合同，见[实际双进程根签](verification/root-restart-acceptance.md)：A1入口解析失败保原，A2确切入口check-only后单新任务/两顺序实际进程，P1终态及原bytes/零settle后才P2冷扫描/真实同payload单账交付；5Job/权威端口及秘密终态已清，无旧数据回放或其它组选集重跑。

## 4. 主代理签收

- [x] 4.1 主代理独立审实际生产范围/源锁、[逐规格覆盖](verification/root-coverage.md)、测试及新数据、原失败/复用依据/账目和清理。覆盖核对发现的“保存仍失败时换席/断线”已由test_lead独立完整原函数1例18断言补齐，见[补证根签](verification/root-unsaved-transfer-acceptance.md)；[总签收](verification/root-review.md)限定接受源码合同范围，更新台账/测试入口并交进度代理，不提升A05、G2–G4或当前1077状态。

## Workflow follow-up

- 正式签收后同步已接受增量、严格验证并归档，核原证据链接。
- 试玩整合或发行另有候选源/包与平台验收门；此项不导出、部署或迁移。
