# Proposal

## Why

正常战斗采样被真实Android启动连接错误拦截：a5三次TCP发起失败/err25，不能以旧超时或主机健康定因。先补同客户端有限启动证据，避免重复整场与猜改产品参数；这是完整可玩版M01入口可靠性、M06定位及M23实际交付的必要前置。

## What Changes

- 直接复用1077已存在的“连接诊断、版本与反馈”页：它显示实际profile_url并以独立HTTPRequest读取同一compat。先观察原入口→现诊断→一次返回，不新增产品观测代码或重建trace包。
- 新增本change的有限QA流程组合，复用M06单profile/设备RPC/既有资源归属与收尾。只保实际端点/页面结果/原日志/有限服务事件，不登录、不记录认证内容。
- 只观察现有行为；保持timeout6、use_threads、预览组合顺序、最多两次读取重试、写请求/认证门禁及场景恢复语义。不同原因分列，不据日志错误码猜网络根因。
- 先工具静态与无资源边界控制，再另审单profile/一AVD/无账号场次的既有APK观测；旧1077不覆盖、旧a5不补跑。若仍缺证，再评审产品内trace或同UID socket切片，当前不加入。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无。纯内部诊断观测，不改变产品规格；skip_specs=true，不为通过验证虚构新玩法要求。真正恢复策略或连接修复需另行评审。

## Impact

主责M01；关联M06/M23及M07/M17认证输入。允许范围为本change限定工具和必要M06生命周期复用接口，最终文件级AR签收后才派实现；不改任何产品/服务/模型/网络协议/数据库或商业化。依赖[产品边界输入](../../../build/architecture-review/m01-startup-compat-boundary-input.md)、[既有诊断复用预选](../../../build/architecture-review/m01-existing-diagnostics-test-input.md)、[a5原失败根签](../m06-current-release-native-profile/verification/root-normal-a5-result-review.md)。正式测试/资源收尾由test_lead执行，进度代理维护原页。
