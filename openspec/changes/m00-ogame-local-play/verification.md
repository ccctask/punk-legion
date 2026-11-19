# 主代理独立验收

2026-11-09，通过。M00 外部参考游戏本机 Docker 试玩。
来源 commit：1138ade97b26a166e5e773732957294f369517da。
数据来源：本轮独立新卷、原安装器全新建库、原注册流程 player；没有历史数据导入或迁移。

独立 player cookie 会话验证 frames、leftmenu、overview、resources、buildings、research入口、techtree、fleet、galaxy 均HTTP200，无PHP fatal/SQL错误。研究入口提示尚未建研究所。当前浏览器自动化不可用，未做视觉验收或中后期战斗验收。

通过页面提供的 buildings.php?cmd=insert&building=1 发起金属矿1：初始500金属/500晶体，扣费60/15，107秒队列。到期重新登录刷新后显示金属矿等级1；只读SQL对账 metal_mine=1,b_building=0,b_building_id=0。没有加速或注入资源。player以此开局进度交付。

导航完整账号JSON调试输出已移除，最后页面确认无password JSON。登录JS修复已静态核对。本机8097、DB无发布端口、邮件禁用已核对。

证据均位于工作区 .local/ogame/verification：root-pages.json、root-buildings-before.html、root-build-started.html、root-build-complete.html、source.patch、self-test.md。部署说明位于工作区 .local/ogame/README.md。

资源复核：仅保留 ogame-play-20261109-web-1 与 ogame-play-20261109-db-1 供用户持续试玩；数据库healthy，Web发布127.0.0.1:8097，独立卷ogame-play-20261109_ogame_data。无额外测试进程或容器；未动原有Punk服务。停止命令见design.md。
