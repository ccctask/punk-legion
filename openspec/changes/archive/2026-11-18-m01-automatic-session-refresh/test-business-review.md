# 真实业务页测试工具准入

root，2026-11-17。已读research/business-page-tool-plan.md，准其明确4文件及真实场景组合，不代实际运行通过：新增tests/godot/refresh_profile_fixture.py、test_refresh_pages.gd，微调既有http_fixture.py可选真实handler和run.py独占refresh_pages组。原GUT/Fixture/OwnedJob是资源所有者，不新增第二框架或资源管理器。

选择本轮文件标记作为唯一窄控制面。真实当前profile Handler在新空SQLite执行普通API/认证/事务，测试子类只控制指定GET失败/延迟及已提交唯一POST响应的hold/drop；必须先核实际提交点，不造各业务JSON/receipt或新的通用查询API。请求账按当前case/method/route/owner/请求ID限定，不记录密码/token。沿原stop_event、非daemon join、监听/Job后证处理成功/失败/超时。

stage含profile/base/workshop/store/world/friends真实场景、五个真实Autoload及资源/import/UID闭包，不空Room stub。只设置本轮隔离user_dir、测试入口/协议5等运行配置，不使用用户会话。生产clock若采用注入，仅独立fixture当前实际now入口，不改主机或全局时间，不在生产加测试hook；无安全注入则报差异/采用真实等待，不编造时钟证据。

P1–P5覆盖真实初库存/生产、实体库存/草稿、world/friends外部变化和网络恢复、store未知写不新增POST、base原key保存核对。工具代码先纯检，实际运行等A/B最终源及准确闭包签收。准备90秒，5段工作120秒/清理20秒，一headless/一loopback fixture，无ADB/Docker或用户R2操作。

G首胜链可复用真实Solo和peer且同新数据接workshop，不直接settle、不读旧spool、不执行含迁移旧整组。540秒工作/30秒收尾为预算方向，旧peer310秒及回连策略的具体窄改/源配置/资源所有者需另补签后执行；满仓前置标来源，不重复第二场完整Solo求绿。

组件初始化前台微差另准为queued_wake及FOCUS_OUT门禁，不改owner/API；test_refresh新增第7个真实初始held请求例并复验受影响组件依赖。原6例保旧源通过，不冒新helper已验。

调试协议约束补签：实际Endpoints.headers仅private_beta feature发送协议头。P1–P5准使用真实debug路径，独立loopback fixture显式BETA_REQUIRE_PROTOCOL=0；保正常token/session鉴权，不能改生产Endpoints或手造发布feature。此选集只签debug页面与真实业务，不证明发布包协议5。compat仍当前实际protocol_max5；原未改发布头路径可沿已签1083证据及后续APK审计核查，Android平台差异选集再说明实际协议与环境。本项取代前文对所有headless请求均带协议5的预想，不能在报告抹去差异。
