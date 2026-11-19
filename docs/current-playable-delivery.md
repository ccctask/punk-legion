# 当前可玩版交付与维护

更新2026-11-18。最新可用客户端为[1084 LAN APK](../build/private-beta/PunkLegion-beta-1084.apk)，[1084稳定发布根签](../build/private-beta/operations/client-release-1084/ROOT-ACCEPTANCE.md)及[实际登记](../build/private-beta/operations/client-release-1084/registration.json)已签；尚未安装到手机。原手机实际1083、默认同机模拟器1082与1082-delivery-r2六业务服务保持，不重部署、不代操作账号。

## 当前组合与来源

以[稳定索引](../build/private-beta/current-playable.json)为客户端、实际运行台账及独立根签入口，激活CID记录不承诺永久在线。

| 对象 | 当前交付 |
|---|---|
| 最新LAN客户端 | [1084 APK](../build/private-beta/PunkLegion-beta-1084.apk)／[原清单](../build/private-beta/PunkLegion-beta-1084.json)，dev.punklegion.beta，协议5，192.168.31.170；54,226,865 bytes，APK SHA256 2e526aa481d14b5c574ad8c8d931f9b85f6a7888dc771cbdde824cf8a9df793e；原证书不变，手机尚未安装 |
| 既有模拟器客户端 | [1082 APK](../build/private-beta/PunkLegion-beta-1082.apk)与[原签名清单](../build/private-beta/PunkLegion-beta-1082.json)，包名dev.punklegion.beta，协议5；APK SHA256 812741882b6a8604c8f03a3e5d7817bc58876ed7b9df75b201737a7668a34de0 |
| 手机局域网变体 | [1083 APK](../build/private-beta/PunkLegion-beta-1083.apk)与[原清单](../build/private-beta/PunkLegion-beta-1083.json)，端点192.168.31.170；APK SHA256 9f4d8af298e93a3eac52a91769db62c4905b1ca29eeebe59cde648325befc3cf，metadata SHA256 cfbfcba193f7db5f9be05e6a130e44194bd1fff9612887323bd36e0e42c1bd40；[独立产物根签](../openspec/changes/m23-usb-phone-lan-install/root-artifact1083-result-review.md) |
| 1082／1083历史客户端源 | [rc-1082-auto-replan](../build/private-beta/snapshots/rc-1082-auto-replan/source-manifest.json)，540实体，manifest 2345b028c700bdfe66e449326941f18c28cc1795f13fa20c30d712513c13cbda |
| 后端源 | [rc-1082-party-ack1](../build/private-beta/snapshots/rc-1082-party-ack1/source-manifest.json)，540实体，manifest 366ed38a702a1ccefedb491fae8614580c019f30d8904a079d7ae1e28b8ac00e；五Godot角色3cea镜像，Profile b0eded，完整image ID见索引/runtime |
| 实际运行 | [R2 runtime](../build/private-beta/operations/1082-delivery-r2/runtime.json)，项目punk-private-beta-1082-delivery-r2，root accepted/resource_owner=root；[永久维护入口](../build/private-beta/operations/1082-delivery-r2/OPERATIONS.md)列cwd、env、四config（含永久lan.compose.yaml）和正常启停命令 |

客户端2345与服务器366e按[1082完整安卓合作/三账/双P95根签](../openspec/changes/m06-normal-candidate-frame-capture/verification/root-current-pump1082-a3-result-review.md)组合验证，不冒同一manifest。R2六卷由本轮a2空卷正常初始化、新key及一次正常账号注册产生；随后同版本正常激活沿用本轮数据。没有R1/1076库导入、迁移或重投旧战报。

1084客户端源为[rc-1084-automatic-session-refresh](../build/private-beta/snapshots/rc-1084-automatic-session-refresh/source-manifest.json)，542实体，manifest 4ea595eacfc9452b31d9cdc447e165f5c271e78e20543430f6f119ddbf6c47bd。正常页面自动读取／回前台恢复，不要求手动刷新或同步日程；真正异常才显示恢复入口。首胜实体钻头、材料与配方分开，已验真实首胜→同UUID自动入已开工坊→正常装机。必要页面与Android切片组合范围见[1084稳定发布根签](../build/private-beta/operations/client-release-1084/ROOT-ACCEPTANCE.md)；F原整场false与末尾工坊native切页未运行保留，本包未重测P95、未手机安装或听感终验，运动顺滑／轻惯性仅研究。

## 安装与首次进入

最新1084 LAN包端点固定192.168.31.170，已登记可安装但尚未执行手机安装；与原1083使用相同可达局域网条件。1082默认包端点固定10.0.2.2，继续用于同机模拟器。1083手机变体端点固定192.168.31.170，已通过指定USB手机唯一安装、当前私人基地入口和手机curl兼容接口HTTP200；用户已自主注册与命名，本次登记不重复安装或代操作。手机与电脑须在可达的同一WiFi/局域网，电脑保持192.168.31.170且六服务运行；宿主IP变更须重新评估固化端点。没有公网包或公网分发结论。

主持人先核模拟器序列号与AVD名称、R2实际台账和服务连接，再安装原包：

```powershell
adb -s <已核模拟器序列号> install -r C:/Users/alienware/Documents/ChatGPT/punk-legion/build/private-beta/PunkLegion-beta-1082.apk
```

打开游戏后按账号页注册本次新账号或登录本轮已有账号，进入私人基地。旧环境账号不导入R2，旧会话不可用时回到账号页；不清除其他环境数据。密码、token、恢复信息不写进反馈。玩家使用[简明入口](testing/playtest/player-start.md)，主持人读[已知限制](testing/playtest/known-limitations.md)。尚未组织的真人自主体验不填通过。

音量入口是私人基地左上「基地菜单」→「音效」：静音/低/中/高，默认中；试车台底部「音效」共用本机保存的设置。

## 维护与限制

六业务服务由root常驻接手用于模拟器及手机试玩，没有新health/sampler或常驻operator。127.0.0.1回环入口保留，并增加192.168.31.170同端口：TCP33380，以及UDP33371/33372/33373/33374/33376。正常启停先核实际使用方、CID、image、标签、挂载/卷网与永久配置，再用[OPERATIONS](../build/private-beta/operations/1082-delivery-r2/OPERATIONS.md)；当前页面没有重新查询运行状态。未知写结果按同一业务号读取核对，不盲目重发。

下列性能为1082既有代表性真实安卓合作证据，未对1084重测。代表性真实安卓合作场景已完成全局终局、三人各6台的三账和tail。全场P95 19.8101ms，满编P95 20.1632ms，覆盖1.0，达到33.333ms预算；118.0593ms与1066.0949ms两次大于100ms长帧仍保留，具体因果未知。模拟器结果不外推真机、所有设备、全部M00–M24或商业发行，不承诺零卡顿。指定手机安装、当前基地画面及手机HTTP连接已单独签收；手机UDP战斗、所有玩法/触控流程、实体性能及声音听感未由本次签收证明，实体性能与听感留负责人试玩终验，未执行。

[1077原索引历史](../build/private-beta/history/current-playable-1077-before-1082-2026-11-17.json)保原字节；[旧七实例退休](../openspec/changes/m23-architecture-release-integration/verification/root-old-runtime-retirement-result-review.md)、[失败R1收尾](../openspec/changes/m23-architecture-release-integration/verification/root-stable-delivery-a1-cleanup-result-review.md)、[R2原a2格式误拒及清理](../openspec/changes/m23-architecture-release-integration/verification/root-stable-delivery-a2-result-review.md)均保原件，不把历史失败改绿。当前六服身份只取最新LAN部署根签与accepted runtime；此前正常激活根签作为LAN变更前历史保留。
