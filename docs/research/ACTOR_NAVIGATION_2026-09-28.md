# 人物坐标、标识、寻路与碰撞校正

适用：艾比、特伦斯、芭芭拉、疾风狼、棕熊，以及小镇到第一野外的往返。来源总入口为 本机来源索引（未随包提供；[资源来源登记](../../THIRD_PARTY.md)），接口变更决策为 [ADR 0006](../adr/0006-source-actor-navigation.md)。源文件只读，提取数值和资源后由本项目实现；不依赖运行时访问拆包目录。

## 已落地的校正

| 项目 | 当前实现及源依据 |
| --- | --- |
| 动作比例和原点 | 删除按可见像素统一为 170 像素的缩放及待机 alpha 脚底锚点。英雄原骨骼乘 0.45；狼和熊乘 `c59_guaiwu_model.bl=0.57`。50 张动作表保留骨骼原点和完整动作边界，统一围绕原点镜像。`btHero.roleScale`、英雄 prefab、怪物模型表提供依据。 |
| 正背面和朝向 | 原资源默认朝左。水平转向保留此前正背面，垂直转向保留此前左右朝向，遵循 `btRole.lookAtVec2`；不在水平行走时强制切回正面。连续行走不重启周期。 |
| 名称与血条 | 英雄名称字号 18、中心 `(0,-114.096)`；怪物字号 20，挂点来自模型 `name_point`，仅其 Y 乘模型缩放。英雄血条底框左上 `(-27.439,4.647)`、怪物 `(-29,4.5)`，58×9 底框和 54×5 填充保持原尺寸。坐标均为 Godot 世界单位。 |
| 遮挡与阴影 | 整个角色按根节点 Y 排序；角色内血条/等级先于身体绘制，随后名称和原英雄阴影。前排角色及场景物可遮挡后排标识。阴影为原 `common_yinying` 65×13、缩放 0.6、透明度 150/255；怪物骨骼已有阴影，不重复添加。 |
| 死亡表现 | 按源 view 在 1 秒内渐隐；归零隐藏血条/等级。返城灵魂使用原灰度系数 0.2126 / 0.7152 / 0.0722，去掉自加半透明蓝色染色。 |
| 原地图格 | 小镇 38×19 菱形格、113×110 范围；第一野外 84×42、45×43 范围。保留 Map prefab 的排除格，小镇再叠加建筑及不可通行装饰占地，生成 4,400 个有效格。删除 20×20 重采样与手工增宽桥梁。 |
| 建筑入口 | 占地从配置格坐标开始，覆盖 width×height；不再将建筑坐标当占地中心。门口为配置坐标−(1,1)+prefab 门口偏移。18 个建筑与第一野外均可双向抵达；跨区经过 6 个源出口之一。 |
| 城镇移动 | 使用原格坐标做八邻居 A*，斜线两侧均可通行才放行，不切建筑角；途中换路先回当前格中心。不增加英雄间圆形硬碰撞；建筑、树石等配置障碍负责不可通行区域。等候点按实际来访预留不同位置。 |
| 野外移动 | 按格逐步接近；地图边缘选择合法邻格绕行。每完成一步检查射程，符合条件就转为攻击，不中途按 0.8 秒强制改道。战斗站位占格，路过的单位和尸体不占战斗站位。 |
| 普攻接敌 | 最终射程取 `skill_base.sk1_range`，特伦斯 100、艾比/芭芭拉 300；移除自加远程后撤。攻击/冷却期间保留站位，不用行走动作原地踏步。 |
| 移速与平滑 | 城内/野外像素倍率取 `c25_public` 1041/1042，均为 100；怪物属性 1.1 → 110。当前英雄初始化采用一星职业区间中值 1.4 → 140。相邻 0.05 秒领域位置仅在表现层插值，不写回规则位置。 |

## 可检索证据

下列相对地址均在 `F:/GameResearch/佣兵小镇` 内：

- `03_美术资源/04_预制体/resources/view/map/Map.json`：两区域原点、格尺寸、排除格、城镇出口。
- 同预制体目录 `build/Building*Prefab.json`、`role/hero.json`、`battle/role/btMonsterView.json`：门口、名字、血条、身体缩放/偏移和阴影。
- `04_配置表/JSON原表/resources/common/json/` 中 `c33_jianzhu`、`c33_jianzhu_zaw`、`c33_jianzhu_zs`、两张 seat 表：建筑及装饰占地，`up_build` 决定装饰是否挡路。
- `02_代码模块/BaseBuildingInfo.js`、`BaseDisassemblyInfo.js`、`BuildingEditorComponent.js`：占地与入口算法，未序列化门口的 Cocos 默认值 (0,0)。
- `AStarGrid.js`、`GridInfo.js`、`CptMapField.js`：城镇邻居规则、通行条件、出城重挂父节点保持世界位置。
- `btRoleMove.js`、`AIStateForward.js`、`AIStateAttack.js`、`btMapBase.js`：野外格步、射程检查、站位登记、目标周围可用格选择。
- `btRole.js`、`btCptHeroCharacter.js`、`Hero.js`、`btCptHeroView.js`、`btCptMonsterView.js`：方向保持、移动周期、死亡渐隐及灰色灵魂。
- `03_美术资源/06_粒子材质字体/resources/materials/gray-spine__EffectAsset.json`：灰度系数。
- `btRoleAttack.js`、`btActiveSkill.js`、`skill_base.json`：普攻覆盖职业默认射程。
- 本项目 `art_source/heroes/navigation_sources.json`、`ui_sources.json`、`bake_jobs.json`：提取结果与来源登记；导入器为 `tools/import_navigation_reference.py`。

重新生成沿用：`import_hero_reference.py`（其中调用导航导入）→`bake_hero_spine.cjs`→`register_hero_assets.py`→`project.py data`→Godot 导入→`project.py assets`。单独修改导航提取时可直接运行 `python tools/import_navigation_reference.py`，再重新生成数据；修改角色比例还须重烘焙。

## 验证与边界

### 2026-09-29 建筑穿模与野外密度修正

建筑阻挡格原本已正确覆盖，但表现层漏掉 `BuildingEditorComponent.setNodePosition` 的高度偏移：源 Y 加 `(height-1)*19/2`，对应 Godot Y 减同值。八格高建筑需上移 66.5 世界单位，装饰按各自高度调整；贴图内部原 prefab 偏移保持不变。现在原占地、建筑图像、门口及节点 Y 遮挡处于同一坐标系，建造前后均适用。

城内斜走新增防切角规则，途中切换目标先接回当前合法格中心，再进入新路线。这两项属于针对穿模的明确加严，不宣称与源 A* 的宽松斜向邻居策略完全一致，不扩大配置占地。详见 [ADR 0008](../adr/0008-town-footprints-and-field-population.md)。

- `test_town_world_rules.gd`：18 栋完整占地、324 条建筑间连续路线、医院角落及中途换路、48 人运行 120 秒（115,200 个位置采样）均不进入建筑内部。
- `capture_world_navigation.gd`：原生医院绕行、建造前后、750×1334 / 360×640 / 750×1624；背面 579 个图像重叠点中 533 个被建筑遮挡，正面 646 点中仅 10 点画面不变，确认人物前后排序。少量相同像素来自透明边缘与同色区域。
- 当前第一野外为源第一档 3 狼＋3 熊、7 个随机候选点、范围巡逻和 10 秒补充；取代旧人口扩容规则，详见 [怪物核查](MONSTER_SPAWNING_2026-09-29.md)。
- 证据集中在 `validation/world_navigation/`；下方旧计数均为历史验收记录。
- 完整 `project.py check` 通过：22 项 Python 测试、5,132 项 Godot 断言、管线、架构、导入、源指纹及启动冒烟均通过。三英雄 20 分钟经营循环持续产出；48 人压力场景 10 分钟全员产生实际攻击，末 150 秒仍有击杀产出。原生遮挡/绕行另有 5 项检查通过，无 `SCRIPT ERROR` 或 `ERROR`。

### 2026-09-29 建筑等候重叠修正

原 `TownNavigation.queue_point()` 忽略英雄编号，始终返回同一个门口，导致医院缺货时三人持续重叠。源调用链 `HeroLineUpAwaitBehavior.tick` → `Hero.gotoBuildSideAwait` → `BuildModel.getBuildSideRandomCanMovePos/getBuildSidePos` 实际从建筑周边格取等候位置；`BuildingEditorComponent.calcStaticExtendTile` 提供周边格，18 个对应建筑 prefab 的 `_buildExtendLength` 均核验为 1。

本项目从这一格宽的周边区域中筛出原地图可通行格，按距门口远近生成站位，再以原英雄 60×80 命中矩形作为停靠间距，为当前三人稳定分配互不重叠的位置。此间距只影响等候目标，不增加城内硬碰撞；原版随机选格，本 Demo 使用固定编号分配以避免重复抽到同一站位，不声称随机轨迹完全一致。服务仍遵循实际到达先后、容量、库存和支付条件；一人入场不会把其他人拉回门口。无效建筑或越界站位返回不可达结果，不循环复用已分配点。

- `tests/test_town_waiting.gd`：177 项断言通过，覆盖 18 栋建筑的三人站位、可达性、无效目标、医院持续缺货等候、按到达顺序入场、容量、三人全部治疗完成及再次来访。
- `tests/capture_building_waiting.gd`：运行真实医院路径后原生渲染 750×1334，截图为 `validation/building_waiting/01_three_waiting.png`、`02_first_hero_inside.png`，独立测试及渲染日志为同目录 `capture.log`。
- 最终 `python tools/project.py check` 全部通过：22 项 Python 测试、977 项 Godot 断言、架构检查、导入、发行输入指纹和启动冒烟，无 `SCRIPT ERROR` 或 `ERROR`；日志为 `validation/building_waiting/project_check.log`。

### 先前人物与导航验证

- `tests/test_town_navigation.gd`：全格坐标往返、医院完整占地、18 门口/野外双向路线、必须经过源出口、轴向朝向保持、短段移动、逐格接敌、活体站位释放和远程停步。
- `tests/test_town_heroes.gd`：20 分钟无人工赠送资源模拟，三人均参与击杀，后五分钟仍继续循环；阵亡/复活另有强制场景测试，不把自然模拟中未发生阵亡称为死亡验证。
- `tools/tests/test_actor_art.py`：1,828 帧透明边缘无裁切，原血条、等级和阴影图像 SHA-256 相同。
- `tests/capture_actor_layers.gd`：750×1334、360×640、750×1624 原生渲染，层级遮挡、死亡渐隐、灰色灵魂及插值不回写状态。179 个重叠采样点中 174 个确认由前排身体遮挡。
- `tests/capture_navigation_motion.gd`：实际行走 150 帧，所有逻辑位置可通行，30 fps 画面最大帧间位移 4.667 世界单位；`tests/capture_combat_motion.gd`：96 帧前后攻击、弹体和命中特效。
- 独立完整复核结论：**ship**，范围为本轮人物、标识与导航；11 张原生截图有效，未提出额外画面或行为修复。审查记录 `.impeccable/review/navigation/reviewer.md`。
- 当前完整门禁通过 22 项 Python 测试、681 项 Godot 断言与启动冒烟；20 分钟模拟完成 159 次击杀、55 次服务，三英雄分别击杀 50 / 52 / 57。
- 重复源导入验证：10 个骨骼烘焙任务及 CSV/schema 完全复现；63 张运行时角色贴图均有来源记录。
- 日志：`validation/navigation_tests_final.log`、`capture_actor_layers_native_nav.log`、`capture_navigation_motion_native_nav.log`、`capture_combat_motion_native_nav.log`；最终完整门禁另记 `validation/navigation_check_final.log`。

尚不能声称与原 APK 任意存档逐帧完全一致：原英雄实例移速由服务端区间生成，本 Demo 明确取中值；Godot A* 在等价路线的排序可能与原实现不同；领域保持 20 Hz、骨骼离线 30 Hz，原版实时骨骼及更新步长并未移植。表现插值最多延后一个逻辑步。生命/攻击/防御、需求衰减、部分索敌/刷新与回城条件仍属既有 Demo 规则；技能、升级及其他野外仍按清单待做。
