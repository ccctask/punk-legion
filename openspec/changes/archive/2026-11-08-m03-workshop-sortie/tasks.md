## 1. 可玩闭环
- [x] 1.1 试车台导航和正常离席，实际 UDP 服务端输出 ROOM_JOIN seat=1 和 ROOM_RELEASE seat=1
- [x] 1.2 工坊保留配置，部署真实有限小队和编队摘要
- [x] 1.3 M04 开局使用部署并提供返程，6 台各 155 HP 的钻头机共 24 点，逐实体核对
- [x] 1.4 Godot 4.6.1 从正常场景测试联网及离线入口、非法组合禁止出击、撤退和两个返回按钮。[试车台](range.png) 和 [工坊](workshop.png) 为 960×540 实际渲染。
- [x] 1.5 主代理独立验收通过。独立连接 compose 的房间并在离线状态分别重测，从试车台启动，检查非法组合、6 台钻头机实装、撤退返程与重新进入试车台；服务端确认 ROOM_RELEASE。已查看 960×540 工坊与试车台截图。

复测用 Godot 加参数 `--headless --path game --script res://loadout/tests/sortie_flow.gd`。对运行中的独立测试房间追加 `-- --with-room`，并给双方设置同一 ROOM_PORT，检查服务端的 ROOM_RELEASE；测试进程会短暂使用一个席位。预期输出 SORTIE_FLOW_OK。

