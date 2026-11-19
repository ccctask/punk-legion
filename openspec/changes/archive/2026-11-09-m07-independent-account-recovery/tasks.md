- [x] 1.1 Implement authenticated issuance and rotation, private verification storage, bounded redemption and atomic password/session changes with fresh-account tests.
- [x] 1.2 Implement optional account-menu issuance and recovery from the normal login screen, with mobile-sized handling and no sensitive local evidence.
- [x] 1.3 Independently exercise a clean second client, concurrent redemption, lost first response and re-entry with the same robot and private stock; verify cleanup.

主代理以独立的会话文件分别启动两份 Godot 客户端，实际截断成功响应的正文。新端按提示登录原账号与命名机体，原端冷启回到登录页。全新 HTTP 用例核对并发消费、原库存与基地。[双端实测](verification/root-devices.json) · [并发核账](verification/root-accounts.json) · [发行源清单](verification/root-manifest.json)。
