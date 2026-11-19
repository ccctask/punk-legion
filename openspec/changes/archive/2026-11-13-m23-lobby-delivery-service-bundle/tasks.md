# Tasks

模块：M23服务交接，关联M15成功读取交付与M06整场验证。root维护范围与独立签收；开发代理准备稳定输入，test_lead执行实际测试及资源收尾，进度代理同步。当前未授权数据迁移。

## 1. 冻结输入与有界工具准备

- [x] 1.1 开发代理交付operations/1076-delivery-r1稳定bundle、唯一已签server副本、固定镜像/源/包manifest及候选/正式配置模板；启动前生成epoch且两配置一致。通过静态差异、SHA与配置依赖检查证明只覆盖已接受server，不改APK/rc1076、不依赖活动change路径；root审查开发报告，不启动服务。签收：verification/root-input-review.md，仅静态准备完成。
- [x] 1.2 test_lead适配既有M06工具的本轮上下文、全局终局与三人结果映射、末次SF尾采及有界时限，提供测试选集/复用理由、输入锁、定向工具自测和清理路径证据；不复制完整框架，不重跑未变矩阵。root审实际工具差异及必要自测后再授权唯一实战。签收及有限放行见verification/root-tool-review.md、root-runtime-release.json。

- [x] 1.3 保存r1首错及清理、审只读Compose配置结果；test_lead准备并经root审查后执行一次无账号/无网络/无端口/无数据卷的单容器挂载诊断，先保存原inspect再读文件SHA，精确清除实际ID。root据分项证据定位或明确限制，不放宽守卫；新实战输入与工具修订须另审，不能覆盖r1锁或续旧卷。诊断不计作实战/SF通过。签收verification/root-bind-diagnostic-review.md：本次原谓词通过，未复现r1具体子条件。
- [x] 1.4 开发代理准备1076-delivery-r2稳定输入（新project/六卷/网段/启动记录，同一已签server/原APK/image），test_lead在runtime-r2薄适配保留原守卫并在断言前记录原inspect与各子条件；只定向核变化，不复跑未变矩阵。root核差异、锁及纯检查后另放行唯一新场次；r1全部证据/epoch/卷不覆盖、不续用。签收verification/root-r2-preparation-review.md及root-runtime-r2-release.json。

## 2. 一场真实三席功能与帧记录

- [x] 2.1 test_lead使用六新卷/三新号及原无插桩端点包，实际执行一场正常泵房并保存三席到场/各自有效指令、正常全局终局、个人收据/单笔费用/释放/累计、手机战报和整场原始SF；按设计报告覆盖/交火/帧分位、失败与资源终态，不自动补场凑绿。root分别审功能和测量结论；功能缺断言或失败不能勾选，本项不等于M06预算通过。签收verification/root-r2-functional-review.md，功能与资源通过，性能另列。
- [x] 2.2 root独立审查原始帧/观察员/时钟与分母、三人结果映射及测试清理，记录M06数据有效性和实际预算结果；仅同时满足既有覆盖及全场/主要交火P95门槛才签原M06任务2.1，数据不足或超预算原任务继续未通过，明确缺口与下一动作。见verification/root-r2-measurement-review.md：有效全场248.345秒，P95 77.455/80.811ms，原M06任务仍未通过。

## 3. 条件交接与运行文档

- [x] 3.1 三席功能签收后test_lead结束设备/peer/采样，核其余四服务源与五UDP握手、旧环境实际活动/在途/共享归属，再按稳定正式配置接替333xx；核本轮数据摘要一致，精确删除退役六服及候选334xx实例和废弃专网，保留命名卷，提交全部实际ID/标签/配置/健康及资源账目。root审交接与清理后接管；功能未过不得切换。签收verification/root-handoff-acceptance.md，当前r2六服/在用专网由root接管，原失败/实际恢复与M06限制保留。
- [x] 3.2 root核稳定runtime/配置归档后仍存在、旧当前文档已正确更新且没有数据迁移，签本轮实际试玩与剩余M06限制；test_lead维护测试入口/记录，进度代理引用根签收同步原看板/阶段，root核链接和状态一致。签收verification/root-closeout-review.md，归档后引用改址按下述follow-up完成，不提升M06预算或全项目完成状态。

## Workflow follow-up

- 各项通过且无运行配置依赖活动change后归档；本change skip_specs=true，不新增玩法规格。
- 验收失败保持原始记录并清理本轮用完资源，由root将具体缺口退回原实现方，不默认重跑整个场次。
- 归档后更新当前文档、M06活动任务及资料空间到实际archive路径，核Markdown链接与非文档证据哈希；不修改历史命令/锁来重跑已归档工具，不复建活动change目录。
