## Evidence and boundary
必读docs/README.md、1074归档root-review与android/mobile-review，以及此前m09-android-workshop-reply-diagnosis探针。复用已修正的sparsepck索引处理，避免重复实现。1074正式签名APK保持原哈希，当前六服不动。

## Diagnostic setup
部署子代理从1074冻结profile镜像创建独立项目，仅启动profile所需实例；核实专属端口、初始业务表全空和新卷，使用新的安卓测试账号。诊断APK仅允许端点及workshop日志变动，保持原业务判断、请求时序与次数；列出每个资源及索引差异，主代理验包后才交移动代理。若需要服务端日志，优先sidecar/只读观测，不改变业务响应。

记录route、操作key的SHA256前12位、单调耗时、request返回错误、request_completed result/HTTP状态/实收字节、解析类型、九项确认校验的布尔结论和不确定分支类别；不记录token、密码、请求/响应正文或原始key。关联实际服务响应长度与收据摘要。仅采TCP连接元数据/监听队列计数，不持久化带凭证的报文负载。

## Execution and acceptance
先普通直连，正常保存v1、制造、保存v2，遇失败保留同操作继续按既定上限恢复。覆盖原号重进/冷启与唯一账目。主代理独立核对真实失败的回调与服务证据；若result2，只能判连接建立失败，须有进一步可复验对照才能定位哪层。若200完整回包却校验失败，记录实际失败条件；不得凭当前库重构响应替代历史失败证据。

失败未复现时限定采样轮数/时长（最多20分钟设备操作），保存成功覆盖与未复现结论，不能声称修复或无限刷样本。仅在实际失败存在并能区分变量时执行一次小范围对照；进一步业务修复另评审。官方枚举依据https://docs.godotengine.org/en/4.6/classes/class_httprequest.html。

历史`2026-11-09-m09-android-workshop-reply-delivery/verification/root-review.md`记录读取/refit的关闭与有限keepalive A→B→A对照，当前策略未覆盖design/build。这是优先调查的假设；本轮先保持原策略采实际失败。只有证据支持时才用单变量临时对照，不能把旧refit结论直接推为本轮根因或改正式服务。

## Cleanup
启动前核对已有实例与可用内存，登记PID/AVD/端口/项目、共享关系；成功/失败/超时路径都保存证据并卸载诊断包、正常退出唯一模拟器/专属ADB和观测器，按精确项目配置down删除测试容器/专网，保留命名卷和证据，根复查零残留。当前1074六服继续试玩由主代理接管。
