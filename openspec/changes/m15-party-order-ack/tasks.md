# Tasks

本change已验收4/4；[root最终交付签收](../m23-architecture-release-integration/verification/root-final-delivery-result-review.md)已闭环关联安卓/性能/稳定分发，本轮本机安卓模拟器内测里程碑完成，非全部模块或商业发行。状态：已验收、路径待归档收口；活跃QA入口互依暂保原位，例外owner=root，下一次入口维护或真正归档复审，不为归档新增工具重构，不伪称已归档。原失败与长帧限制保留，真机/听感交付后负责人终验未执行，后续想法回候选池。

## 1. 实现与结构审查

- [x] 1.1 原开发方仅在Party._order成功保存后为move/route复用现_ack，保_full/所有失败门，交前后像/diff与必要静核，root已[独立签源码](verification/root-source-review.md)。

## 2. 独立验证与组合交付

- [x] 2.1 test_lead按具体工具/运行门验证真实ACK/旧full与新delta交错、失败/未知/旧尝试/跨场隔离，原件与清理由root[独立签收](verification/root-enet-a1-result-review.md)，仅源级兼容不代实际APK。
- [x] 2.2 M23按新后端真实源冻结/单Godot镜像及41/正常加载验证，保现有APK及账本，实测RPC兼容后登记明确客户端/服务端双源组合，不以文档推兼容。 依据[1082/ACK1完整安卓实际根签](../m06-normal-candidate-frame-capture/verification/root-current-pump1082-a3-result-review.md)（仅引用root既签结论，不另签）。
- [x] 2.3 另门fresh operator用该实际组合、新号空卷完成原完整Pump合作/三账/tail/有效双P95，root签后同步M04/M06/M23及进度，保旧失败/精确清理，不自动补轮或加时。 依据[1082/ACK1完整安卓实际根签](../m06-normal-candidate-frame-capture/verification/root-current-pump1082-a3-result-review.md)（仅引用root既签结论，不另签）。
