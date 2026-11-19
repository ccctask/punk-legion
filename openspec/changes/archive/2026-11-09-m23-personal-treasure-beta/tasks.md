- [x] 1.1 签发冻结候选，验证新卷和服务端点。见[签名](verification/signed.json)、[空库](verification/empty.json)、[五路握手](verification/transport.log)与[交接](verification/handoff.json)。
- [x] 1.2 安卓验证组队与同场准入，完成模拟器收尾。见[实录、动作裁切与收尾](verification/android/README.md)。
- [x] 1.3 主验核对包和真实回执，切换当前入口并停止上一版服务。

1016 已验证安卓准入，实际战场动作栏超出安全显示区域。当前试玩入口继续使用 1015。修正 m24-mobile-treasure-actions 后以更高版本号 1017 制作候选；复用本模块已验的编队规则，使用新环境验收实际带货撤离，再切换当前入口。


1017 货物实收、版本切换与资源清理见[最终主验](verification/root-acceptance.md)。