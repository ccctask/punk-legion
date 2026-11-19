# 窄工装准备（未正式运行）

2026-11-17 test_lead，依据design「验收与工具范围」及已定PageRefresh租约API。只使用既有GUT9.6.1、Fixture线程生命周期、OwnedJob与runner，无新资源平台；手机/当前R2未动。

实际修改仅三测试文件：

- `tests/godot/run.py`：新增独占normal `refresh`组/严格6个用例；只组装实际`client/page_refresh.tscn`依赖，旧默认组不引入该新测试或组件，旧negative/skip/empty控制不扩。本组复用原Fixture/OwnedJob/错误和空集门、非daemon线程join/监听终态，没有第二套runner。
- `tests/godot/http_fixture.py`：新增白名单`GET /qa/page-refresh/{case}`，200/一次503/401和三个held请求；数据仅scheduler transport revision/固定server_now，不假扮profile/库存或结算。沿原线程/stop_event/close；只有本轮精确case+请求number取消标记允许连接关闭，其他异常记录handler_failure并令正式结果失败。原POST preview分支不改。
- `tests/godot/test_refresh.gd`：6个实际生产组件用例：可见/available合并首次真实GET、inflight focus+resume只排一次、hide取消无callback再开+旧settled/defer不能解新租约、实际503自动5秒后成功+401终止、组件销毁后的held响应、configure换上下文拒旧租约。使用current_lease和settled/defer lease参数；没有复制调度算法，未声称是假owner适配器已验证所有业务页。

未来准确门的入口形状为现runner `prepare --groups refresh`，实际prepare成功/闭包锁同后 `run --groups refresh --mode normal`，均固定本机引擎参数、新run-id/label；当前未创建stage、未运行Godot/import/check-only、未启动socket/thread/服务。helper实际闭包现观察为2个生产文件，未冻结开发中源码。完整命令和预算待root源签，不列成当前已批准运行。

必要开发纯自检见`tool-pure-preparation.json`：Python源码compile、4个响应正例/3个参数拒绝、runner6用例注册/实际依赖读取，资源0；另从固定GUT压缩源码静查所用assert API存在。**GD解析、真实HTTP/6例结果尚未执行**，不能标passed或勾tasks。

尚需最终候选后补的独立实际业务断言：A页真实HTTP发射器/token/对象失效、编辑草稿不被GET覆盖、pending严格GET/原有限同key POST恢复分别计数、base未知写原receipt核对；B页world/friends/repair等原轮询的隐藏/前后台/到期和当前服务器锚点。已同两开发方约定接口，待候选不在本阶段假造生产API。G首胜实体钻头仍需独立新库正常真实Solo链后接实际workshop，不由该无DB组件fixture冒通过。

准备未触旧升级/迁移脚本；后续实际服务fixture仅空DB正常initialize/本轮生成账号与场次。Android仅最终必要的一次模拟器烟测，当前没有设备或用户服务执行许可。
