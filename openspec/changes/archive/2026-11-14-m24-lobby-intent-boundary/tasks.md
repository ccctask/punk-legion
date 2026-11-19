# Tasks

M24/A05，G1业务整改；工作树候选与当前1077/r2试玩分开。不得以G0规则签收代本项功能通过。

## 1. 架构准入

- [x] 1.1 主代理核真实四操作/单双人字段、状态与请求所有者和服务约束，签允许文件、局部组合与失败合同。见[评审](verification/architecture-review.md)及design矩阵；未改服务API、事务或规则。

## 2. 实现与必要自测

- [x] 2.1 开发代理实现本目录纯意图组件和页面capture/revalidate组合，保body深拷贝/顺序、相关字段校验及同阵容确认/取消正向语义；用必要小型反例/正向自测和源差异说明验证，不建立全局管理器。见[开发报告](verification/development-report.md)，GUT5例31断言；正式验证另列。
- [x] 2.2 开发代理接视图有效性/初始按钮、请求实例及代次、同步失败/未知写/Back先关闭等生命周期，必要自测后交冻结源、准确命令与限制；不构建APK、不启正式服务，正式测试交test_lead。见[源与证据锁](verification/implementation-source-lock.json)及报告；正式证据另见3.1/3.2与整体主签，不提升历史开发自测范围。

## 3. 独立正式验证

上述开发交回已由主代理[限定审查](verification/root-development-review.md)。正式3.1/3.2及源码合同[整体主签](verification/root-review.md)分别留证，当前1077未包含修订。

- [x] 3.1 test_lead按锁定源/夹具选集在真实treasure.tscn/SubViewport/InputEvent和可控真实HTTP验证四写、solo/duo确认的失败与正向、坏结构/同步错/超时/队伍及输入变更、admission/离页迟回调/未知写；记录实际POST、控件/请求终态和省略/复用依据。见[主代理限定签收](verification/root-scene-acceptance.md)：a1原13通过＋a2仅补原两工具失败函数，保原失败；框架替身不冒充真实DB/ENet/Android。
- [x] 3.2 test_lead使用独立新库/账号/合法机体和服务最小集成核相关group/占用/回执：失败GET不产生排队副作用，重新明确操作后按正常规则一次生效；见[整体根签](verification/root-review.md)，实际1连续case/150断言、7POST/11RO快照及秘密/资源终态，不要求无关到期领域或整库字节静止。

## 4. 主签与状态

- [x] 4.1 主代理独立审范围/组合、生产差异、测试入口/断言/原始失败和清理，签[源码合同限定范围](verification/root-review.md)；任务/测试入口与进度分别同步，当前1077未包含修订，不提升G1其他项、Android或M06结论。

## Workflow follow-up

- 严格验证后同步已签M24增量、归档并核链接。整合新APK/试玩另有发布候选与平台门，不能本项自测后直接替换正式1077。
