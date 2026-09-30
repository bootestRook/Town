# 英雄背包、装备详情与完整待机记录

日期：2026-09-29。范围为用户新增参考中的英雄背包六列格子、已穿装备二级界面，以及英雄列表和详情的原待机恢复。沿用独立英雄信息页和半屏列表，不修改源初始化，不固定参考角色、等级、背包数量或词条结果。前置页面记录见 [英雄信息页](HERO_INFORMATION_UI_2026-09-29.md) 与 [英雄列表](HERO_ROSTER_UI_2026-09-29.md)，领域决策见 [ADR 0009](../adr/0009-hero-equipment-instance-affixes.md)。

## 来源与视觉边界

`tools/import_hero_inventory_reference.py` 导入原空背包格、装备面板、分隔线、回购、分享、下划线和星级共7项纹理。来源、UUID与SHA-256保存于 `art_source/hero_inventory/provenance.json`，每张PNG有同名出处sidecar。品质底框、物品图、阶位徽章和正文继续复用已有原资源及 `operations/font.ttf`。

装备静态规则来自 `c39_zhuangbei`、`c39_citiao`、`z_1_1_zhuangbei_xidian` 的回购价与 `c25_public` 的1410品质门槛，写入现有CSV/schema管线的 `data/source/town/main_equipment_rules.csv`。数据只覆盖当前七件制作装备，不补造截图中的高阶装备。

两项既有差异与一项新增重建必须明确：

- 装备设置仍用原包同色圆盾 `pvp_anniu_fangshou` 替代参考新版铠甲圆图；尚非该处像素1:1。
- 更换英雄胶囊仍按参考几何绘制，不能标成原切图。
- 洗练青色菱形与两翼由固定场景中的 `Polygon2D` 分层按新参考重建。当前APK按钮不同，故本图形是参考重建，不是原APK切图，也未由生成式图像工具制作。

## 六列私有背包

`main_hero_bag.tscn` 保存固定滚动面板，`main_hero_bag_cell.tscn` 保存格子。背包与详情共用720源宽缩放，固定六列，单格110×107、横间距8、纵间距3；内容停在底部四分页之上。最少填满可见行及完整末行，常规视口为空时呈现24格；物品更多时向下滚动，不挤压底栏。

每次只读取当前英雄快照中的私有 `bag`，筛选正数量并按定义排序，显示真实图标、品质框、阶位与数量。空格不可点；有物品时打开数量和说明，不能从该说明使用或消耗公共库存。更换英雄重置滚动并呈现另一名英雄的物品，同一英雄的快照刷新保留滚动。公共材料库存与公共装备仓库仍是独立状态，不借背包页合并。

## 装备二级页与真实转移

`main_equipment_detail.tscn` 保存遮罩、源面板、标题/分享、装备图、星级、主属性、词条区域、回购确认及洗练按钮。页面绑定当前英雄、部位和装备实例序号；装备已变更时关闭失效详情。点击面板内部保持打开，点外部空白关闭并回到原详情分页；不会把装备弹窗关闭误当英雄页返回。

词条呈现实例的实际数值及源允许范围，紫色值与白色范围分开；主属性仍由装备定义驱动。测试截图中的守望上衣和百分比只是当次真实实例，不是正式初始化固定值。

| 操作 | 当前行为与边界 |
| --- | --- |
| 空槽/装备设置 | 从公共装备仓库选择符合职业的实例，继续使用 `hero_equip`；职业0按整数边界识别通用装备。 |
| 已穿普通装备 | 打开该实例详情；神器槽继续原神器管理路径。 |
| 回购装备 | 二次确认后提交 `hero_equipment_buyback`，校验英雄、部位、实例序号、独立战斗状态、仓库150件上限和公共钻石，再原子完成扣款与转移。当前五件一阶装备源价6钻石、两件二阶饰品源价5钻石，均读取配置。 |
| 取消/余额不足/陈旧实例 | 不扣钻石，不转移装备；重复请求不会重复扣款。旧 `hero_unequip` 免费卸下命令及对应入口已删除。 |
| 洗练 | 当前七件均为quality 2，低于源门槛5；只提示「仅限金色、红色品质的装备可以洗练」，不扣费、不生成新词条。原文来自 `c9_lang_chinese_simp` 的40014003。 |
| 分享 | 将当前装备名称、主属性和词条文本复制到本机剪贴板并反馈；不向聊天、好友或其他外部应用发送。 |

回购与装备选择继续属于 `TownHeroManagement`，表现只提交意图。原有穿戴替换仍使用既有穿戴规则；付费回购记录描述单独取回已穿装备的入口，不把本地全部装备流转扩大为源服务端经济规则。高阶洗练的随机预览、确认保存及其消耗未新增；当前可取得七件均不可洗练，不用虚构高阶装备掩盖这个边界。

## 初始词条与本地规则

`TownWorkshop` 打造时通过 `TownEquipmentRules` 为每件实例保存源词条ID、效果和实际数值。注入的命名流 `town.equipment` 与掉落、招募、远征分开，在源最小值和最大值组成的闭区间均匀抽样。源配置支持该范围，但未知服务器抽样分布没有证据，均匀分布明确是本地Demo规则。

当前词条映射为攻击加成、移动速度、饥饿消耗折算与已有远征战斗的闪避。饥饿词条同时折算普攻扣除和野外持续消耗，以适配现有0–100需求模型，不宣称已改成原服务器绝对饥饿容量。闪避接入既有远征 `combat.dodge`，不能宣称原先无命中/闪避判定的地图简化战斗也支持该词条。动画、词条文案和弹窗结束时点均不决定领域结果。

## 列表与详情的完整源待机

`tools/bake_hero_roster.cjs` 沿用既有离线Spine依赖，依据原骨骼、逐英雄身体/头/脸、隐藏部件及默认职业武器，按30 Hz烘焙完整 `idl` 循环。`art_source/hero_roster/idle.json` 当前登记74套图集的帧数、列数和原动作时长；当前地图仍为48名英雄，资源覆盖范围不等于地图人数。

烘焙先取循环所有帧的联合边界，再对全部帧使用同一裁切、缩放和位置；256×256格内保持完整身体/武器及统一脚底，不能逐帧重新缩放造成抖动。列表与详情共用 `hero_idle_portrait.gd`：仅可见格延迟加载图集，屏外格跳过处理；同一外观的重复快照不重启周期，切换外观才从新动作开始。播放器读取源时长并循环，不使用玩法随机流。

这是原Spine完整待机的离线图集播放，不是Live2D，也未引入运行时Spine依赖。完整待机恢复不等于逐件装备外观、所有动作或所有地图英雄已新增；默认职业武器边界继续保留。

## 文件与验证

| 用途 | 入口 |
| --- | --- |
| 纹理和装备规则导入 | `tools/import_hero_inventory_reference.py` |
| 固定背包/装备场景编排 | `tools/author_hero_inventory_scenes.py` |
| 固定结构 | `scenes/town/main_hero_bag.tscn`、`main_hero_bag_cell.tscn`、`main_equipment_detail.tscn` |
| 快照绑定及输入 | `src/features/town/presentation/main_hero_bag.gd`、`main_hero_bag_cell.gd`、`main_equipment_detail.gd` |
| 词条与回购 | `src/features/town/domain/town_equipment_rules.gd`、`town_workshop.gd`、`town_hero_management.gd` |
| 原待机 | `tools/bake_hero_roster.cjs`、`src/features/town/presentation/hero_idle_portrait.gd` |
| 原生验收 | `tests/capture_hero_inventory.gd`、`tests/capture_hero_information.gd` |

已核查的本轮证据：

- `validation/hero_inventory_domain.log`：123条装备专项断言通过，覆盖确定性词条与范围、私有库存隔离、回购原子性/重复请求、低品质拒绝及属性实际变化。
- `validation/hero_inventory_native.log`：750×1334、360×640、750×1624原生输入通过；覆盖六列格、空格/满行滚动、换英雄隔离和滚动复位、物品只读说明、装备内外点击、低品质洗练不改状态、回购取消/余额不足/成功，以及列表和详情连续待机。
- `validation/hero_information_regression.log`：四个锚定状态浮层、三尺寸、钱包、技能及升星回归通过。
- `validation/hero_idle_atlas_verification.json`：74组均有不同帧，完整图集alpha边界检查无裁切；`validation/hero_idle_runtime.gif` 为原生详情动画局部预览。
- `validation/hero_inventory_project_check.log`：整项目检查通过5636条Godot断言、运行冒烟和发布清单检查。该日志之后仅将低品质洗练提示换成上述源原文；文档完成后的最终发布指纹同步与收尾核验由主任务记录，不将先前日志冒称为后续文件的检查。

截图在 `validation/main_ui/`：`hero_inventory_bag_<宽>_<高>.png`、`hero_inventory_equipment_<宽>_<高>.png`，另有空背包、满行滚动、回购确认、列表运动和 `hero_idle_00` 至 `hero_idle_07` 连续帧。测试注入的私有材料数量和用于穿戴的装备只用于可辨验收，不写入正常英雄初始化。原生脚本覆盖桌面Godot事件；真实触屏设备与导出包未在本次验收。分享实现已核查，不把上述未点击分享的原生脚本记录写成剪贴板端到端验收。

## 未完成边界

当前完成的是背包、装备二级页及源待机的本地路径；高阶洗练预览/保存、服务端随机分布、聊天分享、逐件动态换装、全量原页面与机制仍未完成。装备设置圆盾和洗练几何重建保留明确来源差异；宠物和神器分页继续原功能列表，不因本轮收到背包参考就宣称其视觉1:1。

## 最终收尾核验

文档同步及源洗练提示更新后，重新执行 `python tools/project.py check`，最终日志为 `validation/hero_inventory_final_check.log`：5636条Godot断言、600秒城镇模拟、数据/资源/架构/发布清单与运行冒烟均通过，无 `SCRIPT ERROR`、`ERROR` 或 `FAIL` 标记。发布清单4448文件、778410350字节；本次没有导出安装包。随后只补记此核验结果及关闭文档审查项，并重新构建、核对发布清单。
