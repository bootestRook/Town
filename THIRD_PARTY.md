# Third-party inventory

The scaffold source and sample SVG are project-owned and released under the repository MIT license.

Godot 4.7.1 is an external engine dependency and is not redistributed in this repository.

## 小镇地图参考资源

2026-09-28，按用户提供资源并明确允许原型使用的要求，导入《佣兵小镇》本地拆包中的 46 张地图/建筑/装饰 PNG。参考档案根目录为 `F:/GameResearch/佣兵小镇`；对应本地 APK 的标识见研究报告。未复制其业务源码。

项目内文件位于 `art_source/town/`、`assets/runtime/town/`。每个资源的精确原路径和 SHA-256 见 `art_source/town/provenance.json`，运行时映射见 `data/source/resource_bindings.csv`。这些文件登记为 third_party，不属于本仓库 MIT 授权范围，也没有被标记为已取得独立再分发许可。

所有者：prototype_team；用途：本地 Godot 地图原型；更新方式：显式运行 `tools/import_town_reference.py`，固定选择 common 地图，重新验证来源和外观。未来替换时保留逻辑资源绑定接口并替换对应美术；没有自动更新或网络依赖。

When adding a dependency, record its name, version, source, license, shipped files, platforms, owner, update policy, replacement plan, and release obligations here and in the machine-readable release inventory.

## 建筑二级页面与角色参考资源

2026-09-28：`art_source/operations/` 与 `assets/runtime/operations/` 包含本轮生活/交易/装备页面素材、字体、物品图标及源 Spine 烘焙序列。精确映射和 SHA-256 在 `art_source/operations/provenance.json`；源参考目录只读。Spine 文本副本仅统一 UTF-8/LF，游戏业务代码为本项目实现。所有参考美术登记 third_party，沿用上节用途及权利归属说明。

离线转换工具：PixiJS **7.4.3**（MIT，https://github.com/pixijs/pixijs），pixi-spine **4.0.6**（包内 SPINE-LICENSE，https://github.com/pixijs-userland/spine），Playwright **1.58.2**（Apache-2.0，https://github.com/microsoft/playwright）。仅用于 Windows 本地工具 `tools/bake_building_spine.cjs`，缓存在 `.godot/bake_tools/`，不进入游戏运行时或发布清单。所有者 prototype_team；版本固定，手动更新并重新烘焙/校验。游戏只消费 PNG，无 Spine 运行时依赖。
