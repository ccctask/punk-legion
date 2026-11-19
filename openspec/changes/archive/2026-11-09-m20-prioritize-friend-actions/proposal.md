## Why
好友页面每两秒自动刷新。可用的保存和援军按钮在刷新请求占用 HTTP 通道时会直接丢掉点击，玩家看不到确认也不知道是否需要重试。
## What Changes
让用户手动操作优先于在途只读刷新，保留点选对象并防止连点重复写入。验证真实 HTTP 和安卓输入。
## Capabilities
### Modified Capabilities
- friends-and-aid
## Impact
M20 好友页请求调度与按钮反馈。
