---
version: 1
slug: "map-dispatch"
primary_target: "scenes/town/main_map_dispatch.tscn"
related_targets: ["scenes/town/main_dispatch_card.tscn","src/features/town/presentation/main_map_dispatch.gd","src/features/town/presentation/main_dispatch_card.gd","src/features/town/domain/town_map_dispatch.gd","src/features/town/domain/town_region_routes.gd"]
---

# 地图派遣

2026-09-30，已实现表面记录。Godot 4.7.1中文竖屏，默认750×1334，使用现有720逻辑宽舞台，模式为Operate。用户三张截图为构图和交互依据，源 `FightSetPnlCtrl.js`、`c8_map` 与可追溯切图为规则和材料依据；沿用《佣兵小镇》手绘奇幻视觉，不包含微信宿主标题栏或活动图标。

THESIS：玩家按目标区域查看已出战英雄，选择同区成员或使用全部派遣，处理战力与解锁限制，关闭界面后沿真实路线前往指定区域。
OWN-WORLD：源橙色切角边框、青黑面板、橙色标题、紫色批量按钮、暗地图底图、原字体和品质卡片保持既有比例与材料；13张派遣切图的来源、目标路径及SHA-256见 `art_source/dispatch/provenance.json`。
STORY：英雄抽屉进入 → 四区按派遣目标分组 → 同区多选/全部派遣 → 领域预检 → 必要时低战力确认 → 草稿重排 → 关闭提交 → 返回原抽屉位置，英雄按真实路线移动。
FIRST VIEWPORT：地图与英雄抽屉压暗，面板占据主要高度；顶部四按钮顺序为主城、兽人密林、亡灵墓地、魔族战场。区域上排主城/魔族战场、下排兽人密林/亡灵墓地，各区三列小卡，保留区域标题、推荐战力与底图。底部保留「点击英雄后可选择要派遣的地区」和面板外「点击空白处关闭界面」。
FORM：固定主面板、四区、帮助和确认层保存在 `main_map_dispatch.tscn`，动态英雄使用 `main_dispatch_card.tscn`。小卡83×108逻辑像素，区域长列表独立滚动；主面板高度不足时整体缩小，750×1334、360×640、750×1624均保留四区与关闭提示。

## 选择、确认与关闭

同一区域可多选并逐个取消，使用源绿色选中框；其他区域卡片压暗且不能加入本次选择，有效目标区显示橙色派遣按钮。卡片显示实际品质、肖像、职业、元素、等级、星级和战力，按战力排序；低于派遣目标推荐战力时显示原警告图。卡片拖动交给区域滚动容器，不误选或带动背景地图。

顶部按钮对其他区域英雄执行全部派遣。预检后达标英雄立即更新草稿，低战力名单单独确认；取消只保留这些低战力英雄原目标，确认后加入目标草稿。分组依据 `assigned_area` 的草稿值，不依据英雄此刻身处哪个区域，返城服务不会改变派遣分组。

确认层660×480，帮助层660×720，正文左右内缩90并使用480宽滚动区；标题29、正文23逻辑像素。长名单自动换行且可滚动，确认和取消留在下方。弹层外点击只收起当前弹层；派遣主界面外点击提交草稿，领域接受后关闭并恢复原英雄抽屉位置，拒绝时保留页面并显示原因。表现层不直接改写领域状态。

## 规则与真实运行边界

| 区域 | 推荐战力 | 地下城进度门槛 | 当前实际行为 |
| --- | ---: | ---: | --- |
| 主城 | 无 | 0 | 保留出战身份，真实返城及既有城内活动 |
| 兽人密林 | 0 | 0 | 世界难度1三档密度、移动、普攻战斗与战利品 |
| 亡灵墓地 | 1000 | 9 | 世界难度1三档密度、普攻战斗与战利品、需求/召唤/撤下返城 |
| 魔族战场 | 2000 | 18 | 世界难度1三档密度、普攻战斗与战利品、需求/召唤/撤下返城 |

推荐战力是可确认继续的软提示，地下城解锁是硬限制。源解锁来自服务器，本地Demo按既有地下城进度达到门槛即解锁；不增加解锁入口或难度系统。只接受地图已出战英雄，保留进行中独立挑战和号角参战保护。地图上阵名单、营地容量与独立五人远征名单均由各自现有规则持有，派遣不改变它们。

三个野外通过源出口与主城连接，跨野外经主城行走，不瞬移、不回血。当前世界难度1的三个地区各有三档密度，后两区已接入各自原怪物、普攻战斗和既有战利品收益。怪物专属技能、首领/变异额外宝箱和其他世界难度仍未实现，源帮助原文不能作为这些扩展已完成的证明；区域源配置、刷新规则与17张三尺寸原生证据见 [区域等级与怪物](../../docs/research/REGION_LEVELS_2026-09-30.md)，本次区域终审与派遣历史整项目检查分别记录。初始艾比、特伦斯、芭芭拉三名绿色英雄不变；7人、15人、提高战力与全部解锁只属于验证夹具。领域预检、原子提交及路线决策见 [ADR 0014](../../docs/adr/0014-four-region-dispatch.md)。

## 验证证据

`tests/test_town_dispatch.gd` 的75条领域专项断言已通过，覆盖门槛、保护、原子提交、后两区往返及服务往返；日志 `validation/dispatch_focused.log`。`tests/capture_dispatch.gd` 和 `validation/capture_dispatch.log` 通过实际点击、同区多选、批量派遣、确认/取消、长文案、触摸滚动、外部关闭和三尺寸原生输入。弹窗正文内边距修正后重新捕获了以下八张状态：

- `validation/main_ui/dispatch_default.png`：真实三人新档与锁区。
- `validation/main_ui/dispatch_seven.png`：七人验证阵容。
- `validation/main_ui/dispatch_selected.png`：选中框、其他区限制与目标按钮。
- `validation/main_ui/dispatch_low_power.png`：低战力确认。
- `validation/main_ui/dispatch_many_low_power.png`：15人长名单确认。
- `validation/main_ui/dispatch_help.png`：源帮助与正文留白。
- `validation/main_ui/dispatch_360_640.png`、`dispatch_750_1624.png`：窄屏与长屏适配。

完整来源与验收记录见 [地图派遣记录](../../docs/research/MAP_DISPATCH_2026-09-30.md)。以上为原生窗口和Godot模拟触摸证据，不代表移动真机、导出包或整款源游戏1:1验收。最终 `python tools/project.py check` 已通过24项Python测试、8528条Godot断言、发布指纹及运行冒烟，日志 `validation/dispatch_check_final.log`。旧两区统一弹窗和二值派遣路径已经删除；本记录不为它们保留兼容约定。
