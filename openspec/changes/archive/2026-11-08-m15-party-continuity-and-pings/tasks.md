- [x] 1.1 把队伍和出击生命周期分开，实现两局间留队/离队/重连、重新准备和独立结算。
- [x] 1.2 正常客户端支持从结算收工或留队换机；添加队伍职责概览与限流的战场建议。
- [x] 1.3 两真实客户端同队连续胜利，途中重连，局间换成各自制造的备用机，第二局后收工。见[双屏实录](verification/consecutive.mp4)、[日志](verification/dev-two-rounds.log)、[账本回归](verification/continuity-ledger.log)、[队长战史](verification/seat-0.json)和[队员战史](verification/seat-1.json)。
- [x] 1.4 主代理独立检查两局录像、四份个人回执、标记与真实指挥的区别，并更新内测说明。

主代理独立启动两名新玩家，在真实隔离档案及 ENet 上同队连胜两场。服务端时长 191.35 秒、193.40 秒；两次出发的公共场次不同。四张个人回执互异，换机后的四台机体各只有一次胜利。两端均收到队长标记，独立规则复验其不改队友指令序号，保护间隔和到期清除通过。按脚本重新验证自愿留队、收工无后续扣费和旧回执重投。已解码[双窗口录像](verification/root-two-rounds.mp4)，可核对[四份回执](verification/root-two-rounds.log)、[席位一](verification/root-seat-0.json)、[席位二](verification/root-seat-1.json)与[续队账本](verification/root-continuity.log)。
