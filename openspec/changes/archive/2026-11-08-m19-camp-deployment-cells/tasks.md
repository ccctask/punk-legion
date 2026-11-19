- [x] 1.1 修复真实营地部署，保留固定塔与预算/战斗规则。
- [x] 1.2 验证双方合法格、同预算攻守胜负矩阵与 ENet 胜负。
- [x] 1.3 主代理复验。

12 台旧守军中 4 台生成于障碍，新位置含 1/6/12 台、固定塔、中立和空营，均分格可达；旧存档的障碍位置可恢复。原 M04 同预算镜像测试脚本跑完 64 场，营地 32 场攻胜 11、守胜 21，轻重攻方各有胜负。真实 ENet 经中立夺地、守方到场、攻方撤退、无人防守易主和审核重启。规则保留原核心半径、16 秒累计、时限、平局守方及统一射程。[原障碍位](verification/before.log) · [布阵与旧档](verification/formation.log) · [原矩阵重跑](verification/after.json) · [ENet](verification/enet.log) · [实战录像](verification/live/live-attack.mp4)。

主代理重新运行原始 64 场同预算矩阵，32 场中继逐项相同，32 场营地由全守胜变为进攻 11 胜、防守 21 胜。满编 24 台均在可通行格。另建隔离 Compose 复验三场真实 ENet 对抗、双方窗口、固定驻防、空营易主及房间重启后的同一回执。[原矩阵重测](verification/root-after.json) · [真实房间](verification/root-live.log)。
