- [x] 1.1 独立常驻容器定时采样档案 HTTP 与四类房间待结算文件，保留 7 天并提供近况与告警查询。
- [x] 1.2 复验正常、边界与恢复，更新索引和自测证据。
- [x] 1.3 主代理独立复验。

运行 python -B tools/operations/check_health.py 复验连续失败、队列过龄、恢复、重启读库、过期数据与缺失卷。常驻容器在真实内测网络达到健康状态；重启前后的查询包含相同旧样本，四个结果卷只读。[隔离告警测试](verification/check.log) · [重启前](verification/before-restart.json) · [重启后](verification/after-restart.json) · [运维手册](../../../../docs/internal-test-operations.md)

主代理核对运行中采样容器四个结果卷均只读，独立历史卷可写；重启采样容器后查到重启前记录及新增样本，同时在隔离环境验证连续异常与恢复。[独立复验](verification/root-health.json)。
