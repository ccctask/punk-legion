## 1. 开发和验收
- [x] 1.1 容器内权威战斗、所有权、准备与重连
- [x] 1.2 从双客户端正常入口操作战斗并查看结算
- [x] 1.3 可复现的双端测试，记录断线恢复与唯一结果
- [x] 1.4 主代理独立启动两个图形进程，连接本机 24581/UDP 的独立 Compose。场次 38eb9268b29e679c8a7de014，双方结果同为 eliminated，SHA256 相同。见 [客户端一](verification/1.log)、[客户端二](verification/2.log)。

## 开发自测记录

- Godot 4.6.1，Windows 双独立渲染进程，OpenGL Compatibility，Linux Godot Docker Compose。两端从试车台按准备进入，分别控制六台机组，点场地移动、点敌机集火。测试还验证跨席位混合选择和重放序号被整条拒绝。
- 场次 `834fbffc2a60c1ae71c876d3`。一席断线后从 tick 100 恢复到 125，两席所见最终结算 SHA-256 同为 `1d5d226d482bf6fa96de1f2d3638ae1acd36a3093c534fc87174216fc92634d9`。二席结算后再断线重连，仍收到相同结果。两端返回试车台并主动释放席位。客户端错误输出为空。
- 复测先运行 `docker compose up -d --build room`，保持两席空闲。PowerShell 执行 `./tests/exercise-smoke.ps1 -Godot <Godot控制台可执行文件> -Windowed`。如使用其他映射端口，设置客户端环境变量 `ROOM_PORT`。日志目录由脚本输出。Android 触控实机和持续弱网质量需要独立验证。


归档后独立复验。两个 Godot 窗口连接同一独立容器。双方完成移动和集火，一席中途断线重连，双方取得同一结算摘要。[完整录像](../../../../docs/evidence/m05-two-clients.mp4) · [两端记录](../../../../docs/evidence/m05-two-clients.log)
