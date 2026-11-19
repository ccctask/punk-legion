## 1. 宿主解析前置

- [x] 1.1 子代理交付受限WPR/已知线程/流式解析与异常清理工具；主代理先审入口再核一次≤5秒实测原始数据，逐payload验证CSwitch/ReadyThread、时钟、零丢事件及Running对GetThreadTimes误差，明确通过或失败证据。

## 2. 身份前置

- [x] 2.1 仅在1.1实际通过并获主代理放行后，至多一次≤10分钟无游戏AVD，用只读QMP与Windows线程/guest拓扑交叉验证4vCPU身份；主代理复核原始查询，若未放行或不可用则记录具体原因，不宣称映射通过。

## 3. 集成收尾

- [x] 3.1 主代理独立复核本轮追踪/子进程/设备/专属端口零残留及1075不变，将工具可用范围、未验门槛和后续停止条件同步原进度页与M06证据，保持整体10/13。

**结果：调查流程收口，工具使用门槛失败，不能接入游戏采集。** 1.1唯一采集实际header7.7000175秒，原≤5秒不通过；已独立复算payload/CPU局部证据，不把lost0摘要代替两个collector完整覆盖。第二配置静态被拒绝，未重采。2.1按条件未放行，已记录原因，vCPU运行映射仍未验证。3.1独立确认WPR/全部登记进程/四端口零残留、未起设备或新容器、1075未变。此处checkbox表示完成指定调查/判定/收尾，不表示失败门槛转绿。整体M06仍10/13。

证据：[主验结论](verification/root-review.md)、[独立CPU复算](verification/root-cswitch-result.json)、[未通过的设备门槛](verification/root-etl-gate.json)、[独立最终收尾](verification/root-final-audit.json)。

## Workflow follow-up

- 依据真实正反证据收口并归档本工具前置任务；归档不代表M06性能出口通过。
