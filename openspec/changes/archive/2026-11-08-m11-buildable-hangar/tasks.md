- [x] 1.1 建造及持久化，复用已发布资源组合军营外观。
- [x] 1.2 从设施打开机库、显示任务状态并按方案制造，兼容旧档。
- [x] 1.3 自有/访客/重复请求、工坊与资产画面回归，记录文档。
- [x] 1.4 主代理独立验收。

运行 python -B services/profile/check_hangar.py --godot <Godot> --capture <截图>，从真实投影点击建造、进入本人机库、保存方案并制造第二台，再返回原基地。另验两栋设施与旧账号容量、道路/重叠、费用去重、免费移动、真实驻防互斥、访客及重启。[自测记录](verification/ui.log) · [地图截图](verification/hangar.png) · [设施手册](../../../../docs/player-profile.md#私人基地复测)。

主代理从新档自行复跑图形客户端点击实际地块建造军营，在该设施打开机库并按方案制造第二台，然后回到原基地。服务器复核重复扣费、容量、驻防互斥、访客权限及重启。[主验截图](verification/root-hangar.png) · [运行记录](verification/root-hangar.log)。
