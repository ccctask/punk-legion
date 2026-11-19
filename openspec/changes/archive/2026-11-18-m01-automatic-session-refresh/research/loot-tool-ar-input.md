# G最小真实掉落工具AR输入（待root签，不执行）

主责M01自动读取，关联M10实体部件/M14真实Solo结算。用户R2和手机完全不参与。

- 复用当前 `tests/godot/run.py` / `http_fixture.Fixture` / `RefreshProfileFixture` / `process_owner.owned_run`；新增仅 `test_refresh_loot.gd`，该group与P1–P5分开单选，不另造peer或资源owner。
- 新fixture同一空DB/正常新号，私有room key；正常API一次 `/v1/expedition/start` 首机锈轨，原token不注入或伪造服务结果。
- Server QA项目沿 `deploy/server.godot` 五Autoload与明确20Hz，实际Solo `--solo-server`；独立PROFILE_URL/SOLO_PROFILE_URL、SOLO_PORT、ROOM_AUTH_FILE、SOLO_SAVE_DIR及新spool全部由原OwnedJob/finally持有。不得默认60Hz冒服务节拍。
- 新GUT客户端保当前真实Solo Autoload；窄复用 `game/expedition/tests/solo_peer.gd` 正常route/collect/repair状态循环，去与目标无关主动断线，450秒wall内部上界；生产CLOCK_LIMIT420不改。无直接settle/旧result重投/SQL加料。
- 战前已打开同一账号的实际workshop；胜利由真实server保存及正常HTTP结果提交完成。保真实receipt.part UUID/胜负/双方命令原件。
- 不点击Refresh：当前workshop.available与Item metadata应出现同一UUID；正常Install/refit后机器人weapon.id同UUID、钻头退出available/原武器归还，并核Robot实际武器定义/外观节点。不能以OPTIONS内有drill或研究配方证明实体掉落。
- 满仓资格需要单独获审可复现正常API容量前置；不得悄悄SQL塞parts。可复用已签后端事务断言，记录平台/依赖边界，不重复完整战斗。
- 工作共同540秒/清理30秒，最多1server+1client+1fixture。先核无其他Godot与内存；原OwnedJob绝对截止，首错停不换参数，结束保存spool/receipt后精确关两Job/线程/监听、保新DB私密证据。
- 旧check_live_expedition整入口不适用：旧310/320界、两账号并行、outage改expires、down --volumes；不调用它，未执行G。
- 准入尚缺：root对上述新增单GD及runner G专组/fixturekey正常配置的明确签收、精确输入/命令/实际资源gate。P1–P5不因此扩大。

F原生烟测另门最小方向：现成Android Debug（dev.punklegion.client、debug签名、无private_beta）QA入口仅选实际profile场景，通过原Endpoint字段设独立deviceQAport；私有serial adb reverse到fixture动态hostport。宿主PROFILE_URL不自动进入Android。需单独准debug包/URL白名单/HOME保PID恢复/reverse清理；不碰33380或R2、不冒1084正式LAN协议头。工作300/清理至400/outer420沿成熟原生owner边界，先不实现/构建/运行。
