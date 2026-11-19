## Decisions
参考 Warframe 按任务匹配及单独的邀请码模式。锈轨采用明确按钮「寻找队友」，凑齐两人立即组成现有大厅，由双方各自准备、队长出发。轻度试玩以最快组成可出发队伍为目标；可再邀请第三人。私房、泵站、已开始场次隔离。[官方多人指南](https://www.warframe.com/fr/news/multiplayer-guide)
## Lifecycle
服务端在同一写事务选择仍有效的最早等待者并建立唯一房间。等待有短租期，客户端仍在搜索时续期；离开或取消停止搜索。匹配与取消竞态由服务端决定，已经成队则显示权威房间和正常离队入口。准备及出发沿用既有结算。新数据库验收。
## Interface
POST /v1/party/match 携带本次搜索唯一的 key 开始或轮询续期，每份租约有效 15 秒，POST /v1/party/cancel_match 使用同一 key 取消。响应沿用 party 状态，并增加布尔值 matching 和仅本人可见的 match_key。普通状态读取不续租。

