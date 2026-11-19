## Why
满编西阀镜头的机体只占几十个屏幕像素。当前阵营环已经显式使用低面数网格，履带机显示网格则含导入的几何细节层，需要测量实际可省的图元、画面变化和移动端收益。
## What Changes
在隔离场景比较履带机 Model 可见网格现行 lod_bias 和 0.35，保留战术阴影、装备、标记、动画和渲染分辨率。
## Capabilities
### Modified Capabilities
- device-battle-baseline
## Impact
M06，依赖 1036 快照及泵站三席场景。
