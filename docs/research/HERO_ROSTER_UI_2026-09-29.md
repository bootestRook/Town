# 英雄半屏列表修正记录

日期：2026-09-29。范围为主界面「英雄」入口及其卡片、详情返回、地图定位、阵容和派遣操作。本次修正保留顶部资源栏、底部五入口和现有地图，不添加活动图标、微信容器、研发提示或额外导航。

## 源依据与真实数据边界

- 源列表依据 `HeroListShowPnl`：列出 `maphero`，按 `combat` 排序；本地对应为 `main.roster` 中 `live` 非空的条目，战力降序、同战力职业降序。当前只显示已进入地图的48位英雄。
- 英雄人数读取当前列表数量与 `main.map_capacity`；容量来自已有地图英雄槽位，当前为48。参考截图的7/7没有写入正式状态。阵容默认3/5是既有战斗队伍规则，与列表48/48各有含义。
- 卡片品质、职业、元素沿用源贴图；星级层级与数量取源 `c29_tf_star` 的 `pic`、`num`，经 `data/source/town/main_star_display.csv` 导入，不能把层级数字直接当星星个数。
- 74套卡片全身动画来自原Spine骨骼、各角色身体/头部/脸部配置及默认职业武器，现以30 Hz烘焙完整 `idl` 循环，替换此前 `idl@0.05s` 单帧。每个循环用全部帧联合边界统一构图；它是离线Spine图集播放，不是Live2D或运行时骨骼预览。74套资源覆盖招募身份，不代表地图已增加到74人。
- 原图UUID、源路径、逐图SHA-256和骨骼/部件/武器出处位于 `art_source/hero_roster/provenance.json`；每张PNG保留同名 `.png.json` 出处记录。原始拆解检索入口仍为 `SOURCE_REFERENCE.md`，导入不修改源目录。

## 页面与适配

固定入口为 `MainHUD/Stage/HeroRoster`。主界面源宽仍为720，缩放因子为视口宽/720；英雄列表为720×600，位于源舞台底部108高的导航栏之上，即纵坐标为舞台高度−708。项目逻辑画布仍为750×1334，不因列表单独修改工程分辨率。

列表头部保留「修改阵容」「地图派遣」、真实英雄人数与向上突出的关闭箭头；三列卡片为217×265，横向间隔15、纵向间隔12。列表独立滚动，最后一行的定位区能够滚动到固定导航上方。页面沿用原字体、青黑底板、品质框、职业/元素图标、星级纹理和战力底板。

英雄route直接显示独立列表，通用 `main_panels.gd` 不再承担旧全屏英雄分支。列表接住滚轮与点击，卡片主体及定位按钮使用 `mouse_filter = PASS` 将拖动继续交给父级滚动容器；露出的上方地图仍接收拖动；打开详情、阵容或派遣弹窗后才阻断地图输入。关闭抽屉恢复普通地图状态，不额外重置地图视野。

## 操作与领域行为

| 操作 | 当前真实行为 |
| --- | --- |
| 点击卡片主体 | 打开该地图英雄详情，将列表排序作为相邻英雄序列；首尾不循环。 |
| 关闭英雄详情 | 返回仍在原位的抽屉，保留列表顺序及滚动位置。 |
| 点击战力/定位区域 | 请求选择同一真实地图英雄，保留抽屉，不误开详情。现有死亡、服务、复活等选择限制仍生效。 |
| 定位时的镜头 | 将被列表及底栏遮挡的高度传给镜头与选中覆盖层；跟随点在原偏移基础上补偿，使英雄处于抽屉上方。 |
| 修改阵容 | 打开既有队伍管理，姓名/战力行打开全部已拥有英雄的详情（含尚未进入地图的新招募英雄），右侧出战/下阵按钮调整实际名单；保留原最多五人规则。 |
| 地图派遣 | 仅列出具有地图实体的出战英雄，提供城内/野外；当前野外对应已实现的第一野外，其他地图没有伪造选项。 |
| 派遣城内 | 写入城内派遣状态，保留队伍身份，清理原攻击/目标等战斗锁，再沿真实道路返城；不瞬移、不直接补血。 |
| 派遣野外 | 要求已在出战队伍，取消城内派遣状态，交由既有活动与需求规则继续处理。 |

地图常驻、战斗队伍、城内派遣是不同状态。将英雄派回城内不等于退出队伍；统一弹窗只是当前操作承载方式，不是原版阵容/派遣页面已逐节点还原的证据。

## 文件与管线

| 用途 | 文件 |
| --- | --- |
| 导入源UI与星级配置 | `tools/import_hero_roster_reference.py` |
| 原Spine完整待机烘焙与元数据 | `tools/bake_hero_roster.cjs`、`art_source/hero_roster/poses.json`、`art_source/hero_roster/idle.json` |
| 列表与详情共用待机播放 | `src/features/town/presentation/hero_idle_portrait.gd` |
| 固定场景编排 | `tools/author_hero_roster_scene.py` |
| 抽屉与卡片骨架 | `scenes/town/main_hero_roster.tscn`、`main_hero_card.tscn` |
| 列表排序、卡片绑定与信号 | `src/features/town/presentation/main_hero_roster.gd`、`main_hero_card.gd` |
| 路由、输入遮挡及详情序列 | `main_hud.gd`、`main_dialogs.gd`、`main_detail_content.gd` |
| 定位和选中区域补偿 | `src/app/app_bootstrap.gd`、`town_camera.gd`、`town_hero_focus.gd` |
| 真实派遣与返城规则 | `town_hero_management.gd`、`town_operations.gd`、`town_hero_simulation.gd`、`town_hero_standby.gd` |

表内未带目录的表现脚本位于 `src/features/town/presentation/`，领域脚本位于 `src/features/town/domain/`。静态定义和资产继续走现有生成管线，表现层只读取快照并提交意图。

## 本次验证与证据

`tests/capture_hero_drawer.gd` 通过Godot原生输入验证独立半屏路由、48/48真实人数、上方地图拖动、列表滚轮隔离、正确英雄定位、角色不被抽屉遮挡、详情首尾边界/序列/返回位置、阵容实际变更、城内与野外派遣状态、末行可达及关闭箭头。另通过真实招募指令建立未进入地图的英雄，验证其仍可从阵容名单进入详情、升级和返回；主抽屉人数仍保持真实地图名单。

模拟触摸验证通过 `InputEventScreenTouch` 与 `InputEventScreenDrag` 注入滑动，确认列表发生滚动且不打开卡片、不移动地图。此项不是实际手机或触屏设备测试，真实触屏设备仍未验证。

日志 `validation/hero_drawer_capture.log` 已记录：`[OK] Hero drawer native input, map focus, lineup, dispatch and three viewport sizes`。

| 捕获 | 尺寸 | 观察点 |
| --- | --- | --- |
| `validation/main_ui/hero_drawer_normal.png` | 750×1334 | 上方地图、半屏列表、48/48人数和三列全身卡。 |
| `validation/main_ui/hero_drawer_360_640.png` | 360×640 | 窄屏三列适配、固定五入口。 |
| `validation/main_ui/hero_drawer_750_1624.png` | 750×1624 | 长屏增加上方地图空间，抽屉与底栏仍贴底。 |
| `validation/main_ui/hero_drawer_locate.png` | 750×1334 | 对应真实英雄定位到抽屉上方。 |
| `validation/main_ui/hero_drawer_last.png` | 750×1334 | 滚动到末行及详情返回位置。 |
| `validation/main_ui/hero_drawer_dispatch.png` | 750×1334 | 派遣弹窗与实际状态。 |

本轮还完成两组关联原生回归：`validation/hero_drawer_main_regression.log` 记录 `[OK] Main UI native input and 24 captures`，`validation/hero_drawer_collections.log` 记录 `[OK] Collections UI native input and 12 captures`。前者覆盖主界面既有入口，后者覆盖英雄详情四分页与宠物/神器路径；不将两组捕获合并宣称为全量源子页视觉还原。

英雄抽屉前一阶段最终 `python tools/project.py check` 已通过：数据/资产与交付格式检查、Python管线测试、架构检查、Godot导入、5196条断言、源指纹和运行冒烟均通过，日志为 `validation/hero_drawer_project_check.log`，无 `SCRIPT ERROR` 或 `ERROR` 标记。抽屉原生输入与模拟触摸、新招募英雄养成入口验证也已通过。没有发布或验收Web/EXE包，也没有移动真机结论。

## 完整待机增量（2026-09-29）

列表与独立英雄信息页共享 `hero_idle_portrait.gd`。可见卡片才加载待机图集，滚动容器外的卡片跳过处理；同一外观的重复快照保留播放相位，不每次重启。图集帧为256×256，所有帧沿联合边界采用相同缩放与位置，保留完整身体和武器；每组按源动作时长循环，表现时钟不改变玩法状态或随机序列。

`validation/hero_inventory_native.log` 已通过列表待机连续变化、详情多帧与三尺寸原生输入验收；`validation/hero_idle_atlas_verification.json` 核验74组都有不同帧且alpha边界未裁切，`validation/hero_idle_runtime.gif` 为原生详情局部动画预览。背包和装备增量见 [英雄背包与装备记录](HERO_INVENTORY_UI_2026-09-29.md)。当前背包装备增量整项目检查已通过5636条Godot断言、运行冒烟和发布清单检查，后续提示文案与发布指纹收尾见增量记录；前述5196条断言只代表抽屉前一阶段。

## 尚未覆盖

- 列表和详情已播放完整源待机循环，仍使用默认职业武器；逐件装备动态外观尚未接入。
- 列表阶位徽章当前显示固定Ⅰ，不据此宣称完整阶位变化已接入。
- 修改阵容与地图派遣仍使用既有统一弹窗；英雄详情现为独立全屏固定场景，不能据此宣称原子页面完整prefab逐节点复刻。
- 只有城内及第一野外派遣；其他区域、服务端行为与整款原游戏完整1:1仍未完成。
- 本记录只修正英雄列表页面及关联操作，不替代英雄地图动作、所有专属技能、其他主界面子系统或性能的独立验收。
