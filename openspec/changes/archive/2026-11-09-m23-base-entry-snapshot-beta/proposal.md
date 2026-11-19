## Why
基地启动时单独读取全工坊会阻断首屏，已在 1023 普通入口复现。安卓内测需要在真实档案服务与签名包中验证修订后的首机数据读取，以及此前已验的秘宝场景组合。
## What Changes
从签名 1023 上集成已通过的 M17 与 M24 改动，建立独立服务，验证安卓基地登录、同版重登和两侧撤离门。
## Capabilities
### Modified Capabilities
- android-private-beta
## Impact
M23 签名内测、档案兼容能力、Android 实测与文档。
