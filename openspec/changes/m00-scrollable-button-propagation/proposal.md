# Proposal

## Why

1079安卓a3停在基地右侧滚动入口，未能进入合作性能场。真实Godot对照已证明当前Base引导按钮、Party机器人选项的STOP阻断拖动传播；仅PASS可滚且保短click/选机一次，见[M06限定根签](../m06-normal-candidate-frame-capture/verification/root-touch-scroll-probe-a2-result-review.md)。必须先解除这项现有入口阻断，再继续性能与完整包验收。

## What Changes

- 只对当前主干22个普通RELEASE按钮使用原生PASS：Base常用操作10个、Guide6个、合作大厅6个；具体白名单在design。
- Party动态CheckButton仅创建时设置PASS，保选择、read gate、复用和释放逻辑。
- 固定控件仍由场景组合配置，不增加输入handler、管理器、递归全树修改或生产trace。开发、自测、独立验收、候选APK与当前试玩分别登记。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `engineering-baseline`：增加已评审主干滚动控件的拖动传播与普通点击隔离要求，不改变权限、网络或经济语义。

## Impact

主责M00客户端工程输入边界；实现归M11 Base、M17 Guide、M15 Party，关联M06测量入口/M23整合。仅四生产文件：`game/base/base.tscn`、`game/onboarding/guide.tscn`、`game/party/lobby.tscn`、`game/party/lobby.gd`。无需新服务或服务镜像，客户端源变更须新候选与准确验收，不覆盖1077/r2。

不附带OptionButton/LineEdit/弹窗、World地图或Beta菜单、匹配续队、Factory/Armory解锁、工坊/生产其他表面整改；这些没有本轮批准的实现集合。没有新玩法、数据迁移、数值、画面性能或声效改动。最终SF/双P95与经营/Solo/完整Android玩家链仍各自待验，局部机制通过不提高其计数。
