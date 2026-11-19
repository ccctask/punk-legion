## 1. 冻结构建与本机服务门槛

- [x] 1.1 子代理从1075冻结源仅叠加三个M15签收文件与新env，生成1076签名包、515文件清单及逐项APK差异证据；起唯一新profile并核全72表/六新卷/实际运行源。主代理独立核签名、版本、ABI、包内容、冻结输入和空库后才放行AVD；同组记录工具自测与操作文档。

  root-freeze-gate、root-inherited-scene-audit、root-package-gate及root-build-gate均由主代理独立执行通过。515源仅4键变；492ZIP项/174资源明确3源与3继承编译派生，12模型仅忽略已知生成node_ids后相同，native/dex逐字节相同。新profile feceea6a/33380，72表仅key1、六新卷、28源逐项核；当前只签构建/初始服务，安卓功能尚未验。

## 2. 安卓真实操作与独立主验

- [x] 2.1 专职测试代理维护逐要求覆盖表，核现有同正式APK/515源/服务与相关环境的证据适用性，复用充分的R3六故障，不默认再跑完整矩阵；用新库/新号/新场次补正常双席双方有效指令、各自撤退及一次费用/结算、派遣释放/累计、收工与冷启。主代理只审查原始日志/截图/SQL、断言、限制及清理后签收，测试执行不得冒充主代理签收。

  当前：R5正常双席、精确指令、双方个人结算/派遣释放/累计/收工冷启已由test_lead实际补证，[root功能签收](verification/root-r5-functional-review.md)通过。R3六故障有界复用，R4原暂停结论不改。AVD清理警告及空android.log明确保留，实际设备/Job/凭据终态清零；1076稳定六服已由root接管当前试玩，1075已退役，运行交接与文档/主规格同步已签收。主代理只审查规划与证据，没有重跑完整矩阵。

| 轮次 | 实际结果与边界 | 证据入口 |
|---|---|---|
| R1 | 8个正常API夹具后，安装前ADB启动超时；更早的沙盒拒绝发生在API前。未签任何安卓功能 | `verification/android/dev/`、`verification/android/failure-private-cleanup.json`、`verification/release/service-cleanup.json` |
| R2 | 安装/命名/首次读局部完成；切号未重新定位，未知身份提交导致停止。具体回车或错位原因不能唯一归因。原代理关闭1/1和被覆盖清理计数0按失败保留 | `verification/root-r2-failure-cleanup.json`、`verification/android-r2/dev/` |
| R3故障 | 六故障开发实测及root原始请求/个人账目复核通过；真实HOME同PID、后台无轮询、准备POST只一次。此为历史开发侧实测与root证据审查；按新分工核依赖充分可复用，未覆盖项仍由测试代理补验 | `verification/root-r3-dev-fault-review.json`、`verification/root-r3-dev-home-review.json`、`verification/android-r3/dev/fault-summary.json` |
| R3直连 | 陪测JOIN比手机晚30.317秒，只有1/2开战/缺席收据，无双方接受指令，完整双席未过。根因不能断言引擎慢，不改30秒规则 | `verification/android-r3/dev/direct-failure.json`、`verification/android-r3/dev/dev-self-review.json` |
| R3收尾 | root核6容器/专网删除、6卷保留、设备/代理/peer零残留；失败证据不覆盖 | `verification/root-r3-failure-cleanup.json` |
| R4暂停 | 工具/新空库/六服已核；两席到场和双方commanded/participated已取证，手机exact seq及正常结算/释放/累计/收工冷启未完成。6容器/网及设备已清、卷保留。不得将暂停/超时算通过 | `verification/root-r4-tool-review.json`、`verification/root-build-gate-r4.json`、`verification/root-direct-gate-r4-dev.json`、`verification/android-r4/dev/pause-handoff.md`、`verification/android-r4/dev/pause-cleanup-final.json`、`verification/android-r4/dev-execution-plan.md` |

## 3. 试玩交接与资源收尾

- [x] 3.1 测试代理执行交接与清理、主代理审查签收后交接1076六服，按实际ID及原配置删除1075退役容器/专网并保卷；核实并精确清理旧punk-legion开发5容器，保留Blender资产库及OGame共用服务。清理AVD/专属ADB/代理/peer与被替换profile容器，独立复核端口、docker ps -a及网络零临时残留，更新试玩/索引/原进度页和主规格。失败不切试玩，及时清本轮候选资源并保留原失败证据。

  [root交付签收](verification/root-review.md)通过。稳定配置在build/private-beta/operations/1076-r5/world；重建核源/健康/transport、个人数据摘要不变，删除替换R5六个与1075六个共12容器/旧专网1，双方12卷保留，三共享实例保留，临时/退役容器及设备进程为零。主规格新增合作恢复要求，试玩/合作文档和索引已更新；资料空间总览46/看板87/阶段33/首日59已读回1076当前试玩及保留缺口，归档后仅收口归档路径。

## Workflow follow-up

- 只在主代理验收与规格同步后归档；保留开发自测、主验和实际试玩版本的区别。
