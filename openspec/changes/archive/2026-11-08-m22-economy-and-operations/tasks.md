- [x] 1.1 30／90 天经济和纯 PVE 成长回归，记录发现、调整与复验。
- [x] 1.2 真实并发与持续运行，统计容量、延迟、资源占用和任务锁。
- [x] 1.3 恢复点、含进行中场次的完整备份、还原及版本回退演练。
- [x] 1.4 场次诊断、受限补偿和脱敏审计。
- [x] 1.5 主代理复验，汇总进入内测的已知问题。

1.1 部分复验：[纯 PVE 30／90 天](verification/root-pure-pve.log)。按每日一次低战损胜利投影，到第 30、90 天闲置件同为 24，累计转化 6、66 件；其余情景另见下方最终复验。

主验已独立运行原始五类情景。30／90 天库存均可从收支解释；旧指标 resource_overflow 把满仓未领、仍保存在营地的资源重复统计，不能作已销毁量。须用营地未领余额、领取失败／部分领取及最终损失分项重测。[原始运行](verification/root-five-scenarios.log)。

主验已独立复跑修订后的指标。长期占地 90 天实际收取 80、期末可领 8、满仓拒领 46 次、部分领取 42 次；探索结算真正舍弃结构 330、零件 51。详见 [五种情景](verification/root-five-corrected.json)。[补偿主验](verification/root-operations.log)覆盖同一请求五次并发、单笔入账、经办角色与审计。

主验五卷独立恢复后，在途机体从检查点继续，待投战果只产生一次收益，两台机体解锁；旧镜像可启动匹配备份。另发现该版回退差异仅统计物资流水，一笔已发货方案栏以及随后退款都漏报，已在下方最终复验关闭。[恢复演练](verification/root-backup-drill.log) · [商店回退对照](verification/root-shop-reconciliation-before.log)。

开发自测与复验入口见[开发记录](verification/report.md)和[内测运维手册](../../../../docs/internal-test-operations.md)。

最终复验：同一方案栏订单在两个恢复点间分别显示创建、付款、发货和退款。涵盖待发货、旧库兼容、权益异常与脱敏输出。[原复现重跑](verification/root-shop-reconciliation-after.log) · [状态复验](verification/root-shop-extended.log)。

主验在本机 4 个独立房间同时发送真实指令，239.4 秒内 4/4 胜利、重连、各有一次终局、机体任务解锁。942 个成功采样的指令确认 p95 为 66 ms；另有 3 条超 2 秒。151 次档案 HTTP 请求 p95 为 936.06 ms，与同机备份及开发并行。该值作为内测已知延迟风险，未核实其成因；尚未测得更多并发容量。[原始负载与时延](verification/root-soak.json)。
