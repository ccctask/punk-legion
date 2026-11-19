- [x] 1.1 实现个人机体分组与四项战前可选行为，接入机库，支持旧机体和无设置直接出战。
- [x] 1.2 将选择冻结到权威部署，验证移动、索敌、护卫、低耐久回撤及手动指令优先级。
- [x] 1.3 在真实玩法的战中快捷选择本人职责组，保留总预算、固定塔规则和席位范围；覆盖重连与旧进行中任务。
- [x] 1.4 主代理用同场反事实、双席与安卓触控实测，保存录像、指令与结果。

开发验证与影片见[报告](verification/report.md)。

主代理从独立工程副本（空导入缓存）启动三个真正的桌面客户端及隔离 Compose。两个不同账号各自只选回本机支援机，空前排不自动回选，断线重连后归属一致；单人双机也分别通过支援和全选。见[三端结果](verification/root-network-roles.json)与[单人双机操作录像](verification/root-network-roles.mp4)。安卓触控独立复测另记。

主代理对同配置、同位置的两个靶实测：设为最近时近靶 70→61，设为残血时残血靶 16→7，另一靶各自维持入场耐久。安卓独立 QA 包从正常装配台选择双足，8 台共 24 点；实际触摸前排显示 0、全队显示 8、火力显示 8，向地图中继下达移动后可见机群到达并交战。不同账号与重连在上述桌面真实网络房间核对。[索敌对照](verification/root-counterfactual.log) · [空前排](verification/root-device-empty.png) · [全队](verification/root-device-all.png) · [火力](verification/root-device-fire.png) · [实际到达](verification/root-device-relay.png)。
