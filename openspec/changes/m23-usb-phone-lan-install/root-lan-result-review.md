# Root局域网部署验收

root，2026-11-17。签收 physical-phone-lan-deploy-2026-11-17-a2-continuation：实际部署28.37秒，outer28.73秒、exit0、无超时/Job余留。已审实际result、完整身份、READY、12监听、HTTP及卷/key/shared后证。六业务服务均保127.0.0.1并新增192.168.31.170原端口；宿主LAN compat实际HTTP200/协议5。同镜像、六命名卷、认证key及业务源保持，无迁移/新库/账号写入，其他共用服务未改，旧CID已退役删除。

当前项目仍punk-private-beta-1082-delivery-r2，网络be6de4d8…，持久四config（原三项加operations/1082-delivery-r2/lan.compose.yaml），env原formal.env，root接管当前六服务用于模拟器及手机试玩：

- profile 6473b8b20293ec1f5b3ee00981573e79a3d7a981f8fca8d51b9e88f26ffdf67a
- expedition 04642cf429dd6e25b07d40000744d1051e40e86c49148fb6f42e8018b4dddfee
- party ed1fe76357cd3fbe62af79f4c9250783bfe0be2ddeaf96a806f88e5f338a346a
- camp af159b3d0f651b1268eec0f9dfa811640aea6ffef136ad1af30ee8089b501257
- room 3bd1a208eeb690f01c5dafd378b2b0e3377e94fe6b982f9b2851a9572eec5eb8
- treasure 5cd85bff6249a9936aa1b83fb35b051e100c4358dd67d71209e8eb9495554e65

a1失败为工具对列表顺序的假设，已恢复后独立后证；a2首次前置引用旧CID而停止在up前，修正只读活动命令目标后续接。原失败均保留，没有重发已完成业务写入或自动重试到绿。工具源改动另见root-deployment-review-amendment.md与实际diff。未改防火墙、Mihomo/路由。命名卷和镜像保留，六服务是当前使用实例，不是待清理临时容器。

本签收确认服务器部署与宿主可达，不代手机网络可达、手机UDP玩法、实体性能或声音听感。手机实际失败/恢复另记USB验收；严禁用宿主HTTP代签手机。
