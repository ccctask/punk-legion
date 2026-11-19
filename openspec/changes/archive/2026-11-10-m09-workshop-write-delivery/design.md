## Evidence and scope
读docs/README.md、生效android-private-beta规格和上轮`2026-11-10-m09-android-direct-confirmation-diagnosis/verification/root-review.md`。已有源码与1074冻结server.py摘要相同。仅测试现有成功write回应的有限保活，不增加网络层、重试次数、数值或新玩法。

## Phase gate
主代理先核对端点测试APK，除runtime_endpoints.cfg及对应sparsepck项/本地测试签名外，所有载荷必须与正式1074逐字节相同，尤其workshop.gdc完全相同。各阶段独立新项目、六新卷/44业务表全空、1个profile容器，同32980端点顺序运行；同一模拟器，阶段间清本轮测试包数据并正常新注册，绝不导旧号。A/B/A2都不带客户端或服务端诊断日志。保存源哈希、配置/卷/实际ID和前后端截图、真实账本。

每阶段固定路线：新号从基地入工坊，以相同底盘/部件及名字保存v1、制造一台，保存v2、制造一台，保存v3、制造一台。每笔只点一次，8秒后记录首轮确认/待确认、原收据和扣费；有失败最多按现有入口核对两轮，不生成替代编号。若仍pending则停该阶段并保留证据，不捏造后续样本。最多30分钟整轮设备操作，3阶段数量预先固定，不因结果不理想无限追加。

## Decision and implementation
B只在status200、HTTP/1.1、无Transfer-Encoding、唯一合法正Content-Length且无Connection:close的成功design/build响应沿用原6秒窗口，其余条件原样。若无日志对照显示A类确认失败、B路线首轮成功且账目一致，可选为有限交付改善；A2若未再现要写明，不能声称所有底层故障已定位。若B仍失败或无改善证据，保留候选而不改正式源码。主代理根据实测独立定案，之后开发子代理才修改唯一运行文件。

回归使用本轮新库和真实HTTP连接：design/build同键只扣一次，Content-Length实收一致、连接可复用且每次认证（缺/错token返回401并关闭），显式Connection:close、HTTP1.0、错误及无关写接口继续关闭，空闲约6秒释放；不扩至所有API，不加入迁移用例。既有实装/读取策略保留。

## Verification and cleanup
主代理独立验包、核对实际运行源/截图/账本及协议边界。开发自测不代表主验。手机每阶段6笔在8秒取图属于已知路径自动操作，不代替真人易用性或实体性能。

登记所有实例PID、AVD、端口、项目、卷及共用关系。A/B/A2顺序运行，阶段结束立即保存证据并精确down删除专属容器/网络，卷保留；失败/超时亦清理。全程保留1074六服，收尾退出模拟器/专属ADB/辅助进程，根独立复查零残留。原数据和实际试玩版本不因源码自测通过而更换。
