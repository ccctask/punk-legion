## Why

M06三席30FPS出口未过。已有guest调度和无符号原生采样无法区分宿主等待，当前短基线也不支持逐帧因果归因；继续重复游戏采集没有已证增量。先证明本机ETL解析和vCPU身份链可用，才能决定下一次实战采集是否值得开展。

## What Changes

- 本change仅M06测量前置工具：内置WPR短采已知TID的busy/sleep进程，用tracerpt检验真实CSwitch/ReadyThread及时间字段能否解码，并独立对账线程CPU时间。
- 解析门槛通过后，至多一次无游戏AVD，通过QMP只读query-cpus-fast核4个vCPU与Windows实际线程ID/进程及guest拓扑；不依赖旧空线程名。
- 主代理独立复核后记录可用范围、失败停止条件与资源清理，交进度代理同步。不给游戏CPU/GPU瓶颈结论，不修改产品。

## Capabilities

无产品规格变更，`skip_specs: true`。生效device-battle-baseline和M06原出口不变；前置工具通过不增加原10/13计数。

## Impact

仅本change verification及专属build目录。最多两次各不超过5秒宿主采集，第二次仅在首次明确配置/入口失败且清理后经主代理放行；解析同一ETL无需重采。至多一个无游戏AVD、10分钟上限，不起容器、不碰1075试玩、不安装SDK/WPA/额外依赖，不改模型、画质或编队。
