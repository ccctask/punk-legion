# Tasks

## 1. 构建与审查

- [x] 1.1 核实USB授权、设备ABI、当前包与局域网绑定，交付discovery-a2证据；root已完成实现前设计签收。
- [x] 1.2 最小修改构建端点和复用监督入口，提交差异、默认/非法参数自测及精确构建输入供root审查；见root-source-review.md及root-build1083-result-review.md。
- [x] 1.3 按签收输入签发一次递增LAN包，独立核实际源、签名、端点、ABI及资源清理，记录工具SHA；见root-build1083-result-review.md及root-artifact1083-result-review.md。

## 2. 服务及安装

- [x] 2.1 持久LAN配置经解析检查、活动核实后部署，测试并记录双入口/新CID/网络/防火墙实际状态；见root-lan-result-review.md，手机实际可达另在2.2核验。
- [x] 2.2 指定USB手机安装并启动，记录实际版本及正常服务连接，保留用户终验边界，清理临时SDK资源；见root-phone-install-result-review.md及root-resource-close-review.md。
- [x] 2.3 root独立审查证据及边界后签收；进度代理同步包用途、试玩入口、限制及文档链接；见root-final-delivery-review.md。

## Workflow follow-up

- 本轮运行配置保存在稳定operations目录。当前根签仍被试玩索引与runtime引用；由root在后续统一文档链接维护时归档并验证引用，不在手机安装任务中移动仍被使用的证据路径。
