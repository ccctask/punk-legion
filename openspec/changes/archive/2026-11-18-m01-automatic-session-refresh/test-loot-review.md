# G真实首胜与实体装配工具准入

root，2026-11-17。依据research/test-selection.md、test_business准入及test_lead/g_reuse_readonly对实际Solo/旧peer的只读核。只在P1–P5执行和清理完成、保全工具as-executed后实现；不得在已启动的输入锁内改变runner/fixture。

玩家问题是首胜得到可装配的实体钻头，并自动进入当前工坊，不是重做掉率/履带实体体系。M14/Solo拥有实际战斗和正常open/settle，M08库存事务拥有UUID/奖励，M09拥有原refit/兼容/原件归还，测试仅组合真实入口和观察。当前正常首次胜利已有100%钻头；材料changes、recipe权限和parts实体分别断言。

允许最小测试文件：现tests/godot/run.py增加独占refresh_loot组及必要stage/资源预算；现refresh_profile_fixture.py增加本组可选独立room key和固定只读账；新增test_refresh_loot.gd承接实际GUT客户端/工坊与旧solo_peer的route/collect/repair小循环；必要新增refresh_solo_host.gd仅为真实Solo宿主观察本轮stop文件后正常quit。复用现GUT、真实5个Autoload、Fixture和process_owner.owned_run，不修改process_owner、不新增资源管理器/协议或产品hook。若无需host驱动则省略，若确需其它文件/生命周期先报告具体差异。

run拥有独立临时HTTP/新SQLite、专属spool/mission保存路径/密钥文件和一个非daemon监督线程。线程内使用原owned_run持Solo服务进程；GUT另由原owned_run持客户端。宿主为真实Solo --solo-server，明确锁deploy/server.godot的20Hz配置；host驱动只接本轮stop文件，不推进/伪造模拟。正常结束或客户端失败均由finally发stop、join线程并核两个Job/端口清空，外层共同监督覆盖异常/超时，不能仅让长驻服务等540秒超时当正常收尾。线程不与模型对话、不能拥有独立下一轮任务。

新库initialize、正常账号/API准备；正常start只一次，记录当前actual admission并以私有文件/env给client，不公开token/secret。Solo自己调用internal open/settle，客户端只通过原ENet命令指挥；不调用trusted settle、不写历史spool、不改expires/结果/任务420秒上限。沿旧peer逻辑但去掉本轮无关主动断线，内部wall上限450秒，集合/指令只按实际状态与原冷却处理，不重造战斗规则。

同账号胜前打开真实workshop并记录已有available UUID；自然首胜后receipt.part.id/definition=drill、库存同ID、当前页无需刷新自动出现同ID。通过真实Slot/Item metadata选择、Install/refit入口装同一ID，核原收据installed、机器人weapon.id、钻头移出available且非救援原武器归还，以及实际Robot显示/功能定义。无自动POST、更不以OPTIONS一直有“钻头”字样充证明。若实际战损/任务状态不允许装配，走正常恢复或明确报缺口，不直接写状态。满仓旧规则未改变，本轮不再打一场重复完整Solo；若无获签容量夹具，明确未重验，不能将主正例外推为满仓通过。

真实game及profile递归生产源、配置、工具、GUT均锁前后SHA；无用户R2、手机、ADB、模拟器、容器、旧库或迁移。准备预算另列；工作共同540秒、内部Solo450秒/前后链90秒、收尾30秒；仅一服务引擎+一客户端+一HTTP fixture。源码/准确命令/输入锁和实际资源准入交root签后唯一执行，失败保原并分类，不自动重试到绿。
