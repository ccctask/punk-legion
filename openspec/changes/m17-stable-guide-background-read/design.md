# Design / 实现前架构评审

2026-11-18 root **带约束签收，准下列实现**。依据docs/module-boundaries.md、docs/architecture-review.md及M23静态GUI a3根签；目标仅收口现有运动安卓交付的入口阻塞。源码风险非历史失败的唯一原因证明。

## 实现落位清单

| 职责与不承担职责 | 模块/入口 | 落位与组合依据 | 生命周期/状态所有者 | 依赖方向及允许范围 |
|---|---|---|---|---|
| 初载与后台Guide读的表示；不调度基地/不授予进度 | M17 game/onboarding/guide.gd::refresh | loaded已描述有效表示，只给Next/Daily的两处loading赋值加not loaded条件；不新建控制器/状态 | Guide持loaded/reading/refresh_after_read；Base传endpoint/token并调refresh，HTTPRequest完成后实际apply或_failed，节点释放仍原合同 | 保Go.disabled=true与原请求/回调/错误逻辑；不改Base/PageRefresh/服务/布局高度 |
| 真实Guide请求与滚动布局的隔离验证；不冒业务Root/Android通过 | tests/godot/scroll_pointer_probe.gd新增固定base-refresh模式 | 复用真实Base Control子树/Watch/输入/清理；仅此模式_load_gui不先apply_guide，初始状态经真实GET建立 | 原probe持子树/采样/held输入，原owned_run持唯一Godot；旧模式不变 | 只此模式从env读取并严格限定loopback endpoint，真实Guide.refresh与HTTP回包；不直接调用_response或伪造成功信号 |
| GET-only当前呈现夹具传输；不复制业务/账户规则 | tests/godot/http_fixture.py新增窄Guide handler | 复用Fixture(handler=...)线程、计数、日志、停止/close/join；原默认Handler不改语义 | Fixture已有Owner持动态127.0.0.1端口及线程；外层原owned_run命令finally close，不新建runner/Owner | 仅/v1/onboarding，固定测试token、同新fixture.base_guide返回；拒POST，日志不记身份密钥 |

## 状态、失败与共同语义

原loaded=false初载仍loading；loaded=true后台读只保文字，按钮仍禁用，成功仍apply真实数据。读中after_claim只合并原标志，响应先触发原排队再最终apply；503/401仍_failed，实际错误或真实内容变化允许重排。没有新事务、权威、缓存或依赖；Guide不得合并进Base调度，测试服务不得进入游戏源。

## 独立验收与工具准入

复用本轮新呈现fixture341a及receipt，不导入账户/旧库。既有302生产闭包、缓存和overlay分别记账；生产Guide小修与新probe是明确delta，不谎称stage仍纯545/29a4源。

单窗口960×540、固定Godot4.6.1，原owned_run：工作70秒+清理13秒，probe内部60秒；仅一个临时loopback Fixture，无SDK/AVD/Docker/DB。真实6 GET顺序：初载200、已加载同内容200、读中合并after_claim产生200/200、503、401。夹具固定短延迟使in-flight状态可观察，按原stop_event可中止。限定path/header/次数/状态，不能用直接回调完成。初载验证loading/禁用→真实loaded；再真实drag+原固定0.9/scroll_ended，保存Explore/文字/最小高度/滚动；后台同内容与排队过程中及成功后文字和几何稳定且Go禁用/恢复。错误验证原反馈及请求无无限循环，不要求错误态保正常布局。

生产小改不自建镜像规则测试；该真实GUI/GET切片同时承担开发必要自测后的正式独立测试，开发只parse，避免重复矩阵。test_lead在源审后执行一次并提交实际GET日志、状态/轨迹/PNG、具体原失败及清理。原P1–P5业务矩阵和B/C规则按未变依赖复用，不重验经济；不据此宣称实际Android或历史原因通过。任何新依赖/生命周期/额外模式先回root复审。

## 后续交付

独立测试/root签收后，M23冻结新候选源和唯一新code，复用未变服务COPY闭包的实际镜像但重新按新候选身份核验，执行必要Android运动/HOME切片与稳定服务接管，再登记新APK。1085和各失败原件保留；旧R2保手机1083试玩。
