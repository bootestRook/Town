# 英雄技能说明浮层与锁定状态

## 本轮范围

根据本轮两张参考图，技能说明改为当前页面内的非模态浮层；未解锁技能使用原锁图标并保留查看说明的能力。详情页、培养行、图鉴预览及既有技能列表共用 `main_skill_tooltip.tscn`，删除 `MainDetailContent` 的旧 `skill` 二级弹窗分支。此变更不调整技能战斗规则或英雄初始化。

## 源证据

- `CptSkilInfolTipsMgr.js`：同锚点再次点击收起；不同技能切换；点击浮层和原图标以外的位置关闭。
- `CptSkillInfoTips.js`、`view/common/SkillInfoTips.json`：660宽、内容决定高度，技能图在左，黄色名称及右侧CD/类型在上，正文保留全部等级值；当前技能等级绿、其他灰。未解锁时沿天赋 `next_id` 查首次解锁星级。
- `CptSkillItem.js`：0级显示锁、压暗图标及角标，但点击权限由独立标志决定，锁定不意味着禁止查看。
- `Enums.js`：绿 `#34CD3F`、灰 `#989896`、正文 `#F3F3D3`；语言表13012–13015对应 `CD:%sS`、`buff`、`（%s星解锁）`、`被动`。
- 背景沿用 `hero_detail.tip_body`，UUID `ee130e8f-3033-47c5-a284-a9f6e1ced5a6`；新增专用 `hero_detail.skill_lock`，源 `yx_suoding`，UUID `4e2ceabc-d437-4e60-ba85-bb9f08ebb870`。通过 `tools/import_hero_detail_reference.py` 导入、登记，源拆包目录只读。

## 实现约定

固定结构保存在 `.tscn`，正文由表现层 `MainHeroSkillText` 格式化。`%s` 使用当前英雄名字，`<br/>` 转换成换行，各数值组逐级着色；等级0不高亮任何值，显示源天赋解锁条件。CD为源配置基础冷却，不是倒计时。解锁查询保留当前JSON目录使用的数值键类型，不引入存档或数据格式迁移。

浮层位于点击技能上方、随文字向上增高，顶边不足时放到下方并限制在可视区域；不增加全屏遮罩、返回或确认按钮。浮层内部点击保持，外部点击不吞掉原操作；Escape只收起浮层。翻页、切换英雄、退出及锚点移动/隐藏时清除，状态提示与技能提示互斥。培养技能按钮维持 `MOUSE_FILTER_PASS`，触摸拖动继续交给父滚动容器。

未解锁技能在详情和培养行均保留等级0、原锁图、较暗底图与角标；仍使用正常按钮。浮层中的图标仅展示，不递归打开说明。

## 验证

- `tests/test_hero_skill_text.gd`：多组等级值着色、0级、名字转义、所有源技能文本及未解锁天赋链。
- `tests/capture_hero_skills.gd`：原生鼠标/键盘/模拟触摸，750×1334、360×640、750×1624；正常技能、锁定技能、最长源说明；同项开关、外部关闭、Escape、英雄/页签切换、培养滚动、图鉴不增加导航层、待机动画持续。
- 原生技能测试通过，日志 `validation/hero_skill_native.log`；截图 `validation/main_ui/hero_skill_*.png`。测试招募索非亚（源appearance12007）并设置星级/等级，正常初始化不变；源名字与新版截图略有差异。`hero_skill_long_*` 是在洛根页面直接注入最长源技能/测试英雄名的合成布局压力样本，不表示正式英雄技能归属。
- 旧英雄详情、管理页原生回归通过，对应日志 `validation/hero_skill_information_regression.log`、`validation/hero_skill_management_regression.log`。最终整项目检查写入 `validation/hero_skill_project_check.log`；未导出或发布安装包。

本轮只改变技能描述的查看方式与锁态表现，不将现有Demo其余未完成子系统宣称为完整源版1:1。
## 最终检查结果

`python tools/project.py check` 退出0：6573条Godot断言、Python管线测试、架构/数据/资产校验、发布清单检查与运行冒烟通过。资源1639项，运行时资源总计761,379,626字节；发布输入4518文件、779,058,464字节。完整日志为 `validation/hero_skill_project_check.log`，没有SCRIPT ERROR或ERROR；编辑器导入退出阶段出现一次 `Scan thread aborted` 警告，后续测试及运行冒烟成功。独立原生技能、英雄详情和管理页三份最终回归日志无错误/警告。
