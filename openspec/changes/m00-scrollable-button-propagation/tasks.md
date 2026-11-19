# Tasks

主责M00，关联M11/M17/M15与M06/M23；[design精确架构签收](design.md#精确落位与生命周期)为派开发前置。原真实机制[M06 a2](../m06-normal-candidate-frame-capture/verification/root-touch-scroll-probe-a2-result-review.md)限定通过，本机产品及[Android输入链](verification/root-android-input-chain-review.md)均已限定签收，本change 3/3；1077/r2保持。

## 1. 最小控件修订与独立本机验收

- [x] 1.1 开发代理仅按design四文件白名单配置22静态按钮及动态CheckButton创建时PASS，交before/diff/四SHA及必要自测或明确未运行，root静审确认无新增状态/处理器、action/业务/read gate/复用释放不变后签源码。见[源码限定签收](verification/root-source-review.md)，只静态自检，未代独立运行。
- [x] 1.2 test_lead按新源准备最小真实GUI拖动/短click/选机/disabled门选集与准确新fixture/stage/入口，root另门后执行并交原日志/图/数值/源绑定/资源终态；独立结果由root签收并同步测试文档，不能原跑要求STOP的旧负例或以机制对照冒新产品通过。见[产品GUI限定根签](verification/root-product-gui-result-review.md)，3drag/5click/16图、10.577秒/925后核同/资源清，仅本机代表。

## 2. Android入口整合

- [x] 2.1 M23新候选及准确门下由test_lead用新数据完成Android Base真实按钮拖动→WorldMap→当前Coop→具名选机/Ready；可合并正常三人性能场，交候选来源、当前图/动作、无误触与精确清理，root只签该输入链并链接M23/M06结果。未入队/未Start/未帧测各自分列，不能由本项关闭双P95或完整包。

[Android真实输入链根签](verification/root-android-input-chain-review.md)：1080 a3正常Base拖动至三人准备完成，通过本项；collector租期不足首错保留，ENet/帧测未运行。

## Workflow follow-up

- root通过逐项证据后更新任务，sync规格并按本change归档；核文档引用，不扩大M06/M23出口。
- 进度代理在原总览/阶段出口/任务页登记本change必要性、范围、当前候选及原始证据；无独立新玩法页面。
- 其他控件表面仅留候选池；新证据要求时先最窄归属评审，不递归改树。真机/听感仍在完整包交付后由负责人终验。
