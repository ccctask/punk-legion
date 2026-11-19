## 1. 战损与恢复
- [x] 1.1 可信终局的停机和剩余耐久损失更新机况，装配与 ID 保留，已损坏机体无法通过调度或入场。
- [x] 1.2 单工位维修，服务器计时，扣费与行程同事务。工坊维修有独立记录，重复请求沿用同一收据。
- [x] 1.3 档案中选中机体 → 检修与回收，可入列、申请救援、预览回收报价并确认。已回收机体的历史留档。
- [x] 1.4 [枯竭、并发、服务端时间与 v5 旧档迁移](verification/recovery.log)、[真实双席战损及 Godot 界面操作](verification/room-repair.log)、[旧机库回归](verification/workshop-regression.log)。
- [x] 1.5 主代理独立验收

开发参数为每账户一个维修工位，耗 1 结构材料与 1 通用零件、30 秒；救援配额 10 分钟恢复。救援修复后机体回收残值为零，最末机体保留。枯竭救援的出征凭证独立于能源材料，取消只返还凭证。旧档迁移保留此前的机况与出发占用，新战损从本模块启用后记账。

从根目录运行 `python services/profile/check_recovery.py`。联机带界面操作回归运行 `python services/profile/check_service_record.py --godot <Godot可执行文件>`，使用隔离数据库和临时双进程房间。

独立通过 [双席实战至维修界面](verification/root-ui.log) 和 [停服跨过真实维修期限](verification/root-offline.log)。检修完成后同一机体重新获得入场券，重试原付费请求复用原收据。安卓调试包已验证 v2/v3 签名，本模块界面操作在桌面复验。
