## 1. 生产与研究
- [x] 1.1 三类产线与服务器时钟、有效供能
- [x] 1.2 仓储、离线封顶、领取与对账
- [x] 1.3 基地领取和有限研究、工坊联动
- [x] 1.4 可控时间、断电与并发回归
- [x] 1.5 主代理独立验收

主代理在独立 HTTP 服务、临时 SQLite 和可控服务器时钟下运行 check_production.py --godot。Godot 真实流程返回 PRODUCTION_UI_PASS base/claim/research/owned_workshop/drill_robot，领取后完成研究，真实机体工坊可制造钻头机。短时、24 小时、3 天、7 天、容量、断电、并发与重启核对通过。

子代理：python -B services/profile/check_production.py --godot <Godot程序> 输出 PRODUCTION_PASS、PRODUCTION_UI_PASS。真实工坊制成钻头机体；长离线在仓储和实际库存均富余的测试中仅得 36 个材料（连续冶炼 12 小时）。M11 的预览显示当前版本，确认成功改为明确已保存与扣费，并禁用确认按钮，实际 Godot 窗口的五次建造均通过反馈回归。

