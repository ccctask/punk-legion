- [x] 1.1 核对 1008、1007 固定入口和双地接口差异；配置下一版标识、更新门槛与可重现发布环境。
- [x] 1.2 M17 修订通过后冻结、构建、校验同签名的 1009，在隔离服务复跑升级及数据、双地路由、进行中场次与旧入口拒绝检查。
- [x] 1.3 主代理在签名包覆盖升级、重登和进基地命名，进入两个对应营地；核对服务、五路房间、旧版提示及恢复点。
- [x] 1.4 实际上线与复验，更新操作说明、资料空间和安装包链接。

候选准备与隔离端口见 [1009 切换前检查](verification/preflight.md)。

签名与隔离场次验收见 [候选接口与资产](verification/candidate-1009.json)、[1008 在途场次恢复及回执](verification/migrated-match.json)。

主代理从签名 APK 校验签名证书、哈希、双 ABI、首屏/诊断/港口编译入口、服务端口与 420 项冻结来源。在原 1008 安装上覆盖 1009，首次安装时间仍为 08:54:16。隔离环境新玩家在基地给首机命名 BrassBud，旧号保留 BetaCrawler，并由地图进入带线圈的港口和黄铜转运场。签名包实测时两处使用真实日程，闭窗不能登记。旧场续局和双地开窗争夺分别在隔离服务器与 M19 安卓包验证。[签名](verification/root-signed-1009.json) · [新玩家](verification/root-mobile-new-home.png) · [线圈港](verification/root-mobile-port-console.png) · [黄铜](verification/root-mobile-brass-console.png) · [跨版本原场次](verification/migrated-match.json)。

正式切换后核对五个 ENet 入口、三个 TCP 地址的协议 3/4/5，旧版本提示以真实 Android 原包直连原端口检查。使用旧账号重新登录正式 1009 回到原基地、机体及指引。正式库 5 个账号，SQLite 完整性正常，末次五卷快照和回退演练保留。安装手册、营地手册、文档索引和研发路线图已同步。[正式基地](verification/root-mobile-formal-home-ready.png) · [1007 升级屏](verification/root-mobile-original-1007.png) · [1008 升级屏](verification/root-mobile-original-1008.png) · [正式协议矩阵](verification/root-live-gates.log) · [正式握手](verification/root-live-enet.log)。
