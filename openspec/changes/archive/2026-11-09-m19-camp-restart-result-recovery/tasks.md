- [x] 1.1 Handle malformed terminal and checkpoint records at startup and during normal redelivery.
- [x] 1.2 Verify fresh real rooms across restart, authoritative expiry or recovery, unrelated new admissions and idempotent settlement.

主代理使用全新数据库和场次重跑了 7 次房间重启。已确认的移动指令序号 1 在恢复后保留；原结束时间与补交一致。同一终局两次投递只计 1 场，双文件损坏场自然到期，同时另一营地完成结算。临时 HTTP 服务已停止，UDP 已释放。[独立联机实测](verification/root-live.json) · [四种终局文件损坏对照](verification/root-checkpoint.json)。修复尚未并入签名版 1064。
