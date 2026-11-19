# 设计与资源归属

状态：生效；维护：本任务主代理。模块 M00 外部参考环境。

源码：https://github.com/wap-game/ogame，具体 commit 见 `.local/ogame/verification`。PHP 5.6 + mysql 扩展适配其原版 mysql_* 调用；MariaDB 10.5 以空 sql_mode 运行原版建表语句。通过原安装器全新创建表及管理员，通过正常注册创建 player，未运行任何旧库迁移。

Compose 项目 `ogame-play-20261109`，目录 `.local/ogame`。保留容器 `ogame-play-20261109-web-1` 和 `ogame-play-20261109-db-1`，供用户持续试玩，不与其他任务共用。入口仅 `127.0.0.1:8097`；数据库无宿主发布端口，独立卷 `ogame-play-20261109_ogame_data`。DB 位于内部网络，Web 同时接入前端网络以发布端口。PHP sendmail_path=/bin/true，安装过程不外发邮件。

修正原版登录脚本的 PHP/JS 混用和失效焦点；移除页面顶部完整账号调试输出。安装入口及 .git HTTP 访问被禁止。无玩法数值调整，无旧版本适配。

停止：`docker compose -f .local/ogame/compose.yaml stop`；继续：`docker compose -f .local/ogame/compose.yaml up -d`。默认保留卷和验收文件。

验收采用独立 HTTP cookie 会话和只读数据库对账；浏览器自动化当前不可用，未宣称截图或视觉验收。科技/造船仍依原版前置建筑解锁；单人新宇宙没有其他真实玩家。完整战斗和中后期科技不在本次启动验收范围。
