## 1. 场景实现与开发证据

- [x] 1.1 子代理在既有大厅场景实现读取恢复、首次操作门槛、意图上下文及生命周期，交付源码/自测与文档；真实HTTP故障覆盖原失败场景，主代理检查变更范围和单人/匹配取消未回归。

  r3开发自测25场景、59检查通过；主代理复核原HTTP计数、真实SQL及截图，见`verification/qa-r3/dev-root-review.json`。r1产品退出错误及r2夹具串扰已保留失败原证据并修订，不替代后续独立主验。

## 2. 独立验收

- [x] 2.1 主代理用本轮新账号和实际Godot/HTTP故障独立复验设计场景，核真实请求计数、可见状态、无脚本错误、无重复POST及新库状态，保存可复现证据；不把桌面验收当Android整合。

  root亲自执行r3/root，独立25个新账号，25场景/59检查通过，147.17秒；原请求、当前SQL、截图及账号不重叠核查见`verification/qa-r3/root-root-review.json`与`verification/root-review.md`。只签源码/Godot Debug，Android及ENet实战未在本轮验证。

## 3. 集成交接

- [x] 3.1 保存证据后清理Godot/代理/临时容器专网，主代理复核1075不变与零残留，更新权威规格/索引入口和原进度页，记录Android候选仍待整合。

  `verification/qa-r3/root-final-cleanup.json`独立复核三轮容器/网络均零、端口与所属进程释放、18卷及证据保留、1075六服/APK不变，源码仍等于已验候选。主规格两条已同步，55项spec校验0失败，本change严格校验通过；文档索引、原看板/阶段D/首日卡已更新并回读，明确Android待M23整合。历史两条其他spec的Purpose警告不扩大本轮修订范围。

## Workflow follow-up

- 验收与规格同步后归档；下一M23候选仅消费本轮已签收的源码差异。
