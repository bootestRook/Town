---
version: 1
slug: "scenes-town-main-hero-detail-tscn"
primary_target: "scenes/town/main_hero_detail.tscn"
related_targets: ["src/features/town/presentation/main_hero_detail.gd","tools/author_hero_detail_scene.py","scenes/town/main_hero_bag.tscn","scenes/town/main_equipment_detail.tscn","src/features/town/presentation/hero_idle_portrait.gd","tools/author_hero_inventory_scenes.py"]
---

# 英雄信息页表面约定

范围是玩家从英雄抽屉或阵容进入的一名英雄详情。任务是看清当前属性和需求，检查装备、技能、星级及私有物品，完成真实钱包、升星与装备回购操作，再返回原上下文。

THESIS：以用户英雄信息页与背包/装备新参考承载实际英雄状态，独立全屏页替换旧通用hero弹窗，背包为六列私有格子，已穿装备进入独立二级页。
OWN-WORLD：沿用源品质场景、原Spine完整待机、技能图、战力位图数字和手绘青黑材质。装备设置圆盾是明确替代；更换英雄胶囊及洗练青色菱形按参考几何重建，不能标成原切图。
STORY：公共/私有资源 → 品质场景与六槽 → 战力和四需求 → 三属性/四技能/星级；底部属性、宠物、神器、背包。装备详情显示实际实例和源词条范围，回购先确认后校验与原子扣费转移；分享只复制本机剪贴板。
FIRST VIEWPORT：第一眼识别当前英雄、原待机与真实装备/战力；四状态就地展开浮层，私有背包与公共库存分开。参考角色、100级、百分比或背包数量不写入初始化；储备英雄未记录需求显示「—」。
FORM：原生Godot固定场景，720源宽随视口缩放，底栏固定。背包六列滚动并随英雄隔离；74套原Spine完整idl以30 Hz离线烘焙、全帧联合边界统一构图，可见格延迟加载。不是Live2D，默认武器不代表动态换装。宠物和神器仍为已有功能列表，不宣称未提供画面的1:1。

证据集中在 docs/research/HERO_INFORMATION_UI_2026-09-29.md 与 HERO_INVENTORY_UI_2026-09-29.md。当前两份原生三尺寸/信息页回归、123条装备专项断言、74组图集边界及5636条整项目断言均通过；整项目日志后的源洗练提示与最终发布指纹收尾按增量记录区分。当前七件quality 2低于源洗练门槛5，只提示且不扣费，高阶预览/保存未新增；初始词条闭区间均匀抽样是本地规则。真实触屏、导出包、完整原子系统1:1未验收。保留地图、生活建筑与其他页面既有承诺。

技能说明使用 main_skill_tooltip.tscn 共享非模态浮层，覆盖详情、培养和图鉴入口，旧 skill 二级弹窗已删除。原位显示名称、CD/类型、全部等级系数及当前等级绿色高亮；0级保留源技能锁 yx_suoding、压暗图标且可查看源天赋解锁星级。同项/空白/Escape收起，英雄切换、分页、滚动清除；培养保留触摸滚动，角色待机继续。三尺寸原生输入与旧详情/管理回归通过，长说明截图为合成压力样本；详情见 docs/research/HERO_SKILL_TOOLTIPS_2026-09-29.md。
