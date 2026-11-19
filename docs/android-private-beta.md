# 安卓独立内测

开发验收按[测试数据与数据迁移规则](../AGENTS.md#测试数据与数据迁移)新建独立服务卷和账号，以当次版本生成场次与进度。下文以往版本的升级、存档恢复和回退记录属于历史操作，不能作为新版本的默认验收项。

适用于 Windows 构建机、本机 Docker Desktop 和 Android Studio 模拟器。内测负责人保管签名与测试账号，开发代理维护构建工具和版本记录，主代理独立复核候选 APK。这里的测试账号、容器、数据卷与调试环境分别管理。

## 1084 局域网客户端（最新可用，未安装手机）

2026-11-18：[1084 APK](../build/private-beta/PunkLegion-beta-1084.apk)／[清单](../build/private-beta/PunkLegion-beta-1084.json)已按[稳定发布根签](../build/private-beta/operations/client-release-1084/ROOT-ACCEPTANCE.md)及[登记](../build/private-beta/operations/client-release-1084/registration.json)发布。54,226,865 bytes，APK SHA256 `2e526aa481d14b5c574ad8c8d931f9b85f6a7888dc771cbdde824cf8a9df793e`；542实体冻结源manifest `4ea595eacfc9452b31d9cdc447e165f5c271e78e20543430f6f119ddbf6c47bd`。原包名／证书、HTTP协议5和实时协议3保持，地址192.168.31.170、TCP33380与原五UDP不变；共用原R2六服，不升级后端或迁移数据。

正常页面自动读取／恢复，保草稿和原经济意图，真实异常才提供恢复。已验真实首胜实体钻头同UUID自动可见及装机，材料与配方另记。Android实际HOME停读、同PID恢复及新实体可见按必要切片签收；F原整场false及末尾工坊native切页未运行保留。此发行APK仅独立产物审计，没有1084手机安装、新P95或听感结论；运动顺滑仅研究，UI重设计未实施。安装和限制见[当前交付](current-playable-delivery.md)。原手机仍1083、同机模拟器默认1082，不能把发布当已替换设备。

## 1082 模拟器默认包与1083手机局域网变体（既有设备与历史证据）

原签名[1082 APK](../build/private-beta/PunkLegion-beta-1082.apk)与[原清单](../build/private-beta/PunkLegion-beta-1082.json)已登记；客户端2345源、服务端366e/3cea与Profile b0eded分列于[稳定索引](../build/private-beta/current-playable.json)。[R2当前双地址六服由root接管](../openspec/changes/m23-usb-phone-lan-install/root-lan-result-review.md)，永久配置在operations/1082-delivery-r2和ACK1 snapshot；同版本沿用本轮a2空卷正常生成的数据，不导旧库。

安装、账号/私人基地入口、音量及正常启停统一从[当前交付维护](current-playable-delivery.md)进入。1082的10.0.2.2入口仍为同机模拟器默认。[1083 LAN APK](../build/private-beta/PunkLegion-beta-1083.apk)与[原清单](../build/private-beta/PunkLegion-beta-1083.json)绑定192.168.31.170，已[签收指定USB手机安装/当前基地画面/手机HTTP连接](../openspec/changes/m23-usb-phone-lan-install/root-phone-install-result-review.md)；用户自行注册和命名，不代操作。手机需在可达的同一WiFi/局域网，电脑保持该IP及服务运行；未提供公网包。全场/满编P95为19.8101/20.1632ms，118.0593/1066.0949ms两次长帧及未知因果保留；[原始根签](../openspec/changes/m06-normal-candidate-frame-capture/verification/root-current-pump1082-a3-result-review.md)不代真机或所有设备通过。手机UDP玩法、实体性能及声音听感不在本次安装/HTTP签收中；实体性能和听感由负责人试玩终验，未执行。

以下1077及更早条目为历史，不代表当前后端仍在线或当前性能结论。

## 1077 本地内测（历史）

**历史客户端。** 修复公开营地提醒在点击切屏时的按钮释放问题。已签正式包复制至试玩路径，完整515项冻结源与候选一致。[下载1077](../build/private-beta/PunkLegion-beta-1077.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1077.json) · [当前客户端与后端索引](../build/private-beta/current-playable.json) · [交付签收](../openspec/changes/archive/2026-11-13-m23-defense-alert-input-lifecycle/verification/root-client-delivery-review.md)

客户端1077继续连接原**1076-delivery-r2**六服，协议5及333xx端点保持；未重建或迁移后端。服务维护继续从下文r2的runtime/OPERATIONS进入。原runtime的1076包哈希属于历史服务交接，当前客户端以新索引为准；rc-1077客户端快照不能替代实际后端源和镜像。

本轮有限原生验收使用同核心、仅端点和签者不同的隔离派生包：两次真实提醒进入正确黄铜指挥台并返回，启动到收尾过滤日志未出现目标生命周期错误。保留兼容恢复与shader警告；不代表所有界面、设备或完整正式端点矩阵重验。测试模拟器、ADB、临时两容器及专网已清理，现有六服继续供试玩。[原生签收与限制](../openspec/changes/archive/2026-11-13-m23-defense-alert-input-lifecycle/verification/root-native-result-review.md)

性能沿用下文已测限制：整场/满编交火P95为77.455/80.811ms，超过33.333ms，M06仍未通过。按负责人2026-11-14安排，真机检测与声音系统最终验收在完整可玩版交付后由负责人执行，未执行、不代签且不作为当前开发阻塞；模拟器必要验证继续。真人首日观察仍以实际证据登记。

## 1076 本地内测

**历史客户端，r2后端继续沿用。** 合作大厅首次状态读取前保护准备和出发操作；临时失败最多自动重试两次，耗尽后手动刷新，登录过期停止请求。后台/关闭不重放旧操作，准备已处理但丢回复时仅向服务端读取核对。[下载 1076](../build/private-beta/PunkLegion-beta-1076.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1076.json) · [安卓功能签收](../openspec/changes/archive/2026-11-12-m23-lobby-recovery-android/verification/root-r5-functional-review.md)

模拟器档案 TCP 33380，演习、独行、合作、营地、秘宝 UDP 依次为33371、33372、33373、33374、33376。当前服务修订为 **1076-delivery-r2**，整合成功GET的合作大厅／泵房／工厂三路有限连接复用；原正式APK和515冻结源不重编、不重签。六项服务由root接管，实际资源台账为[runtime.json](../build/private-beta/operations/1076-delivery-r2/runtime.json)，维护从[OPERATIONS.md](../build/private-beta/operations/1076-delivery-r2/OPERATIONS.md)进入；运行配置均在稳定目录，归档任务不影响维护。原1076-r5六容器及专网已退役，命名卷保留。

本服务修订使用本轮新卷／三新号的正常泵房验证：三人各6台12点，手机245秒通关，三人各一次费用和个人结果、机体释放及累计对账通过；同场采样后接替核138源、同轮数据摘要、日程、协议及五路ENet均通过。接替复验删除12个候选／旧容器及旧专网，当前仅保留新六服供试玩，共享服务不变。[根签收](../build/private-beta/operations/1076-delivery-r2/handoff-v2/root-acceptance.md) · [三席及整场记录](testing/runs/2026-11-13-m23-service-bundle-r2.md)。未导入旧环境数据库；本轮同版本重启沿用本轮数据。

原1076-r5验收复用同包的R3六故障证据，新库两名玩家正常参战，双方精确指令序号各1，分别主动撤退；每人一次能源费用和个人结算、机体解除派遣/参战累计1，手机正常收工冷启后账目不变。当时设备与peer已关闭，交接替换及退役共删除12个容器、1075专网1个，命名卷和共享服务保留。这些为历史范围，不与本次服务修订重复计数。[历史执行报告](../openspec/changes/archive/2026-11-12-m23-lobby-recovery-android/verification/test-r5-report.md) · [历史运行交接](../openspec/changes/archive/2026-11-12-m23-lobby-recovery-android/verification/handoff-r5/result.json)

范围为模拟器功能。历史OS字节基线缺失、原生日志为空及早期设备退出警告保留。当前已取得有效整场248.345秒／覆盖1.0的采样，但全场P95 77.455ms、满编交火P95 80.811ms，超过33.333ms门槛，M06性能仍未通过；不能归因为单一模型／宿主瓶颈或推断实体机表现。实体机、真人首日体验及人耳试听仍待实际验证。服务修订的有限改善不证明全部GET零失败或底层连接故障已治愈。

## 1075 本地内测

**历史版本，专属服务已退役。** 工坊成功保存方案和制造机体时，服务端使用有界的六秒连接复用窗口，原编号确认与单笔扣费逻辑保持。模拟器档案 TCP 32980，演习、独行、合作、营地与秘宝 UDP 依次为 32971、32972、32973、32974、32976。[下载 1075](../build/private-beta/PunkLegion-beta-1075.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1075.json) · [安卓主验](../openspec/changes/archive/2026-11-11-m23-workshop-delivery-android/verification/root-review.md)

签名正式包的新号在约八秒观察点确认了三版方案和三次制造，无额外手动核对；冷启重登保持四台机体、七条收据和 3 结构／3 零件／2 能源，空名称拒绝后仍可编辑。观察可能包含已有的自动核对，不等于逐 HTTP 首答耗时，也不证明间歇性故障已经消除。

当时1075六服由主代理接手提供本机试玩。交接前后档案 HTTP 和五路 ENet 均通过，1074 六个容器及专属网络已删除，六个命名卷保留；测试包、模拟器、专属 ADB 和辅助进程已清理。现由1076接替，1075六容器及专网已删除，卷保留。[1075历史交接记录](../openspec/changes/archive/2026-11-11-m23-workshop-delivery-android/verification/handoff-ops.json)

## 1074 本地内测

**历史版本，专属服务已退役。** 工坊保存方案或制造机体后，如果回包中断，会沿用原编号自动核对一次。仍待确认时，顶部保留手动核对入口，库存标为「上次读取」。重登后进入原工坊可继续核对。[下载 1074](../build/private-beta/PunkLegion-beta-1074.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1074.json)

安卓实测中，同一制造收据的前两次回包被丢弃，冷启后第三次取回原收据，材料只扣一次。恢复普通服务后，保存第 2 版方案经历多轮待确认，最终手动核对成功，账本只有一笔保存记录。普通服务上早先失败的回调没有采样，间歇失败的原因仍待定位。

[安卓独立主验](../openspec/changes/archive/2026-11-10-m23-workshop-recovery-android/verification/root-review.md)记录当时的实际画面、原单账本与清理。

后续[普通直连诊断](../openspec/changes/archive/2026-11-10-m09-android-direct-confirmation-diagnosis/verification/root-review.md)捕获两次制造服务成功写回、手机却收到零字节的同次记录，确认失败发生在收据校验之前。诊断服保活后原单恢复成功，反切原策略未再现；当时没有改变1074的服务策略。

开发源码接受的[两路成功写入有限交付变更](../openspec/changes/archive/2026-11-10-m09-workshop-write-delivery/verification/root-review.md)现已整合1075。逐请求鉴权及关闭边界已独立复验；此前无日志客户端的三阶段观察为5/6、6/6、6/6，反切没有复现，不能声称间歇故障消失。

## 1073 本地内测

**历史版本，专属服务已退役。** 新号命名后先带现成机体打锈轨，首胜回营即可收工，愿意继续可装钻头与造机。私人基地正式预警为 3 小时。[下载 1073](../build/private-beta/PunkLegion-beta-1073.apk) · [安卓主验](../openspec/changes/archive/2026-11-10-m23-first-battle-guide-android/verification/root-review.md)

本轮制造出现过确认失败，服务端实际只扣一次，后续同编号恢复成功；M09已定位一次连接建立失败，底层连接原因及确认体验仍待修订。原正式包恢复后机体、部件和库存重登一致。

## 1072 本地内测

**历史版本。** 私人基地的防守战报首屏显示实际损失；点受损守军查看原机维修报价。失守后整备 48 小时，整段离线者回归另获 24 小时。档案 TCP 32380；演习、独行、合作、营地、秘宝 UDP 32371、32372、32373、32374、32376。[下载 1072](../build/private-beta/PunkLegion-beta-1072.apk) · [安卓主验](../openspec/changes/archive/2026-11-10-m23-base-defense-report-android/verification/root-review.md)

## 1071 本地内测

**历史版本。** 在工坊制造铆钉连发器和测绘雷达，装上侦察轮式机体即可在秘宝区域提前辨识密封物资。贴近货箱拾取，回到撤离区带出。档案 TCP 32280，演习、独行、组队、营地、秘宝 UDP 32271、32272、32273、32274、32276。[下载 1071](../build/private-beta/PunkLegion-beta-1071.apk) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-survey-scout-android/verification/root-review.md)

## 1070 本地内测

**历史版本。** 在机库给自己的机体设置两位编号。好友页可查看并保存带可选部件的方案。安卓模拟器档案 TCP 32180，演习、独行、组队、营地和秘宝依次使用 UDP 32171、32172、32173、32174、32176。[下载 1070](../build/private-beta/PunkLegion-beta-1070.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1070.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-numbered-fleet-android/verification/root-review.md)

## 1069 本地内测

**历史版本。** 在私人基地建造雷达远征站并供电，点站房可进入周边探索、世界地图或查看袭击情报。机库会将当前底盘标为「已装备」，选中其他底盘后才显示费用。安卓模拟器档案 TCP 32080，演习、独行、组队、营地和秘宝依次使用 UDP 32071、32072、32073、32074、32076。[下载 1069](../build/private-beta/PunkLegion-beta-1069.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1069.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-radar-station-android/verification/root-review.md)

## 1068 本地内测

**历史版本。** 在机库更换轻型轮式底盘后，从基地指引进入锈轨回收场。首胜领取钻头，再装回同一台轮式机。安卓模拟器档案 TCP 31980，演习、独行、组队、营地和秘宝依次使用 UDP 31971、31972、31973、31974、31976。换装成功后若当前底盘仍显示库存不足，可通过「当前 轻型轮式」和机体属性核对实装。[下载 1068](../build/private-beta/PunkLegion-beta-1068.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1068.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-wheel-chassis-android/verification/root-review.md)

## 1067 本地内测

**历史版本。** 在仓库制造铆钉盾板并给履带机装上，进入战场后可把盾机和维修机编成一组。点组名选中成员，再点地图下达命令。短暂断网后可接回原场。模拟器档案 TCP 31880，演习、独行、组队、营地和秘宝依次使用 UDP 31871、31872、31873、31874、31876。[下载 1067](../build/private-beta/PunkLegion-beta-1067.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1067.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-guard-groups-android/verification/root-review.md)

## 1066 本地内测

**历史版本。** 在私人基地建光学研究站，可研究、制造战术目镜并为原机换装。清除客户端数据后，可用游戏内恢复码重设密码并回到原基地。安卓模拟器档案 TCP 31780，演习、独行、组队、营地和秘宝分别使用 UDP 31771、31772、31773、31774、31776。[下载 1066](../build/private-beta/PunkLegion-beta-1066.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1066.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-optics-account-android/verification/root-review.md)

## 1065 本地内测

**历史版本。** 开放南地后，可从私人基地进入旧武器库、携箱撤离并把首胜烟囱炮臂装到原机体上。部件仓满时可腾位后补领。在公开地图点选有主的营地，可以查看营主的工坊名片与其主动公开的铭牌。营地服务重启后可从有效检查点恢复终局。安卓模拟器档案 TCP 31680，演习、独行、组队、营地及秘宝分别使用 UDP 31671、31672、31673、31674、31676。[下载 1065](../build/private-beta/PunkLegion-beta-1065.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1065.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-armory-and-camp-recovery-android/verification/root-review.md)

## 1064 本地内测

**历史版本。** 从私人基地进入封闭工厂护送、应对蜂群或响应黄铜转运场回防告警。机库换装遇到首答中断时会自动取回原收据。模拟器档案端口 31580；演习、独行、组队、营地及秘宝分别使用 UDP 31571、31572、31573、31574、31576。模拟器已实测。宿主机断电时营地终局写入的恢复修复在 M19 单独验收。[下载 1064](../build/private-beta/PunkLegion-beta-1064.apk) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-factory-swarm-android/verification/root-review.md)

## 1062 本地内测

**历史版本。** 私人基地失守后可点受损冶炼炉或车间抢修，也可等 10 分钟免费恢复。在机库选一件备件即可对照整机耐久、移速与指挥点。当前包若未收到换装回执，滚到工坊底部点「重试上次请求」。模拟器档案端口 31380，演习、独行、组队、营地及秘宝分别使用 UDP 31371、31372、31373、31374、31376。[下载 1062](../build/private-beta/PunkLegion-beta-1062.apk) · [发行清单](../build/private-beta/PunkLegion-beta-1062.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-android-facility-and-refit/verification/root-review.md)

## 1061 本地内测

**历史版本，专属服务已停止。** 三个秘宝地点各有独立地标和地面。安卓模拟器在雾钟岔道完成双人匹配、携货和撤离。模拟器档案端口 31280，演习、独行、组队、营地及秘宝分别使用 UDP 31271、31272、31273、31274、31276。[下载 1061](../build/private-beta/PunkLegion-beta-1061.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1061.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m02-android-treasure-dioramas/verification/root-review.md)

## 1060 本地内测

**历史版本，专属服务已停止。** 秘宝场次中本人带货撤离可触发加固锅炉打捞。整备显示机会及仓满提醒；终局与机库可用部件登记短号核对同一实物。模拟器档案端口 31180，演习、独行、组队、营地及秘宝分别使用 UDP 31171、31172、31173、31174、31176。[下载 1060](../build/private-beta/PunkLegion-beta-1060.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1060.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m24-android-rare-salvage/verification/root-review.md)

## 1059 本地内测

**历史版本，专属服务已停止。** 好友协防机在黄铜转运场或线圈港实际受损后，原机主送修只需 1 个通用零件。机况与维修工位随所选机体显示应付材料和缺口。模拟器档案端口 31080，演习、独行、组队、营地及秘宝分别使用 UDP 31071、31072、31073、31074、31076。[下载 1059](../build/private-beta/PunkLegion-beta-1059.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1059.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m20-android-aid-repair-beta/verification/root-review.md)

## 1058 本地内测

**历史版本，专属服务已停止。** 机库较大时，成功登录和野袭状态读取使用限时保持连接。已建配电柱的基地可以打开野袭预警与战后回放。模拟器档案端口为 30980，演习、独行、组队、营地及秘宝分别使用 UDP 30971、30972、30973、30974、30976。[下载 1058](../build/private-beta/PunkLegion-beta-1058.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1058.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-relay-defense-and-login-beta/verification/root-review.md)

## 1057 本地内测

**历史版本，专属服务已停止。** 私人基地的野袭预警会显示恢复期减免和实际来袭编队，战后从基地防守入口可回放同一场。模拟器使用档案端口 30780，演习、独行、组队、营地及秘宝分别使用 UDP 30771、30772、30773、30774、30776。本轮模拟器首次登录出现三次连接失败，重启应用后登录成功；战中自动重连并取得实时战况。[下载 1057](../build/private-beta/PunkLegion-beta-1057.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1057.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-raid-pressure-beta-1057/verification/root-review.md)

## 1056 本地内测

**历史版本，专属服务已停止。** 从私人基地的公开地图选择开放的秘宝，确认阵容并进场。亲自拾取后即使超时，个人结果仍单列参与奖。退回地图后再次打开秘宝可查看上场结果。模拟器使用档案端口 30680，演习、独行、组队、营地及秘宝分别使用 UDP 30671、30672、30673、30674、30676。[下载 1056](../build/private-beta/PunkLegion-beta-1056.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1056.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-treasure-reward-android/verification/root-review.md)

## 1055 本地内测

**历史版本，专属服务已停止。** 从私人基地的菜单进入「指挥官档案与机库」，选择机体后点「查看所选机体累计战绩」，可查看参战场数、击败敌机数和为友机实际恢复的耐久。安卓模拟器连接档案服务 `10.0.2.2:30580`，演习、独行、组队、营地及秘宝分别使用 UDP 30571、30572、30573、30574、30576。[下载 1055](../build/private-beta/PunkLegion-beta-1055.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1055.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m10-robot-career-totals/verification/root-review.md)

## 1054 本地内测

**历史版本，专属服务已停止。** 安装后注册新账号，在机库确认把真实部件装上首机，回基地即可继续首玩指引。秘宝战按己方阵营播放移动、开火与低耐久声音。基地菜单可以调整音效。档案服务为 `10.0.2.2:30480`，演习、独行、组队、营地及秘宝分别使用 UDP 30471、30472、30473、30474、30476。[下载 1054](../build/private-beta/PunkLegion-beta-1054.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1054.json) · [安卓主验](../openspec/changes/archive/2026-11-09-m23-fit-audio-android/verification/root-review.md)

## 1053 本地内测

**历史版本，专属服务已停止。** 安装签名 APK 后注册新账号。从私人基地进入世界地图的秘宝争夺，可在机体服役档案查看本机参与击破的助攻，收藏后重开游戏可回到原事件。档案服务为 `10.0.2.2:30380`，演习、独行、组队、营地及秘宝使用 UDP 30371、30372、30373、30374、30376。[下载 1053](../build/private-beta/PunkLegion-beta-1053.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1053.json) · [安卓实战与高光](../openspec/changes/archive/2026-11-09-m23-treasure-assist-android/verification/root-review.md)

## 1052 本地内测

**历史版本，专属服务已停止。** 在本机安卓模拟器安装后注册新账号。基地领取正数产出即可完成当日目标，卡片显示实际所得与收据。三人泵站在服务端确认开战后显示指挥按钮。本版档案为 `10.0.2.2:30280`；演习、独行、组队、营地和秘宝使用 UDP 30271、30272、30273、30274、30276。[下载 1052](../build/private-beta/PunkLegion-beta-1052.apk) · [签名清单](../build/private-beta/PunkLegion-beta-1052.json) · [安卓实战及账本](../openspec/changes/archive/2026-11-09-m23-production-coop-android/verification/root-review.md)

## 1051 本地内测

**历史版本，专属服务已停止。** 在本机安卓模拟器安装签名 APK，启动后注册本版新账号。已登录玩家关闭游戏后重开，会读回已保存的机体和基地布局。档案服务为 `10.0.2.2:30180`；演习、独行、组队、营地、秘宝分别使用 UDP 30171、30172、30173、30174、30176。[下载签名 APK](../build/private-beta/PunkLegion-beta-1051.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1051.json) · [七次冷启动主验](../openspec/changes/archive/2026-11-09-m23-cold-base-android-release/verification/root-review.md)

## 1050 本地内测

**历史版本，专属服务已停止。** 基地保存回包中断时，原页会自动核对收据，显示本次保存版本、当前布局和实际扣料。若核对读取也失败，点「重新核对保存」。档案没有收据且原版本仍有效时，才可手动重试原操作。此次直连冷启动的首次基地同步失败，点一次「重试连接」后正常读回已保存的配电柱。[签包触屏及独立对账](../openspec/changes/archive/2026-11-09-m23-verified-base-save-android/verification/root-review.md)

在本机模拟器安装后注册本版新账号。档案地址为 `10.0.2.2:30080`，演习、独行、组队、营地、秘宝依次使用 UDP 30071、30072、30073、30074、30076。[1050 签名 APK](../build/private-beta/PunkLegion-beta-1050.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1050.json)

1049 是本轮字形复验前的签名候选，专属服务已停止。

## 1048 本地内测

**历史版本，专属服务已停止。** 在私人基地的建造列表中选择「配电柱」。核心与启用的配电柱各覆盖 6 格，配电柱需在核心直供范围。预览会显示地图供区和受影响的设施。首胜扩地后，可用 1 份结构材料把电力引到东侧冶炼厂。若保存时显示连接中断，点「刷新布局」可核对已保存的版本。[触屏验收与限制](../openspec/changes/archive/2026-11-09-m23-power-coverage-android/verification/root-review.md)

模拟器使用本版新账号，档案服务为 `10.0.2.2:29880`。演习、独行、组队、营地、秘宝依次使用 UDP 29871、29872、29873、29874、29876。[1048 签名 APK](../build/private-beta/PunkLegion-beta-1048.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1048.json)

## 1047 本地内测

**历史版本，专属服务已停止。** 在私人基地打开「委托制作战役铭牌」，选择机体一场已结算的参战记录。每块消耗 4 结构、1 通用零件。首块自动陈列，之后可从收藏免费换展，铭文保留战时机名。安卓模拟器已实际点选非默认行、制作两块、换展并重登。[触屏与账本主验](../openspec/changes/archive/2026-11-09-m23-plaque-android/verification/root-review.md)

安装签名包后使用本版新账号。模拟器档案地址为 `10.0.2.2:29780`，演习、独行、组队、营地、秘宝依次使用 UDP 29771、29772、29773、29774、29776。[1047 签名 APK](../build/private-beta/PunkLegion-beta-1047.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1047.json)

## 1046 本地内测

**历史版本，专属服务已停止。** 在私人基地查看本场预警或实战时失去连接，页面会标出最后确认的画面，快速补读后每约 10 秒查询一次。恢复连接后直接显示服务端战况或结算。模拟器实测在断网期间完成结算，恢复后未点刷新即取得同场战报。[安卓主验记录](../openspec/changes/archive/2026-11-09-m23-raid-recovery-android/verification/root-review.md)

安装签名包后使用本版新账号。模拟器档案地址为 `10.0.2.2:29680`，演习、独行、组队、营地、秘宝依次使用 UDP 29671、29672、29673、29674、29676。[1046 签名 APK](../build/private-beta/PunkLegion-beta-1046.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1046.json)

## 1045 本地内测

**历史版本，专属服务已停止。** 在基地打开野生机预警，可看见通往核心的箭头、来敌台数及威胁预算。重型拆解机消耗两点预算，移动较慢，耐久更高。开战前保存新布局会更新同场路径，实战和回放沿用最终防线。本次模拟器在战中遇到读取失败，点一次「刷新战况」后取得同场结算。[安卓操作与实战](../openspec/changes/archive/2026-11-09-m23-raid-roster-android/verification/root-review.md)

本机安卓模拟器安装 1045 后注册本版新号。档案服务使用 10.0.2.2:29580，演习、独行、组队、营地、秘宝依次使用 UDP 29571、29572、29573、29574、29576。[1045 签名 APK](../build/private-beta/PunkLegion-beta-1045.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1045.json)

## 1044 本地内测

**历史版本，专属服务已停止。** 进入开放秘宝后选好火力组，点敌方机体指定集火，点空地移动。签名安卓实测可以越过近处前排选中后排维修机。泵站准备页可核对已回收首通维修臂的编号。[安卓实战与截图](../openspec/changes/archive/2026-11-09-m23-treasure-focus-beta/verification/root-review.md)

在本机安卓模拟器安装 1044，注册本版新号。档案服务使用 10.0.2.2:29480，演习、独行、组队、营地、秘宝依次使用 UDP 29471、29472、29473、29474、29476。[1044 签名 APK](../build/private-beta/PunkLegion-beta-1044.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1044.json)

## 1043 本地内测

**历史版本，专属服务已停止。** 私人基地收到野生机预警后，可返回基地恢复炮塔供电并保存，在同一预警页核对位置、供电和防线版本。开战时服务端锁定本场防线。从泵站准备页可回看首通维修臂编号及 AUX 功能槽提示。准备页已回收状态的编号末尾仍有一个缺字框。[安卓主验](../openspec/changes/archive/2026-11-09-m23-defense-android-1043/verification/root-review.md)

在连接本机的安卓模拟器安装 1043，注册本版新号。档案服务使用 10.0.2.2:29380，演习、独行、组队、营地、秘宝依次使用 UDP 29371、29372、29373、29374、29376。[1043 签名 APK](../build/private-beta/PunkLegion-beta-1043.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1043.json)

## 1042 本地内测

**历史版本，专属服务已停止。** 从私人基地进公开地图，在泵房开放时选择独行或合作。本人第一次成功撤离，维修臂直接入包；仓满时可腾出位置后在基地机库补领。回营后选择原机的 AUX 功能槽，可按战报编号装入维修臂。安卓战报末尾的句号可能显示为方框，部件编号仍可辨认。[签名手机通关与装机验收](../openspec/changes/archive/2026-11-09-m23-pump-recovery-beta/verification/root-review.md)

连接本机安卓模拟器，运行 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1042.apk`，注册本版新账号。档案地址为 `10.0.2.2:29280`，演习、独行、组队、营地、秘宝分别使用 UDP 29271、29272、29273、29274、29276。[1042 签名 APK](../build/private-beta/PunkLegion-beta-1042.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1042.json)

## 1041 本地内测

**历史版本，专属服务已停止。** 从私人基地进入公开地图，选择开放的黄铜转运场或线圈港。登记后可在指挥台查看首次开战所需的 1 能源和私仓余额。同场断线后可凭原席位免费接回。锈轨大厅取消后重新寻找队友时，会显示本次等待状态。[签名手机截图与账本](../openspec/changes/archive/2026-11-09-m23-camp-supply-beta/verification/root-review.md)

在已连接本机的安卓模拟器执行 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1041.apk`，注册本版新账号。档案地址为 `10.0.2.2:29180`，演习、独行、组队、营地、秘宝分别使用 UDP 29171、29172、29173、29174、29176。[1041 签名 APK](../build/private-beta/PunkLegion-beta-1041.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1041.json)

## 1040 本地内测

**历史版本，专属服务已停止。** 从私人基地点「日常 · 找队友 / 邀好友」进入锈轨大厅，点「寻找队友」。等候和取消免费，两人准备后由队长出发，每人支付 1 能源或本人可用的救援凭证。取消后立刻重搜时，下方可能保留上次提示，以顶部搜索状态和「取消寻找」按钮为准。[手机与桌面实战验收](../openspec/changes/archive/2026-11-09-m23-rustyard-match-beta/verification/root-review.md)

连接本机安卓模拟器，运行 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1040.apk` 后注册新账号。档案地址为 `10.0.2.2:29080`，演习、独行、组队、营地、秘宝分别使用 UDP 29071、29072、29073、29074、29076。[1040 签名 APK](../build/private-beta/PunkLegion-beta-1040.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1040.json)

## 1039 本地内测

**历史版本，专属服务已停止。** 在地图选择自己的黄铜营地可预览领取量、仓库余位和当地留存。在指挥官档案进入「机库与实装」，可先看方案会沿用、装入和退回哪些部件，确认后再换装。[安卓触控与账本验收](../openspec/changes/archive/2026-11-09-m23-camp-and-refit-beta/verification/root-review.md)

本机安卓模拟器运行 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1039.apk` 后注册新账号。档案地址为 `10.0.2.2:28980`，演习、独行、组队、营地、秘宝分别使用 UDP 28971、28972、28973、28974、28976。[1039 签名 APK](../build/private-beta/PunkLegion-beta-1039.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1039.json)

## 1038 本地内测

**历史版本，专属服务已停止。** 私人基地 → 指挥官档案 → 自有机体工坊 → 设计与制造。更换功能件可直接比较造价和指挥点。合法方案即使缺料也可保存，材料足够时可制造。档案首次读取遇到短时网络故障会在原页限次重试。[签名包、造机及账本主验](../openspec/changes/archive/2026-11-09-m23-fabrication-quote-beta/verification/root-review.md)

在连接本机的新安卓模拟器上执行 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1038.apk`，注册本版新账号。档案地址为 `10.0.2.2:28880`，演习、独行、组队、营地、秘宝分别使用 UDP 28871、28872、28873、28874、28876。[1038 签名 APK](../build/private-beta/PunkLegion-beta-1038.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1038.json)

## 1037 本地内测

**历史版本，专属服务已停止。** 从私人基地进入指挥官档案 → 好友与援军 → 装配分享，可查看好友方案的功能件和本人缺件，再保存到自己的工坊。后台刷新时也可保存。基地野袭战报可打开当场驻防机的当前机况，临时读取失败会重试。[签名包与玩家入口验收](../openspec/changes/archive/2026-11-09-m23-friends-and-raid-beta/verification/root-review.md)

在已连本机的安卓模拟器上运行 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1037.apk`，首次进入使用新账号。本机档案地址为 `10.0.2.2:28780`，演习、独行、组队、营地、秘宝分别使用 UDP 28771、28772、28773、28774、28776。[1037 签名 APK](../build/private-beta/PunkLegion-beta-1037.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1037.json)

## 1036 本地内测

**历史版本，专属服务已停止。** 在私人基地菜单设置音量，重开游戏保留选择。合作集结中主动退出和到期未出战分别显示个人战报。在基地野袭记录中，可点「查看驻防机当前机况」，按机名与编号查看报价，确认送修才扣材料。模拟器首次加载战况偶发失败，本轮在重新进入后读到同一记录。[签名与普通入口验收](../openspec/changes/archive/2026-11-09-m23-base-and-combat-reports-beta/verification/root-review.md)

模拟器安装命令为 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1036.apk`。使用新账号，本机档案地址为 `10.0.2.2:28680`；演习、独行、组队、营地、秘宝分别使用 UDP 28671、28672、28673、28674、28676。[1036 签名 APK](../build/private-beta/PunkLegion-beta-1036.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1036.json)

## 1035 本地内测

**历史版本，专属服务已停止。** 从私人基地出击锈轨回收场，战后点「展开机体明细」并选一台机器人，即可查看本场事件。准备页的最近个人战报也可按实体编号查阅、翻页。打开指挥官档案的服役记录，可以查看该机体生涯全部胜败、平局、撤退和过期次数。[实战、同名机体与累计档案验收](../openspec/changes/archive/2026-11-09-m23-unit-record-beta/verification/root-review.md)

模拟器安装命令为 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1035.apk`。档案地址为 `10.0.2.2:28580`，演习、独行、组队、营地、秘宝依次使用 UDP 28571、28572、28573、28574、28576。[1035 签名 APK](../build/private-beta/PunkLegion-beta-1035.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1035.json)

## 1034 本地内测

**历史版本，专属服务已停止。** 从私人基地进入锈轨准备页，可查看每台机体的装配点数。更改选择后刷新，能以同一阵容出发。合作大厅中，按住机体期间队友准备，松手仍能选中。野袭预警的驻防选择按机体编号跟随名单更新。[三入口安卓验收](../openspec/changes/archive/2026-11-09-m23-sortie-guard-beta/verification/root-review.md)

模拟器安装命令为 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1034.apk`。从新账号开始，档案地址为 `10.0.2.2:28480`；演习、独行、组队、营地、秘宝使用 UDP 28471、28472、28473、28474、28476。[1034 签名 APK](../build/private-beta/PunkLegion-beta-1034.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1034.json)

## 1033 本地内测

**历史版本，专属服务已停止。** 安卓断网登录后，界面保留已填内容。恢复网络后点一次「登录已有基地」即可返回基地。合作探索集结时，主动退出者会从待到人数中扣除。原队长退出后，继任者可在小地图发出全队可见的移动标记。[安卓与服务端交叉验收](../openspec/changes/archive/2026-11-09-m23-coop-command-beta/verification/root-review.md)

模拟器安装命令为 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1033.apk`。本机档案地址为 `10.0.2.2:28380`，演习、独行、组队、营地、秘宝依次使用 UDP 28371、28372、28373、28374、28376。1032 在登录复验时发现缺陷，1033 修正客户端并沿用该轮独立部署的六项服务。[1033 签名 APK](../build/private-beta/PunkLegion-beta-1033.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1033.json)

## 1031 本地内测

**历史版本，专属服务已停止。** 从私人基地打开指挥官档案，选中参与驻防的机体，在服役记录里可查看当场维修平台的地格、受修机体、修复量与剩余战损。基地修理站和机体档案均列出送修所需与持有材料。[安卓战报与维修验收](../openspec/changes/archive/2026-11-09-m23-raid-repair-beta/verification/root-review.md)

在安卓模拟器执行 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1031.apk`，从新账号开始试玩。档案地址为 `10.0.2.2:28280`，演习、独行、组队、营地、秘宝依次使用 UDP 28271、28272、28273、28274、28276。此次首次 Wi-Fi 登录出现三次连接失败，切到模拟移动网络后成功，随后 Wi-Fi 冷启可正常恢复基地。[1031 签名 APK](../build/private-beta/PunkLegion-beta-1031.apk) · [版本清单与校验值](../build/private-beta/PunkLegion-beta-1031.json)

## 1030 本地内测

**历史版本，专属服务已停止。** 安卓模拟器曾实测带援军夺营、锈轨断网接回和原场撤退结算。[验收记录与截图](../openspec/changes/archive/2026-11-09-m23-expedition-roster-beta/verification/root-review.md)

在本机开启 1030 的 Docker 服务，从全新模拟器安装签名包并注册新账号。安装命令为 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1030.apk`。模拟器使用 `10.0.2.2:28180` 连接档案，演习、独行、组队、营地和秘宝分别使用 UDP 28171、28172、28173、28174 和 28176。[1030 签名 APK](../build/private-beta/PunkLegion-beta-1030.apk) · [版本清单及校验值](../build/private-beta/PunkLegion-beta-1030.json)

从私人基地进入公开地图，选择已开放的营地。指挥台列出每台机器人的装配点数，好友援军被接收后计入该营地本方的合计。超出 12 台或 24 点时，取消勾选即可重新调整。攻守正在进行时可接回原席。[营地部署](camp-contest.md)

从基地点「出击 · 锈轨回收场」。失联时场景保留最后一帧，战斗指令收起，点「重连原场」并等候席位确认即可继续指挥。若任务已结算，接回时可查看原战报。泵站使用相同的重连接口，校准与守卫提示随状态更新。[探索玩法](solo-expedition.md)

## 1029 本地内测

**历史版本，专属服务已停止。** 安卓模拟器曾通过黄铜转运场重连夺营和失联超时保营验收。 [验收记录](../openspec/changes/archive/2026-11-09-m23-live-camp-reconnect-beta/verification/root-review.md)

1029 使用同一内测证书和协议 5，连接独立档案。使用新账号，在全新模拟器运行 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1029.apk`。模拟器档案地址为 `10.0.2.2:28080`；演习、独行、组队、营地、秘宝依次使用 UDP 28071、28072、28073、28074、28076。[下载 1029 签名 APK](../build/private-beta/PunkLegion-beta-1029.apk) · [版本清单与校验值](../build/private-beta/PunkLegion-beta-1029.json)

从私人基地点「公开地图」，在开放时段登记黄铜转运场或线圈港，进入指挥台后点「实时进攻」。主攻方失联时保留已有核心进度，战斗和守方计时继续。请在 30 秒内点「重连原场」并等服务器确认，随后可继续累计至 16 秒；超过宽限或整场先到时限，离线攻方不能凭领先夺营。[公开营地攻防与接回席位](camp-contest.md#指挥与结算)

在私人基地打开防守预警，财富预算会把私人产线已完工待领取物资与主仓同类物资等值计算。实际失守仅从主仓超保库存掠夺，产线上未领成品仍可领取。[私人基地防守与保险](player-profile.md#私人基地的模块化防御平台)

## 1028 私人基地防守（服务已停止）

在私人基地点「基地防守」可以查看保护倒计时。新账号先受保护 12 小时，随后有 30 分钟袭击预警。预警期间点「野生机袭击预警」查看当前库存的风险，可选择一台待命机体并点「登记驻防机」。防守画面按当场记录显示守军，返回基地后恢复自己的基地布局与展示机体。[下载 1028 签名 APK](../build/private-beta/PunkLegion-beta-1028.apk)

主仓保险额度为结构材料 6、通用零件 3、能源 2。核心失守时，只从当时超出各自额度的主仓物资中随机掠夺，三种合计最多 3 份。驻防机受损需要 2 份维修物资时，掠夺与维修合计最多 4 份。花掉库存后可点「刷新战况」重看估算，战后点「播放本场防守记录」查看实际战况及扣款。[签名包两场实际收据](../openspec/changes/archive/2026-11-09-m23-base-defense-beta/verification/root-defense.json)

模拟器使用新账号，档案地址 `10.0.2.2:27980`，演习、独行、组队、营地、秘宝分别使用 UDP 27971、27972、27973、27974、27976。全新安装运行 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1028.apk`。模拟器上，英文机名接全角括号的驻防提示可能显示缺字符号。[版本清单及 APK 校验值](../build/private-beta/PunkLegion-beta-1028.json) · [驻防回放实图](../openspec/changes/archive/2026-11-09-m23-base-defense-beta/verification/android/guard-replay.png)

1028 的公开营地有一项已复现的问题：主攻方掉线时，在核心圈内的机体仍可能累计到 16 秒并夺营。该问题的开发版修订与重连规则见[公开营地攻防](camp-contest.md#指挥与结算)。

## 1027 个人战报（服务已停止）

从私人基地点「出击 · 锈轨回收场」可独行，也可点「邀请好友 · 组队探索」。想分头攻阀，和好友一起从公开地图点本轮开放的泵站。战后自动显示本人的结算原因、物资收支和维修报价。点「展开机体明细」可查看每台机体的击杀与实际施修。收工后回到同一活动准备页，点「查看上次个人战报」即可复看。[下载 1027 签名 APK](../build/private-beta/PunkLegion-beta-1027.apk) · [两席签名包实战与核账](../openspec/changes/archive/2026-11-09-m23-personal-debrief-beta/verification/root-review.md)

使用新测试账号。模拟器连接档案 `10.0.2.2:27880`，演习、独行、组队、营地、秘宝分别使用 UDP 27871、27872、27873、27874、27876。全新安装运行 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1027.apk`。[版本清单及 APK 校验值](../build/private-beta/PunkLegion-beta-1027.json)

## 1026 营地采集站（服务已停止）

[下载 1026 签名 APK](../build/private-beta/PunkLegion-beta-1026.apk)。从私人基地进入「公开地图」，在黄铜转运场或线圈港的开放时段登记并实时占领。回地图点自己的营地，进入「营地产出与驻防 → 建设采集站」。消耗 2 份当地材料，将产速提高至每 12 分钟一份，最多积存 8 份。可先离开游戏，稍后回指挥台点「领取营地产出」。时窗以公开地图上的服务器日程为准。

模拟器经 TCP 27780 访问独立本机档案。演习、独行、组队、营地、秘宝分别使用 UDP 27771、27772、27773、27774、27776。使用新测试账号，安装命令为 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1026.apk`。[版本清单](../build/private-beta/PunkLegion-beta-1026.json) · [实际占领、建设与自然领取](../openspec/changes/archive/2026-11-09-m23-camp-extractor-beta/verification/root-review.md)

## 1025 真实涂装试穿（服务已停止）

[下载 1025 签名 APK](../build/private-beta/PunkLegion-beta-1025.apk)。安装后从私人基地进入「菜单 → 指挥官档案与机库 → 自有机体工坊 → 涂装与方案栏商店」。选中自己的机器人试穿薄荷珐琅，底盘、核心大小、空槽和维修臂都按这台机体的实装显示。未拥有时可试穿，模拟购买后需选择机体并确认装备。退款会收回涂装并恢复基础色。

本机服务为 `punk-private-beta-1025`。模拟器经 TCP 27680 访问档案，演习、独行、组队、营地和秘宝依次使用 UDP 27671、27672、27673、27674、27676。使用新测试账号；六个服务卷独立于 1024。安装命令为 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1025.apk`。[发布清单](../build/private-beta/PunkLegion-beta-1025.json) · [签名与手机订单实测](../openspec/changes/archive/2026-11-09-m23-equipped-preview-beta/verification/root-review.md)

## 1024 基地与撤离门验收（服务已停止）

[下载 1024 签名 APK](../build/private-beta/PunkLegion-beta-1024.apk)。从新安装的安卓模拟器启动游戏，在私人基地注册并为初始机体命名。本机 Docker 项目为 `punk-private-beta-1024`，档案入口 `10.0.2.2:27580`；演习、独行、合作、营地、秘宝分别使用 UDP 27571、27572、27573、27574、27576。安装可从工程根目录执行 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1024.apk`。

首机的登记号和实际装配随登录或恢复会话的同一份档案返回。六台机体全部出征后也能重回基地，首机显示自己取的名字；正常首屏不需加载整个工坊。

从公开区域图选择当前的限时秘宝。确认自愿参战并匹配后，点地接近资源，再点「拾取最近」。按「回到撤离点」返回己方有门牌的出口，到达后点「确认撤离」。安卓已实测从左侧门带出一件结构材料并入库。[发布清单](../build/private-beta/PunkLegion-beta-1024.json) · [安卓基地和秘宝验收](../openspec/changes/archive/2026-11-09-m23-base-entry-snapshot-beta/verification/root-review.md)

## 1023 历史试玩

[下载 1023 签名 APK](../build/private-beta/PunkLegion-beta-1023.apk)。在运行本机服务的电脑上，向全新安卓模拟器安装此包。档案服务为 `10.0.2.2:27480`，演习、独行、合作、营地、秘宝分别使用 UDP 27471、27472、27473、27474、27476。本机 Compose 项目为 `punk-private-beta-1023`。

从私人基地打开「公开区域图」，在开放时段选择「遗迹」，独行或输入好友邀请码参战。进泵房后点一台自己的机器人，指挥栏显示自定义名，点「前往西阀」只派这台出发。点「全队」可看选中数量，再派整队前进。双阀、宝箱与分别撤离的玩法沿用上一版。

三席满编时，每席六台轻机，另有六名守卫。安卓模拟器已验证单机和整队指挥，密集交火帧时仍高于 30 FPS 预算。[签名清单](../build/private-beta/PunkLegion-beta-1023.json) · [安卓实测与性能边界](../openspec/changes/archive/2026-11-09-m23-pump-selection-beta/verification/root-review.md)

## 1022 历史试玩

[下载 1022 签名 APK](../build/private-beta/PunkLegion-beta-1022.apk)。本机 Docker 项目为 `punk-private-beta-1022`。模拟器档案入口 `10.0.2.2:27380`，演习、独行、组队与遗迹、营地、秘宝分别使用 UDP 27371、27372、27373、27374、27376。

进入私人基地的「公开区域图」，选择当窗的「遗迹」图钉。在单人 PvE 准备页可独自出发；好友 PvE 支持使用邀请码组队。分头清理两端守卫、靠近阀门校准，箱子由队伍共同打开。每人带自己的存活机体到出口后确认撤离。每 30 分钟开放 20 分钟，具体倒计时看地图。窗口关闭不影响已出发的实例。

每人按出发 UTC 日首次胜利最多获得 2 通用零件。收工回地图可核对剩余额度；再次协助好友仍会获得真实参战记录。锈轨与公开营地保持原有独立进度。此版也已修正准备页说明裁切和服役记录空目标箭头。

[版本清单](../build/private-beta/PunkLegion-beta-1022.json) · [双端实战与个人账本](../openspec/changes/archive/2026-11-09-m23-pump-ruin-beta/verification/root-acceptance.md)

## 1021 历史试玩

[下载 1021 签名 APK](../build/private-beta/PunkLegion-beta-1021.apk)。本机 Docker 项目为 `punk-private-beta-1021`，模拟器从 `10.0.2.2:27280` 访问档案。演习、单人探索、组队探索、营地和秘宝分别使用 UDP 27271、27272、27273、27274、27276。

从基地进入锈轨回收场，首次个人胜利后再次打开独行准备页。展开「锈轨外围 · 快速回收」，选一台待命机体，核对实际报价后确认。每个 UTC 日可用 1 能源回收至多 2 结构材料；仓库只剩一格时可得 1 份。领取后显示机体、到账数量与当日状态。

[版本清单](../build/private-beta/PunkLegion-beta-1021.json) · [真实首胜、安卓回收与核账](../openspec/changes/archive/2026-11-09-m23-quick-salvage-beta/verification/root-acceptance.md)

## 1020 历史试玩

[下载 1020 签名 APK](../build/private-beta/PunkLegion-beta-1020.apk)。本机 Docker 项目为 `punk-private-beta-1020`。安卓模拟器经 `10.0.2.2:27180` 访问档案，演习、单人探索、组队探索、营地和秘宝分别使用 UDP 27171、27172、27173、27174、27176。

从私人基地的「日常 · 好友组队」出发。探索结束后，打开「基地菜单 → 指挥官档案与机库」，选中该机体并查看服役记录。实战后主动撤退会写入时间线；集结时一直未到场的玩家收到个人过期回执，机体仍然待命，参战次数维持原值。此版修正了 1019 中两者均显示为失利的问题。

[版本清单](../build/private-beta/PunkLegion-beta-1020.json) · [逐机验收及安卓截图](../openspec/changes/archive/2026-11-09-m23-service-record-beta/verification/root-acceptance.md)

## 1019 历史试玩

[下载 1019 签名 APK](../build/private-beta/PunkLegion-beta-1019.apk)。本机 Docker 项目为 `punk-private-beta-1019`。模拟器档案入口为 `10.0.2.2:27080`，演习、单人探索、组队探索、营地和秘宝分别使用 UDP 27071、27072、27073、27074、27076。

从私人基地的「日常 · 好友组队」出发。首位指挥官进入战场后可看到谁已到场，队员到齐立即开战；到 30 秒时，已到场者开始作战。开战时拥有完整的 7 分钟。安卓已分别验证两席到齐、一席缺席，并核对各自回执、触控指挥及回营。

已知问题：探索的撤退或过期在本版机体服役记录中会显示失利，未到场的机体也可能增加一场。个人派遣回执正确保留撤退或过期原因。修正由 M10 的探索参战记录变更跟踪。

[版本清单](../build/private-beta/PunkLegion-beta-1019.json) · [主代理验收](../openspec/changes/archive/2026-11-09-m23-party-assembly-beta/verification/root-acceptance.md)

## 1018 历史试玩

[下载 1018 签名 APK](../build/private-beta/PunkLegion-beta-1018.apk)。本机 Docker 项目为 `punk-private-beta-1018`。安卓模拟器经 `10.0.2.2:26980` 访问档案，演习、单人探索、组队探索、营地和秘宝使用 UDP 26971、26972、26973、26974、26976。按本轮新账号验收。

从私人基地进入「日常 · 好友组队」，建立队伍或输入邀请码。选机时核对本人草案、与已准备队友合计的预计点数及本人费用。每名玩家在出发时支付 1 能源，能源用完可用本人的救援凭证。战果页点「本次收工」回营，其他玩家可以另开下一局。此版也合入了秘宝界面动态机体和物资列表的标点修复。

[版本清单](../build/private-beta/PunkLegion-beta-1018.json) · [1018 实战与账本](../openspec/changes/archive/2026-11-09-m23-coop-outing-beta/verification/root-acceptance.md)

## 1017 历史试玩

[下载 1017 签名 APK](../build/private-beta/PunkLegion-beta-1017.apk)。本机 Docker 项目为 `punk-private-beta-1017`，模拟器经 `10.0.2.2:26880` 访问档案。演习、单人、组队、营地和秘宝房间使用 UDP 26871、26872、26873、26874、26876。用新的本轮测试账号登录。

在公开地图点限时秘宝图钉，与一名好友分别提交机体并确认同一阵容。两人各自最多 6 台、12 指挥点，单人最多 12 台、24 点。在战场点地靠近货箱，点「拾取最近」，确认临时包出现货物，再回己方撤离点点「确认撤离」。960×540 安卓模拟器已验证此路径，个人账本实际增加 1 份结构材料。1017 名单内多个机体之间的顿号可能显示为方框。

[签名摘要与端口](../build/private-beta/PunkLegion-beta-1017.json) · [主验记录](../openspec/changes/archive/2026-11-09-m23-personal-treasure-beta/verification/root-acceptance.md)

## 1015 历史试玩

[安装 1015 签名 APK](../build/private-beta/PunkLegion-beta-1015.apk)。本机 Docker 项目为 `punk-private-beta-1015`。安卓模拟器连接 `10.0.2.2:26680`，演习、单人探索、组队探索、营地和秘宝分别使用 UDP 26671、26672、26673、26674、26676。使用新设备或空的测试安装环境，运行 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1015.apk`。

建成并供电后，点基地的修理站即可看到两个工位。每台耗 1 结构、1 零件，送修后 30 秒归队。已掌握的钻头配方在小屏上完整显示操作路径，从指挥官档案进入仓库与账本，先点「查看库存」，再点「制造钻头」。双人秘宝的个人额度改动在后续开发版本中。

[1015 验收与实图](../openspec/changes/archive/2026-11-08-m23-repair-bay-beta/verification/root-acceptance.md) · [版本摘要与文件指纹](../build/private-beta/PunkLegion-beta-1015.json)

## 1014 历史试玩

[安装 1014 签名 APK](../build/private-beta/PunkLegion-beta-1014.apk)。模拟器连接本机 Docker 项目 `punk-private-beta-1014`。档案为 `10.0.2.2:26480`，五个房间使用 UDP 26471、26472、26473、26474、26476。模拟器使用宿主 GPU。首次安装可用 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1014.apk`。

从私人基地给第一台机器人命名。到「生产与研究」查看钻头的个人 0/3 进度，或建造供电装配车间提前研究。整机工坊切换履带气炮机的头部，可见普通双目的 2 指挥点与战术目镜的 3 指挥点。保存、制造后，从基地出击锈轨回收场可以核对同一机体。掌握配方后可到档案仓库单件制造钻头。1014 的小屏研究成功提示末尾会截断。

[1014 主验和模拟器实图](../openspec/changes/archive/2026-11-08-m23-rustrail-workshop-beta/verification/root-acceptance.md) · [版本摘要和文件指纹](../build/private-beta/PunkLegion-beta-1014.json)

## 1013 历史试玩

本机容器项目为 `punk-private-beta-1013`。模拟器通过 `10.0.2.2:26380` 连接档案服务，五个权威房间分别使用 UDP 26371（演习）、26372（单人）、26373（组队）、26374（营地）、26376（秘宝）。本轮从空卷开始，使用新注册的指挥官。

1. 在同一台运行容器的电脑上启动 Android 模拟器。本轮已在宿主 GPU 渲染模式运行；SwiftShader 软件模式出现片元 uniform 上限错误，画面停留在启动页。选择本轮新建且未安装本游戏的测试设备，使用 `adb -s <设备序列号> install build/private-beta/PunkLegion-beta-1013.apk` 安装。
2. 打开游戏，在私人基地注册账号并给首机命名。普通双目气炮机占 2 个指挥点。将另一台履带气炮机的头部选为战术目镜，通过保存方案和制造获得实体；该配置占 3 点，制造消耗 3 份结构材料、2 份通用零件与 1 点能源。
3. 从基地出战，在射程内对新敌集火。普通双目的首次瞄准为 0.25 秒，目镜为 0.05 秒；气炮连续射击间隔均为 1 秒。换敌时，武器冷却和干扰仍会限制开火时刻。

包名 `dev.punklegion.beta`，协议 5，APK SHA-256 为 `87817b2380e7f7ef1bfc914c213f0b796a7ba56146c536bb7732b039754e31c1`。[1013 安装包](../build/private-beta/PunkLegion-beta-1013.apk) · [版本清单](../build/private-beta/PunkLegion-beta-1013.json) · [新装与主验记录](../openspec/changes/archive/2026-11-08-m23-visor-timing-beta/verification/root-acceptance.md)

在仓库根目录执行 `docker compose -p punk-private-beta-1013 ps` 检查当前测试服务；若同轮服务已停止，以 `docker compose -p punk-private-beta-1013 start` 重新启动原容器。使用 `Invoke-RestMethod http://127.0.0.1:26380/v1/beta/compat` 检查档案协议。

## 基地优先的 Android 启动

从 1033 起，客户端在登录通信失败时保留本次表单输入，恢复连接后点「登录已有基地」即可继续。注册时连接中断，账号可能已经创建，先用同一账号登录核对。登录成功后清空密码，档案中的机体与基地归属以服务端为准。

开发版增加 `starter_equipment_snapshot` 服务能力。注册、登录、恢复和命名返回的账号档案同时携带按创建顺序确定的首机装配；该机已派遣也可显示，已回收时装配值为 null。同一响应内核对账号、机体和实际槽位，再继续加载基地布局与指引。服务缺少能力时显示匹配版本提示，快照错误和真实断网保留重试入口。

1009 已采用基地启动流程。Android 先绘制私人基地场景，未认证时只有场景、连接和账号入口，布局、库存及机体均以档案服务返回为准。新指挥官在基地登录或注册后可查看首机的当前名字、登记号和实际装配，输入名字并确认。已有名字的首机直接恢复显示。会话令牌按档案地址保存在应用私有存储，应用不保存密码。服务未响应时点「重试连接」；会话过期需重新登录。确认名称遇到断线时，重试先读取服务器已保存的首机名称。

「基地菜单」提供指挥官档案与机库、试车台、连接诊断、版本、反馈和切换账号。在试车台点「返回私人基地」回到同一指挥官。普通桌面编辑器继续从试车台进入，直接启动 `res://beta/entry.tscn` 可复验基地流程。新客户端读取 `/v1/beta/compat` 的 `capabilities`，服务端必须声明 `base_first_naming`；数字协议相同而能力缺失时显示更新或匹配版本提示。覆盖旧包之后，以原账号登录可恢复旧基地。

## 历史记录：1012 安装与首次登录

本版加入锈轨回收场的首次通关扩地。新老账号按个人胜利回执免费获得东侧三列 27 格；尚未通关时可在基地查看解锁条件。已安装 1011 的玩家直接覆盖安装。

1. 获取本页的正式 APK 和版本单，核对 SHA-256。包名为 `dev.punklegion.beta`，支持 Android 7.0 及以上的 arm64-v8a 与 x86_64。
2. 启动本页列出的本机服务和同一宿主上的横屏模拟器，在 Windows 执行 `adb -s emulator-5580 install -r <APK路径>` 覆盖原包。
3. 在私人基地注册并为首机命名。原指挥官用已有账号登录，基地、机器人和库存从服务器恢复。大地图上的黄铜转运场和线圈港各自打开对应营地指挥台，攻占时段由服务端日历决定。
4. 通过「基地菜单 → 连接诊断」查看版本与端口。出现问题时，复制诊断信息，附操作时间、场次与复现步骤给邀请人。

## 冻结构建与端口

构建工具读取同一 Windows 用户的 Godot 4.6.1.stable 编辑器、匹配版本 Android 导出模板、JDK 与 Android SDK。如需指定路径，使用 `--godot`、`JAVA_HOME`、`ANDROID_HOME`。依据 Godot 官方的签名导出环境变量运行 release preset。[Android 导出文档](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html)

```powershell
python -B deploy/build_private_beta.py freeze build/private-beta/snapshots/rc-<批次>
python -B deploy/build_private_beta.py build --snapshot build/private-beta/snapshots/rc-<批次> --code <下一递增整数> --protocol <快照中的BETA_PROTOCOL_MIN>
```

每次冻结使用新目录。构建前重新核对文件集合及 SHA-256。完成后 `build/private-beta/` 中同名 APK 和 JSON 记录版号、文件哈希、快照哈希、签名指纹、ABI 和网络目的地。包名与证书保持一致，发布计数严格递增。私钥、DPAPI 密文与版号账本位于构建机用户目录 `%LOCALAPPDATA%/PunkLegion/signing/private-beta`。备份签名材料及相应 Windows 用户的 DPAPI 恢复能力，限制到内测构建负责人访问。

1012 历史内测使用签名客户端 1012，继续连接协议 5 的现有服务项目 **punk-private-beta-1009**。日常重启使用下列命令，保留现有具名卷。旧版 1008 的资料卷与回退镜像留在原项目。隔离候选 punk-base-coil-rc1009 的测试账号保存在另一组卷。

```powershell
$snapshot = (Resolve-Path 'build/private-beta/snapshots/rc-1009').Path
docker compose --project-directory "$snapshot" -p punk-private-beta-1009 --env-file "$snapshot/deploy/private-beta.env" -f "$snapshot/compose.yaml" -f "$snapshot/deploy/private-beta.compose.yaml" -f "$snapshot/deploy/base-coil-legacy-entry.compose.yaml" -f "openspec/changes/archive/2026-11-08-m23-camp-settlement-patch/verification/forward.compose.yaml" -f "openspec/changes/archive/2026-11-08-m23-rustrail-land-beta/verification/profile-1012.compose.yaml" up -d --no-build
Invoke-RestMethod http://127.0.0.1:25180/v1/beta/compat
$env:HEALTH_GAME_PROJECT = 'punk-private-beta-1009'
docker compose -p punk-private-health-1009 -f "$snapshot/deploy/health.compose.yaml" up -d
docker compose -p punk-private-health-1009 -f "$snapshot/deploy/health.compose.yaml" exec -T sampler python /app/health.py report
```

| 服务 | 正式宿主端口 | 协议 |
|---|---:|---|
| 档案、账号、工坊与大地图 | 25180 | TCP/HTTP，档案协议 5 |
| 1007 与 1008 安装包原地址 | 24980、25080 | 同一个正式 profile 对协议 3、4 返回 426 升级提示 |
| 双人演习 | 25171 | UDP/ENet |
| 单人探索 | 25172 | UDP/ENet |
| 好友组队探索 | 25173 | UDP/ENet |
| 公开营地 | 25174 | UDP/ENet |
| 限时秘宝 | 25176 | UDP/ENet |

正式数据卷前缀为 `punk-private-beta-1009_`，包含 player-profiles、room-results、solo-missions、party-missions、camp-battles 和自动配置的 room-auth。正式监控的历史卷是 `punk-private-health-1009_history`。新测试机先从 rc-1009 构建基础服务镜像，再从 rc-1011 构建补丁镜像：在仓库根目录执行 `docker build -t punk-1011-profile:1279769030e3 build/private-beta/snapshots/rc-1011/services/profile` 和 `docker build -t punk-1011-camp:1279769030e3 build/private-beta/snapshots/rc-1011`，再执行 `docker build -t punk-1012-profile:936be505b208 build/private-beta/snapshots/rc-1012/services/profile`。随后使用上方含两份发行覆盖文件的启动命令。

1012 的包名是 dev.punklegion.beta，SHA-256 为 `d00966cc4e7aa0f26241561fbdf6524bf0797820337b9ca0489181728fba5c94`。[1012 APK](../build/private-beta/PunkLegion-beta-1012.apk)、[版本清单](../build/private-beta/PunkLegion-beta-1012.json)

1012 已建东侧资产的恢复使用[保留新地读写的恢复镜像](../openspec/changes/archive/2026-11-08-m23-rustrail-land-beta/verification/recovery.md)。

1011 的同卷镜像回退、停写恢复点及逐项核对命令见[补丁交接记录](../openspec/changes/archive/2026-11-08-m23-camp-settlement-patch/verification/handover.md)。

### 回退到 1008

停写恢复点和健康历史存放在 `%LOCALAPPDATA%/PunkLegion/private-beta-qa/final-1008-v20`。先停 1009 写入并保留其恢复点，核对新账号、进行中场次、机体锁和订单，再决定如何迁移切换后新增的数据。若需恢复至 1008 停写时刻，先停 `punk-private-health-1009` 和 `punk-private-beta-1009`，再在保留的 `punk-private-beta-1008` 项目执行 `docker compose -p punk-private-beta-1008 start`，并启动 `punk-private-health-1008-sampler-1`。检查 25080 返回协议 4，使用单独的模拟器安装原签名 1008 回到原账号。

当前交付支持 **与服务同一台 Windows 宿主机上的标准 Android Studio 模拟器**。另一位测试者在自己的电脑上同时运行对应快照的本地容器与模拟器，也可使用同一 APK，游戏档案属于其本机独立实例。只将 APK 发给异机测试者，其模拟器里的 `10.0.2.2` 会指向他自己的电脑；实体手机上的此地址也无法到达本项目的测试服。当前发布包固定读取内置网络配置。若要让多台电脑或实体设备共用服务器，需要另选测试网络、在目标机验证档案 TCP 和五路 UDP 可达、生成与之匹配的发布配置及递增包。本次容器仍仅绑定宿主回环，无公网监听。[Godot 客户端说明](../game/CLIENT.md)

## 已验更新路径

| 版本 | 档案协议 | SHA-256 |
| --- | ---: | --- |
| 0.1.0-beta.1012 | 5 | `d00966cc4e7aa0f26241561fbdf6524bf0797820337b9ca0489181728fba5c94` |
| 0.1.0-beta.1011 | 5 | `f5dcde01802fa160955b97def3898b84a6ec0137dac2d9841c9129315d82c834` |
| 0.1.0-beta.1010 | 5 | `c0b3e1bb88a07c5efcdec3ee092aa67bbec069aca0ec8201b21571a4fbf78dab` |
| 0.1.0-beta.1009 | 5 | `52b542a07a5e8fd5e02c7ba7212cbaea1ac7a9cc32d05e066cfe35771dde7c8c` |
| 0.1.0-beta.1008 | 4 | `338075a62bc34cb2744482fc9e714751d28d5f431a49efcc0a4a2fabde777354` |
| 0.1.0-beta.1001 | 1 | `f22b84cc611bd393dc67f40ce4d4fe0eed4face3a676614e5b0d101877ee18f7` |
| 0.1.0-beta.1002 | 2 | `2f0f29b35fa54057a1c72ab12fb30f9e69b89c54b88c53a36c6e3cb2cb7f9aa2` |
| 0.1.0-beta.1005（整合候选） | 2 | `1054d70f7a011d29a91f09394087d14c77045fee7e535172b4c6214d4f98002f` |
| 0.1.0-beta.1007 | 3 | `216a9d45a0421a28b378d7a19c96029fa2b7aa9163d4b9021a122a57e01219a0` |

证书 SHA-256 为 `0a22abf91e03bdcd10b742b87816ee21fc4426a701ee2d01f72af3cdb0ac25c5`。前两包用于验证更新机制，冻结时尚未整合 M24。两包均已实际安装在 Android 15 x86_64 模拟器。1002 原位更新保留首次安装时间，原账号机体可见。另测卸载后重新安装 1002 并登录，机体及三个装配实体、方案、库存、薄荷外观、七格方案容量和两笔订单历史逐项一致。

1005 位于 `build/private-beta/PunkLegion-beta-1005.apk`，对应同目录的 JSON 版本单及 `snapshots/rc-1005` 源码。APK 和六个容器来自相同冻结快照，清单 SHA-256 为 `f0093c9101bf53e0efa0badf8915504654a7c014730846cd828e68dcdbf6ecec`。含独立秘宝端点、批量房间轮询、M06 的场景渲染调整和可滚动引导页。1003、1004 是内网整合验证的中间构建。

1005 已从重装后的 1002 原位更新，首次安装时间未变。测试者在模拟器上使用重试、复制反馈与进入按钮，登录原账号后看到原机体、薄荷涂装和七格方案容量。六个服务运行在 `punk-private-beta`，五个 UDP 端点从版本单读取并分别完成 ENet 握手。宿主以五卷 v14 实际恢复点在独立容器启动原版镜像，恢复后的旧服和在线 v15 分别登录同一账号，两个账本均匹配升级前对照。

复核时可以在有凭据的本机先用 `deploy/check_beta_assets.py --url http://127.0.0.1:25180 --protocol 5 --credentials <私有账号文件> --fixture <快照路径> --record` 创建新对照，完成升级或重装后去掉 `--record` 重跑；测试脚本通过同一账号会话登录，会替换该账号此前的访问令牌。档案文件与凭据保存在受限测试目录。

1007 来自 `build/private-beta/snapshots/rc-1007`，清单 SHA-256 为 `cc939d6c0081604fb0c763efce2ba3222d4fe42d630a1039033c666721a15e4e`，六个容器使用同一快照。它包括基地军营、模块化私人防御平台、野生袭击维修回放、维修臂调优、营地合法出生格、首玩提示和战术音效。1006 是未签发的中间源快照，1007 仅在该快照上调整回放文字的分行与小屏适配。

2026-11-08 的安卓验收发生在恢复后的 5580 模拟器。原只读 AVD 进程退出时丢失本地临时安装，重新安装签名的 1005 并连接 v15 恢复副本后，原账号能看到 BetaCrawler 机体。服务切回 v16 后，1005 在首屏显示更新指引并禁用进入。用 `adb install -r` 更新到 1007 后首次安装时间保持 08:54:16 UTC，更新时间为 08:58:37 UTC。重新登录后读到同一机体，客户端可进入私人基地和线圈港的日程预览。

升级前 v15 恢复点包括五个持久卷。首次回退演练按原镜像摘要启动隔离副本；安卓恢复验收按 1005 冻结源重建并保留镜像标签。两次均成功登录旧账号。原账号在旧实例和升级后实例的对账 SHA-256 同为 `e6a883521c00e54f7544b8fc0221868ed3fac706004988310a7df89cee80ae3e`，涵盖机体、部件、库存、方案与订单。健康采样在取统一恢复点时短暂停止，维护切换时发出档案不可达告警，恢复主服务后自行解除。1007 的五个 UDP 接口均已完成真实握手。

冻结后增加的同场乱序音效快照过滤、后台轮询期间暂存加入队伍操作与机体职责配置属于后续开发。当前 1007 在 960 宽的私人基地侧栏中仍有首玩长句超出边缘，回放中两行维修目标与数值已验证可读。

1005 对应的历史服务支持协议 1、2，回退时使用该快照的 Compose 配置，对账命令附加 `--protocol 2`。1007 的内测配置要求协议 3，1005 访问该服务时首屏应提示覆盖安装新版。新服务在业务读取和写入前检查版本；只读兼容性发现可用于健康采样。停服期间首屏允许复制反馈和重试。维护者可用 `python -B services/profile/check_beta.py` 检查门槛，再用模拟器上实际安装的旧包和新包验收。

## 回退与后续验收

APK 更新使用同包名、原证书和更高的版号。客户端回退可从上一份已验证的源码构建更高版号，先核对当前服务协议与档案兼容性。保留源快照、APK/JSON、容器镜像和升级前统一恢复点。服务端需要回退时，先保留故障时恢复点，另建隔离恢复项目，从与旧镜像匹配的已验证快照恢复并对账，再切换。按[内测运维手册](internal-test-operations.md)执行。

签发最终候选前，核对 M06 设备测量、M20 援军、M21 模拟权益、M22 运维和 M24 独立端点的版本。渠道发行另需确定包名与商店账号、隐私与用户协议材料、真实支付沙箱及退款流程、正式网络和实体机温升/耗电实测。当前独立内测范围止于本机模拟器。
