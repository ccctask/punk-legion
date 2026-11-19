# 部署校验差异签收

root，2026-11-17。作为design.md的本轮明确补充，不改变已锁定构建输入。

既有 stable_delivery_once.py 的 validate_identity 允许 keyword-only expected_config_files=None，默认原三配置不变，LAN调用传批准四配置。expected_ports按同target/protocol累计HostIp列表，修正字典推导在双绑定时覆盖前项的问题；继续精确比较完整PortBindings与实际发布列表，其他身份、镜像、挂载、命令、环境和网络断言保持。

此差异复用原资源身份校验，不新增部署状态机。默认单绑定、LAN双绑定及缺失/多余绑定必须可区分；纯检查不代实际部署。

实际a1差异追加签收：root读取017-identities/godot.log，profile与camp的NetworkSettings双绑定顺序与HostConfig相反，完整HostIp/HostPort内容一致。这是校验工具的顺序假设问题，不能当产品绑定失败。批准同函数内局部规范化完整绑定列表后比较：按HostIp、HostPort排序，保留完整字典、列表长度、重复项和全部端口key；HostConfig及NetworkSettings均与完整expected精确比较。禁止转set丢失重复、忽略额外字段或允许通配IP。a1失败原件保留；恢复实际状态先后证，再依据当前实际CID给a2独立门，禁止重用旧身份冒充新部署。
