# 英雄点击、放大与持续跟随

当前范围：地图英雄点击选中、原圆形选中环、镜头放大和持续跟随、空白点击取消，以及「英雄详情」跳转。2026-09-30用户要求选中不暂停英雄，并接入对应详情页；此前仅还原按钮外观及城内暂停的约定已被替换。

## 源证据

先通过 本机来源索引（未随包提供；[资源来源登记](../../THIRD_PARTY.md)） 查阅本地 APK 和拆解档案。以下路径相对于拆解根目录，原档案保持只读。

| 项目 | 原代码或预制体 | 本轮实现 |
| --- | --- | --- |
| 英雄命中区 | `Hero` 预制体 `clickNode`：位置 (-4,39)、尺寸 60×80；`Hero.js:onUIEvents` 移动距离达到 15 即不算点击 | Godot 世界坐标矩形 (-34,-79,60,80)，15 逻辑像素拖动阈值，英雄优先命中 |
| 可选条件 | `Hero.js:onPopupNodeOpen/isCanOrientationHero`：非建筑内、存活、可见、非放逐 | 当前 Demo 的活体且非 serving/reviving/dead；服务端章节解锁与放逐尚未实现 |
| 镜头挂点 | `Hero.js:onPopupNodeOpen` 设置角色相机偏移 (0,45) | 转为 Godot (0,-45)，每次渲染跟随插值后的角色位置，不从动画图像边界估算 |
| 放大 | `CptMapDrag.js:onScaleMapCameraMax` 保存原倍率，增加 min(1.6−当前倍率,0.6) | 当前倍率 +0.6，上限 1.6；默认 0.65 → 1.25，已有 1.0 → 1.6 |
| 城内行为 | `Hero.js:onPopupNodeOpen/onPopupNodeClose`：suspendCurTree、stopMove、showBodyFront、waitAction；关闭后 continueCurTree | 按2026-09-30用户要求，选中不再暂停或修改英雄，继续原寻路、朝向、动画与业务；这是明确的源规则差异 |
| 野外行为 | `Hero.js:updateHeroFrameLocation/openHeroFrameLocation` | 持续移动/战斗，同时持续定位相机；不暂停模拟、不改寻路和碰撞 |
| 空白取消 | `NavigationMainPnlCtrl.js:onClickMaskNode` 发出 CLOSE_HERO_POPUP_NODE | 该次点击仅取消选中，不继续点击下方建筑；再次点击所选英雄也取消 |
| 倍率恢复 | `CptMapDrag.js:onScaleMapCameraMin/updateCameraScale` | 0.5 秒线性回到选中前倍率，保留当前跟踪位置，不回到原先地图位置 |
| 跟随边界 | `CptMapDrag.js:onMoveCameraToWorldPos` 的 isHero 分支直接赋值 | 跟随英雄时保持挂点，普通浏览恢复地图边界限制 |
| 原版选中环 | `resources/view/navigation/NavigationMainPnl` 的 bg_node：396×396，Cocos Y=-4.5 | 原始透明纹理，不重绘渐变；画布中心 +4.5，按源 720×1280 UI 尺度适配 |
| 开合动画 | `NavigationMainPnl_dakai/guanbi` | 圆环 0.2 秒：透明度 0↔255、缩放 0.5↔1、Cocos 角度 -290↔0；详情按钮从第 0.1 秒开始缩放/淡入，0.2 秒到位 |
| 详情按钮 | `NavigationMainPnl/detail_n`：107×114，Y=-191.335；标签 84×29、左右切片边距 15 | 原图、原位置、原字体与颜色；透明TextureButton接住点击并打开所选英雄已有的信息页。其他四个入口在源预制体中 inactive，不显示 |

原图导入工具：`tools/import_hero_focus_reference.py`。三张图片位于 `art_source/hero_focus/` 和 `assets/runtime/hero_focus/`，`sources.json` 记录 UUID、源路径与 SHA-256，PNG 保留原字节和透明画布。

## 状态与输入边界

`TownOperations.select_hero()` 是选择状态的唯一入口，只校验所选英雄并写入ID；旧 `inspection_paused` 字段及全部赋值、模拟跳过分支已删除。表现层只提交所选 ID 和读取快照。入建筑、死亡时由领域清除选择，恢复镜头及选中环。打开建筑页面先取消英雄选择，页面关闭后恢复地图输入。

详情按钮通过 `TownHeroFocus.detail_requested` 交由组合根读取最新所选ID和拥有名单，再进入现有 `MainHUD` 英雄信息页，默认属性分页；不创建另一套详情或改变英雄状态。全屏页面沿用既有覆盖层规则取消选择和隔离地图输入，模拟继续运行。返回恢复原地图或英雄抽屉上下文；关闭动画期间按钮禁用，无所选ID时请求不跳转。

镜头与圆环属于表现层，不能影响伤害、生产或英雄路线。切换英雄及缩小过程中重新选中保留同一初始倍率，避免重复点击累计放大。选中期间地图拖拽只判定手势，滚轮不改变倍率；拖动不会被当成空白单击，保持选中面板的输入遮罩作用。鼠标和触屏使用同一输入链，触屏沿用 Godot 的鼠标模拟。

## 验证入口

- `tests/test_town_focus.gd`：城内/野外选中与未选中的同种子模拟对照，无效/怪物/死亡/入建筑选择、真实鼠标和触屏、切换及重复点击、缩放上限、恢复时长、对应详情与返回、关闭后请求拒绝、建筑页面隔离。
- `tests/capture_hero_focus.gd`：原生 Godot 渲染和真实点击；三英雄城内持续行走与跟随、三名对应详情、野外持续行走/战斗与详情返回、英雄抽屉上下文返回；750×1334、360×640、750×1624、参考图游戏区域 825×1462。
- 输出：`.impeccable/review/hero_focus/`；连续帧在 `validation/hero_focus_motion/`，原生指标日志为 `validation/hero_focus_native.log`。

2026-09-29历史验收：原生连续198帧录制中，180帧跟随的挂点误差为0，镜头实际移动200.45世界像素，输入与画面检查无失败；四种尺寸和开合动画的独立视觉复核结论为ship，仅覆盖当时的选中与跟随功能。

本项接入既有本地英雄详情，详情页的原有范围仍见 [英雄信息页记录](HERO_INFORMATION_UI_2026-09-29.md)；不据此宣称新增全量养成、服务端章节解锁或跨进程保存。

## 2026-09-30增量验证

`validation/hero_focus_update_native.log` 原生渲染和点击退出0、`failures: []`。三名英雄各连续30帧城内选中行走，镜头累计移动380.80世界像素、跟随误差0；野外180帧跟随及18帧关闭录制误差0。三人按钮均打开对应姓名及属性页，详情打开期间模拟继续运行，返回恢复地图或已有英雄抽屉。750×1334、360×640、750×1624详情截图与四尺寸选中截图已检查，未改变已有详情页布局。

截图仍位于 `.impeccable/review/hero_focus/`，包括 `detail_hero_1/2/3.png`、`detail_360x640.png`、`detail_750x1624.png`、`field_detail.png` 和 `drawer_detail.png`；连续录制仍在 `validation/hero_focus_motion/frames/`。窗口与画布在 `canvas_items/expand` 下使用不同尺寸，返回位置验证以逻辑画布尺寸为准。

最终 `python tools/project.py check` 退出0：25项Python管线测试、9264项Godot断言、发布源指纹与运行冒烟通过，日志为 `validation/hero_focus_update_check.log`。旧待命英雄暂停断言已按当前需求改为继续巡游；鼠标和模拟触摸详情入口、关闭后请求及页面返回回归通过。两份最终日志无 `SCRIPT ERROR`、`ERROR` 或失败标记，终端中文编码已修正，源码无需编码修复。本次原生输入和截图使用桌面Godot，未新增导出包或真机验收。
