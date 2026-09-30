---
version: 1
slug: "scenes-town-main-recruitment-tscn"
primary_target: "scenes/town/main_recruitment.tscn"
related_targets: ["scenes/town/main_recruitment_overlay.tscn","src/features/town/presentation/main_recruitment.gd","src/features/town/presentation/main_recruitment_overlay.gd","tools/author_recruitment_scene.py"]
---

# 招募表面约定

范围为Godot 4.7.1中文竖屏本地Demo的招募流程，模式为Operate。视觉以用户九张截图及已登记源资产为准，延续地图和英雄现有风格；主地图不添加活动图标，截图的白色小游戏容器不进入游戏。

THESIS：玩家看清三名候选、当前条件概率和招募费用，完成一次真实本地结算，观看或跳过结果动画，再决定继续、刷新或换批。
OWN-WORLD：源船长、招募室、门台、青黑切角框、紫/橙动作区、原字体和Spine待机构成此表面。新版心愿、龙魂、勾选底框与免广告横幅使用三张用户原截图的AtlasTexture区域；横幅以原生多边形裁切旧背景，保留原PNG，分别记录出处。
STORY：地图上的船长对白 → 等级/卷轴/停船时间 → 三候选与概率 → 首抽卷轴或后续钻石 → 三门台动画 → 成功与实际碎片/新英雄 → 剩余候选或换批。说明、购买、心愿、刷新与换批确认均为独立覆盖层状态。
FIRST VIEWPORT：720×708抽屉底部锚定，608高主体加100高「英雄、龙魂技能」底栏；上方地图继续可操作，打开覆盖层才阻断下层。源舞台按视口宽缩放，覆盖750×1334、360×640、750×1624；人物、品质、进度和费用读取真实快照。
FORM：固定 `.tscn` 保存结构，旧 `MainPanels` 招募及通用概率弹窗路径移除。普通覆盖层680×530，购买高748，心愿高不超过1040并留出视口边距；九宫格保留源边框角部，76%黑遮罩。成功标题与手绘横幅独立保持可读，心愿卡与面板内框保留间距。

动画只呈现已提交的不可变回执，约5.2秒自然结束或空白点击跳过均只进入成功页，不再次扣费或抽取。原金/紫光柱各15帧，原成功Spine横幅采样16帧；本地动效时序未证明与源Cocos逐帧一致。源英雄待机与地图动作覆盖维持原有边界，招募到其余定义不等于已接入地图动作。

本地规则及源版本差异由 [招募界面记录](../../docs/research/RECRUITMENT_UI_2026-09-30.md) 与 [ADR0011](../../docs/adr/0011-source-recruitment.md) 持有。心愿须拥有锤锤解锁，其100基础权重乘2是Demo规则；龙魂只展示锁态，免广告推广只查看截图权益，不模拟激活、发奖或虚构价格。无服务器、广告SDK、现金支付或新增跨进程保存。

完成证据为 `.impeccable/review/recruitment/` 的九状态×三尺寸共27张原生捕获、`validation/recruit_native.log`、57条专项断言及通过的整项目检查 `validation/recruit_project_check.log`。最终独立审查 `ship` 仅覆盖动画落脚/光柱、推广边缘、心愿卡信息/间距和360宽成功标题的列出修正项，见 `validation/recruit_review.md`。来源扫描145张图、0缺失；不扩大为整款源游戏、移动真机或导出包验收。其余英雄、地图及生活建筑约定不变。
