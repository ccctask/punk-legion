- [x] 1.1 测试商品表、购买与权益页，公开已确认的便利性与购买上限。
- [x] 1.2 工坊免费 6 套和加购上限 2 套，历史兼容、缺件、版本更新与整理。
- [x] 1.3 同机体外观预览、装备、战斗呈现与数值对照。
- [x] 1.4 可恢复模拟订单、取消／失败、重复或并发成功、补发、退款与重购。
- [x] 1.5 主代理复验移动端显示、测试订单账本并归档。

[复测步骤](../../../../docs/player-profile.md#m21-工坊模拟商店) · [真实双席营地战与持续入账](verification/live-pvp.log)。同一机体在真实战斗模型按完全相同输入，8 次包括初始状态在内的射击采样、炮口坐标、几何边界、数值与正式战果一致。真实营地房间双视角分别确认已购涂装，恢复后同收守方获胜战报。工坊截图 build/m21/mint.png，战斗截图与视频 build/m21/pvp/。
主验 Android 15 模拟器 960×540 通过可操作工坊入口下单、装备薄荷、退出游戏再登录读取待付款的方案栏订单、发货容量 6→7、退款 7→6 及单独退涂装后恢复黄铜。商店使用测试点；截图取自已验签的移动调试包。[重登](verification/android-relogin.png)、[扩容](verification/android-seven.png)、[方案退款](verification/android-slot-refunded.png)、[涂装退款](verification/android-paint-refunded.png)。另验 [服务重启与原方案恢复](verification/root-slot-restart.log)。
