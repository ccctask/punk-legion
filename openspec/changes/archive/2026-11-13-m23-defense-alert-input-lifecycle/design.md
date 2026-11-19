# Design

## Context

见proposal。当前工作树defense_alerts.gd与1076冻结版同样在删除旧行时立即remove_child，pressed→base._open_defense→隐藏HUD→visibility_changed→set_screen/_restart/_show_rows路径会同步回到该删除。a3/a4原生错误及只读线索见已归档两链root-current1076-final-review，暂无完整引擎栈；不能把假设写成已证崩溃。

## Goals / Non-Goals

消除真实GUI分发期间的离树访问风险，保持一次点击对应一次正确营地导航、旧提醒失效与后续提醒重建。实现范围优先单生产脚本，测试使用已有GUT隔离工程及真实Viewport输入。无需新增UI框架、服务、日程或商业化功能，不扩M06采样工具；当前正式1076不因此自动变成已修版本。

## Decisions

1. **先验证可复验边界。** test_lead用实际defense_alerts.tscn放入既有SubViewport真实GUI路径，以生产按钮实际矩形派发按下/抬起；enter回调同步隐藏屏幕/调用实际set_screen(false)，覆盖已知重入边界。直接调用pressed.emit或手写can_process错误不算GUI重现。修前保原始日志/失败，若未重现如实标限制，不重复碰运气。
2. **退休与销毁分离。** 首选使旧按钮立即隐藏/不可输入、从业务映射失效，再queue_free等待安全释放，保留输入栈退出前的树归属。替代方案是延后导航，但会引入重复输入/页面已变化时的旧导航校验，当前不优先。开发方根据修前证据可提出更小等价实现，需root核对范围。
3. **定向复用自动化。** 专职测试代理维护已有tests/godot入口，只加入本真实场景及其最小依赖和独立组。验证一次点击的node ID/次数、退出后无旧点击、同帧清除再重建与锁定/后台规则、引擎无该错误；不把内部结构断言堆成实现镜像。原lobby/rules/async依赖未变则引用既有证据，不重跑全矩阵。
4. **分工与版本边界。** test_lead先锁修前生产源并执行一次真实GUI基线；开发代理在基线完成后修一处生产脚本及必要自测；正式测试由test_lead以新run-id执行受影响组。root审实际失败/通过、输入路径、断言与清理后签源码修复。源码签收不代表原1076 APK已更新；候选构建/原生受影响入口另需具体包/源差异与放行，不能拿旧两链证明新代码。
5. **资源。** 本阶段仅固定Godot4.6.1及已固定GUT9.6.1，单引擎/新隔离目录/user，无Docker/ADB/AVD/账号/数据库。导入90秒、每次定向组60秒，已有Job负责子树与任何导入自动子进程，保存实际argv/SHA/终态。首错停止，零用例/跳过/错误不得假绿；不导旧user，不修改冻结源/包。
6. **候选源码基础。** root只读发现工作树相对rc1076还含32处既有差异（测试/文档、泵房文案、已验c88服务及旧未引用脚本缺失），不盲目freeze全部、不恢复或覆盖其它工作。候选以已签rc1076完整515源码复制到新目录，仅叠加本修复脚本与明确的构建版号/端点变换；有效服务继续固定已签c88及原镜像。只复用代码，不搬旧user/账号/数据库。实际签发code须核既有发行账本及原签名材料，不自动生成新key；导出/验证先提交具体前置和预算再获root放行。

## Risks / Trade-offs

- 真实GUI与直接发信号不同 → 必须保实际InputEvent路径和原始引擎错误；不能用替身绿灯冒充Android日志已消失。
- 延后释放的一帧旧行 → 立即隐藏/禁止输入并清业务引用，覆盖同帧新行与重复点击。
- 缺完整原生栈 → 修前若不能在公共GUI路径重现，注明未证原因，root决定最小原生补证，不扩猜测性重构。
- 发布依赖变化 → 明确源码签收/实际试玩版本，未构建的修订不能称已交付。

## References

- [Godot Node生命周期](https://docs.godotengine.org/en/stable/classes/class_node.html)：remove_child与queue_free的不同语义。
- [Godot Viewport输入分发](https://docs.godotengine.org/en/stable/classes/class_viewport.html)：真实push_input路径。
- [现有测试入口](../../../../tests/godot/README.md)与[测试协作](../../../../docs/testing/README.md)；其现成真实GUI输入实现优先复用，不增框架。
