# 区域等级、城门与怪物密度

2026-09-30，承接用户城门及「兽人密林」截图。截图是结构和交互参考，怪物生成规则以本机源客户端和配置为证据；来源入口见 本机来源索引（未随包提供；[资源来源登记](../../THIRD_PARTY.md)）。

## 本轮范围

接入当前世界难度1的兽人密林、亡灵墓地、魔族战场，每区三个密度档。点击原位置城门，查看掉落材料、各档怪物和数量，激活已解锁档位、镜头移向对应野外；点击空白关闭。材料栏可横向拖动，单击查看原物品说明，问号显示该区域原帮助文本。

区域激活不扣金币。源 `MapSwitchItemCmpt.onClickActivateBtn` 调用地图切换接口，没有建造金币成本，不能套用英雄营地的金币升级规则。

| 区域 | 开放进度 | 1档 | 2档 | 3档 |
| --- | --- | --- | --- | --- |
| 兽人密林 | 初始 | 疾风狼3、棕熊3 | 各4；开放牛头人首领 | 各5；开放变异狼、熊；地下城1-30 |
| 亡灵墓地 | 地下城1-9 | 僵尸3、骷髅战士3 | 各4；开放死亡骑士；1-15 | 各5及变异；1-16 |
| 魔族战场 | 地下城1-18 | 魔族武士3、魔灵3 | 各4；开放恶魔首领；1-21 | 各5及变异；1-24 |

其他世界难度需要全局世界难度系统，本次没有伪造该进度，也没有把30个源配置行混为单一区域30级。状态依旧只保留本次进程，与现有项目一致。

## 源代码与规则

- `MapSwitchEntranceCmpt.js`：城门贴图随当前档位 `dt_pic` 切换；`Map.json` 的 `nodeSwitch1/2/3`、`bg` 和 `click` 提供原坐标及130×160点击范围。
- `MapSwitchPnlCtrl.js`、`MapSwitchItemCmpt.js`：按当前难度筛选三行，当前行橙色、锁定行变暗；`gq_id` 与实际通关进度比较。预览中的首领/变异图标不等于额外常驻槽位。
- `FieldMapModel.js`、`c8_map`：区域开放进度和掉落预览。全部11种掉落预览可横向查看；屏幕初始显示约6种。
- `btMapField.js`：初始只加载普通槽位；每种普通怪独立统计创建次数。变异优先，达到30次且概率通过时替换；首领需达到5次、无活首领、距上次首领死亡至少60秒且概率通过。替换后清零对应普通怪创建计数。首领死亡后回到其来源普通槽位刷新。
- 普通刷新间隔前两区10秒、第三区12秒；切档清掉本区域旧怪物并按新配置重建，不影响另一区域。号角战期间拒绝切档，结束恢复所有已开放区域的已选档位。
- `btFightPropertyMonsterField.js`：变异使用 `hp_jy`，其攻击、防御仍取原值。当前表的变异生命是普通五倍；没有额外猜测攻击倍率。
- `btMonsterField.js`、`btCptMonsterCharacter.js`：野外骨骼缩放为 `sfbl * 0.5`，名称位置取模型 `name_point`。已修正旧怪物误用模型 `bl` 的缩放，九种怪物均按这一实际渲染调用链烘焙。

沿用此前已说明的出生占用修正：不照抄源包可疑占用计数，在指定点全部被占时保留死亡槽位等待可用点，不生成重叠演员。已沿用项目的普攻、伤害、巡逻和战利品系统；怪物专属技能、首领/变异额外宝箱系统仍未实现，帮助文案保留源文本，不代表这些扩展已完成。

## 文件与重建

`tools/import_field_reference.py` 生成区域档位、成员、42个原刷新点和15份怪物定义（9种原型、6种变异）。`tools/import_region_ui_reference.py` 导入城门、弹窗与原图标，记录原文件、UUID和SHA256。源文件只读。

领域由 `TownRegionLevels` 管理选择与锁定，`TownMonsterPopulation` 管理区域创建计数和刷新槽位；`TownCombat` 只索敌同区域，切换目标会清掉旧追击路径。固定界面在 `scenes/town/region_*.tscn`，运行时仅生成区域行、图标和地图实体。

```text
python tools/import_field_reference.py
python tools/import_combat_reference.py
python tools/import_loot_reference.py
node tools/bake_hero_spine.cjs --missing
python tools/register_hero_assets.py
python tools/project.py data
python tools/project.py assets
```

改变已烘焙怪物的原尺寸/动作时，须重建对应角色的动画元数据及图集；`--missing` 仅补缺失角色，不会覆盖现有图集。源证据为 `art_source/heroes/field_sources.json`、`combat_sources.json`、`provenance.json` 和 `art_source/region/provenance.json`。

## 验证

`tests/test_region_levels.gd` 检查锁定与失败原子性、切档数量、同档重复操作、刷新阈值与冷却、变异属性、跨区追击、号角恢复。更新旧派遣测试，让后两区实际寻路和战斗；旧48英雄压力场景继续保留。

`tests/capture_regions.gd` 在750×1334、360×640、750×1624原生窗口检查城门点击、激活、材料点击/拖动、帮助、空白关闭和九种怪物表现，截图与操作日志位于 `validation/regions/`、`validation/regions_capture.log`。完整检查记录 `validation/regions_check.log`。

最终 `python tools/project.py check` 通过25项Python测试、9258项Godot断言、资源指纹与运行冒烟；日志无 `SCRIPT ERROR`、`ERROR`、`WARNING`。17张原生捕获及交互检查零失败，独立视觉终审为 `ship`。专项3851项断言还覆盖48英雄600秒循环，全部英雄均实际出手；修复城门重叠网格处追击后停留城镇的问题，并将战斗占用判断扩展到三个区域。三人1200秒循环与324条路线、115200个路径采样回归通过。
