# Root手机安装及连接结果验收

root，2026-11-17。已直接审查physical-phone-install1083-a1/install-result.json与原ADB输出：唯一USB安装Success，exit0，14.31秒，无超时，Job与同实例余留为空；没有重装/清数据或代注册。读手机实际包信息versionCode1083、versionName0.1.0-beta.1083，包源9f4d8af2…及原签名已由独立产物审计确认。

已读connect-diagnosis-a1/phone-http/godot.log：命令在手机/system/bin/curl执行，对192.168.31.170:33380/v1/beta/compat实际HTTP200，协议上下界均5。已亲看该目录current-ownapp.png，手机当前已显示私人基地、机体、核心及基地菜单。用户报告的“连接失败”发生于部署切换期间，当前连接已恢复；没有证据判定旧错误的唯一因果，不要求再次Retry。

本签收仅覆盖指定手机安装、当前入口画面与HTTP连接；不代签手机UDP战斗、所有玩法、帧率、触控全流程或声音听感。真机性能与声音终验由负责人试玩，未执行。未操作用户账号/命名，保留App供用户使用。

服务器部署另见root-lan-result-review.md，稳定APK另见root-artifact1083-result-review.md。电脑保持当前WLAN192.168.31.170及六服务运行，手机需在可达的同一局域网；宿主IP变更须重新评估构建端点。资源收尾与文档登记由测试/进度代理提交后另行核签，不以当前画面代替资源终态。
