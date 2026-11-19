- [x] 1.1 开发实体部件获取、兼容功能槽装配与武器/维修双入口服务端延迟。
- [x] 1.2 让玩家辨认干扰来源、效果和保护；重连保持权威截止，事件进入逐机账本。见[档案截图](verification/jammer-history.png)。
- [x] 1.3 实测同输入有/无干扰、双干扰同帧、持续移动、晚出现维修目标与重连。见[实战录像](verification/jammer-live.mp4)、[普通入口日志](verification/solo-live-gold.log)、[营地同目标双动作与两次恢复](verification/camp-dual.log)、[18 种相位](verification/developer-phases.log)、[秘宝步进](verification/treasure.log)以及[64 局常规节奏对照](verification/ordinary-cadence.json)。
- [x] 1.4 主代理独立复现关键时序，在 Godot 联机场景与安卓模拟器验收。

主代理独立对照 18 个初始冷却相位和每种相位的武器、维修动作。第一次发现武器在 0.500 与 2.750 秒初始化时早一个模拟步结束干扰，交回修正在自然就绪点的浮点比较。修复后 36 项实际动作全部推迟 1.000 秒。同一目标在正常营地模拟 3.40 秒受到干扰，原射击/维修时间 3.75/8.25，实测变为 4.75/9.25，保护在 7.40 秒结束。另于保护到期后连续恢复三次，既不重启保护也不重复记功。秘宝的两入口独立通过。安卓签名包的可见操作待候选就绪。见[全部相位](verification/root-phases-final.log)、[营地双动作](verification/root-camp-dual.log)、[保护期后恢复](verification/root-expired-restore.log)、[秘宝模拟](verification/root-treasure.log)。

主代理另启一个全新账号，通过真正的本地 ENet 单人房间完成制造、实装、出击，在保护期内主动断线重进，随后撤退并从普通档案读回同一实体的有效干扰记录。此轮客户端采用无渲染模式；安卓视觉与触控另验。[独立联机日志](verification/root-enet.log)。

在签名 1008 的安卓模拟器独行对局中，已改装双足的 Copper Step 令废轨斥候进入保护状态，屏幕显示剩余 2.7 秒。主代理独立核对对应权威场次的真实装配及战史，27.10、32.10 和 37.15 秒各产生一次有效干扰；每次保护 4 秒。另在模拟器亲自进入另一真实联机战报、选中对应事件并冷启重登，确认按施修/干扰机真实身份留存。[安卓实战](verification/signed-battle.png) · [签名包战史与装配](verification/root-signed-battle.json)。
