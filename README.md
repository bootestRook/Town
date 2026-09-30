# 佣兵小镇 · Godot 原型

基于 Godot 4.7.1 研发底座的竖屏小镇经营原型。默认 750×1334；拖动地图、滚轮缩放。点击医院、餐馆、旅馆、酒馆、交易所、武器店、防具店、饰品店或复活祭坛进入二级页面。地图不添加说明栏或演示导航按钮。

生活店拖材料到中间操作台生产，英雄会排队付费使用；交易所设置材料预购、召唤英雄回城出售；装备店选择配方打造，再召唤英雄到店确认出售。点英雄头顶装备图标也可开始交易。各页面的返回箭头回到地图，库存与英雄活动持续运行。启动时提供有限测试资金与材料，暂不跨进程保存。

新游戏只拥有三名绿色初始佣兵：艾比（法师）、特伦斯（战士）、芭芭拉（弓手），默认全部出战。其余佣兵需通过现有招募获得；74名招募英雄均已具备地图正背面动作资源，资源数量不代表拥有数量。招募新英雄后立即入城巡游待命，仅显示蓝色名字；上阵后显示绿色名字、血条和等级。撤下或新入城时立即寻路，到达后保留源规则的随机短暂停留。地图上阵与五人独立挑战分别管理；英雄营地初始5级、容量7人，初始两份名单均为原三人；点击地图营地可只花金币升级，5→6级花费15万金币并将实际出战容量增至8人，最高13级容纳15人。见 [英雄营地](docs/research/HERO_CAMP_2026-09-30.md)。见 [初始名单与招募入城](docs/research/HERO_ACQUISITION_2026-09-30.md)、[英雄管理页面](docs/research/HERO_MANAGEMENT_UI_2026-09-29.md)。三个野外城门可打开区域等级面板，按地下城进度激活各自的三档密度；普通怪每种3/4/5只，首领和变异按源刷新次数与冷却替换生成。初始森林仍为3狼＋3熊，区域数量不随英雄人数扩容。见 [区域等级与怪物](docs/research/REGION_LEVELS_2026-09-30.md)。全部专属技能与装备动态外观仍待接入。

点击地图上的英雄可放大并显示原版选中环；城内和野外都继续正常行动，镜头持续跟随。点击空白或再次点击本人取消并恢复原倍率；「英雄详情」打开所选英雄的信息页，返回后恢复地图操作。源码依据和验证见 [英雄选中与跟随](docs/research/HERO_FOCUS_2026-09-29.md)。

普攻按源配置播放动作变体、出手、飞行与命中特效，原骨骼按 30 Hz 离线采样；不再使用临时攻击线条或起手瞬间扣血。对应证据、时序与边界见 [动作特效校正](docs/research/COMBAT_PRESENTATION_2026-09-28.md)。人物使用原骨骼坐标和缩放，小镇/野外按源菱形格、建筑门口与战斗站位通行，详见 [人物与导航校正](docs/research/ACTOR_NAVIGATION_2026-09-28.md)。

地图使用用户提供的《佣兵小镇》拆包美术与摆放数据；来源登记在 `art_source/town/provenance.json`。运行不需要原 APK 或拆包目录。通用框架仍保留独立测试样例，玩法实现放在 `src/features/town/`。

野外战利品现区分英雄私有收益和玩家地面收益：参战英雄分配材料、金币与经验；玩家点击落定物品进入公共库存，可直接用于现有生产。普通地面物品60秒消失、BOSS材料300秒；重复点击不重复发奖。经验按源表自动升级，状态仍只保留本次进程。来源、表现差异及验证见 [掉落与拾取](docs/research/FIELD_LOOT_2026-09-30.md)。

查询源 APK、拆解地址、美术/配置/代码索引，本机入口为 `docs/research/SOURCE_REFERENCE.md`（不随 Git/ZIP 交付）。可移植资源来源与许可证见 [THIRD_PARTY.md](THIRD_PARTY.md)。

主界面已接入源顶部资料/资源栏和「玩法、地下城、英雄、招募、商城」五项底栏，不加入活动图标。英雄四分页、宠物/神器基础养成、招募、独立挑战、遗迹打捞与钻石模拟充值均使用本地状态运行。商城当前只开放独立钻石页，旧七分类界面已移除，既有礼包领域规则保留但没有页面入口。全部源二级页布局和完整子系统仍有未完成项，历史实现、测试与差异见 [主界面开发记录](docs/research/MAIN_UI_2026-09-29.md)。

招募现使用独立抽屉，已接入卷轴购买、刷新、心愿锁态/选择、可跳过动画、成功结算及换批确认；三尺寸原生输入和整项目检查通过。龙魂仅展示锁态，免广告推广只查看权益；来源与本地规则边界见 [招募界面记录](docs/research/RECRUITMENT_UI_2026-09-30.md)。

钻石快捷购买页按源商人横幅和三列两行六档卡片呈现，每档首充额外赠送同等钻石，复购仅基础数量。客户端先一次结算，再播放源奖励入场、循环横幅、爆光与音效；返回恢复英雄或招募上下文。只在本次进程保存，无服务器、支付 SDK 或真实扣款，不开放每日特惠、英雄礼包、道具礼包页签。来源、动效和验证见 [钻石充值页记录](docs/research/DIAMOND_SHOP_UI_2026-09-30.md)。

当前范围与后续事项见 [开发清单](docs/TOWN_PROTOTYPE_LIST.md)，各建筑原包证据、操作链与未还原项见 [建筑交互核查](docs/research/BUILDING_INTERACTIONS_2026-09-28.md)。

英雄抽屉的「地图派遣」现为源四区面板，支持同区多选、顶部全部派遣、推荐战力确认与关闭保存。地下城通关9/18关分别开放亡灵墓地/魔族战场，英雄沿源网格和城门实际往返；三个野外均已接入怪物、普攻、战利品和返城服务。见 [地图派遣记录](docs/research/MAP_DISPATCH_2026-09-30.md) 与 [区域等级增量](docs/research/REGION_LEVELS_2026-09-30.md)。

## 4 条日常路径

要求 Python 3.10+、Godot 4.7.1。不需要第三方 Godot 插件。

```powershell
# 1. 首次检查环境和生成物
python tools/project.py doctor

# 2. 修改策划表或资源后生成
python tools/project.py data
python tools/project.py assets

# 3. 运行
python tools/project.py run

# 4. 编译 AbilityGraph Resource → generated execution plans
python tools/project.py graphs

# 5. 提交前完整验证
python tools/project.py check

# 6. 生成完整、可编辑的工程 ZIP
python tools/project.py scaffold
```

工程制品输出到 `build/佣兵小镇-工程源码.zip`，包含代码、场景、策划表、原始美术、运行时美术、资源导入设置、技能编辑器、文档、测试与工具。归档会在独立临时目录重建生成物并完成 `project.py check`，再逐文件校验 ZIP 的 CRC 和 SHA-256；排除缓存目录、旧构建、日志、临时备份、验收截图和本机来源索引。解压后打开 `佣兵小镇/project.godot`，先阅读 `AI_AGENT_GUIDE.md`。工程归档流程见 [SOURCE_ARCHIVE.md](docs/SOURCE_ARCHIVE.md)。

指定其他输出位置：`python tools/scaffold.py build --output "F:/T8demo/佣兵小镇-工程源码.zip"`。工具保留已有 ZIP，重复生成时使用新的文件名。

里程碑或发布前运行 `python tools/project.py release` 更新 allowlist 输入清单；它不替代平台签名/上传流水线。

Godot 不在 PATH 时增加 `--godot <可执行文件>`，或设置 `GODOT_BIN`。

### Ability Graph 编辑器与测试入口

`src/runtime/ability/ability_run.gd` 是由 Ability Service 创建的运行时 `RefCounted`，不是 Godot 场景入口；在编辑器中对它使用 “Run Current Script” 会出现“doesn't inherit from SceneTree or MainLoop”提示。请使用 `F6/F5` 运行场景/项目，或运行 `python tools/project.py test`（对应 `res://tests/test_runner.gd`）。技能图资源位于 `authoring/combat/ability_graphs/`，启用编辑器插件后可在 Inspector/FileSystem 中打开图编辑器。

## Git 与美术资源

仓库：[bootestRook/Town](https://github.com/bootestRook/Town)。贴图、音频、字体和骨骼资源使用 Git LFS；首次克隆与提交步骤见 [VERSION_CONTROL.md](docs/VERSION_CONTROL.md)。

## 已包含的通用能力

| 能力 | 直接产物 |
|---|---|
| 生命周期与装配 | 唯一 Composition Root；默认无 Autoload |
| 状态与行为 | Definition/Instance、Feature state owner、Intent/Action/Command、局部 Hook |
| 可复现性 | 命名确定性 RNG、stream snapshot/restore、表现流隔离原则 |
| 存档 | 版本化 DTO、顺序迁移、原子写、备份、未来版本拒绝 |
| 策划配置 | 版本化 Schema、类型/ID/外键/枚举/范围/平台覆盖、确定性 JSON |
| 美术资源 | DCC 源与 runtime 分区、逻辑资源 ID、import policy、owner/license/budget/consumer 台账 |
| UI | 固定骨架 `.tscn`、动态绑定、只提交意图、不改领域状态 |
| 自动治理 | 架构 lint、生成物防漂移、Python 管线测试、Godot 领域/场景测试、启动烟测 |

## 目录地图

```text
art_source/                  DCC/可编辑源文件；.gdignore 排除 Godot 导入
assets/runtime/              Godot 实际消费的导出资源
assets/generated/            自动资产台账
data/schema/                 表结构与跨表约束
data/source/                 策划、人类可编辑的源表
data/generated/              运行时只读 JSON 与来源指纹
scenes/                      固定场景和 UI 骨架
src/app/                     生命周期与依赖装配
src/foundation/              RNG、Save 等底层协议
src/runtime/                 Action/Hook 等通用执行原语
src/runtime/core/            Entity、Attribute、Tag、Effect、Event、Condition、Formula
src/runtime/ability/         Ability graph、plan、grant、cooldown、run
src/runtime/modules/         Damage/Buff/Projectile/Movement/Summon/Area gameplay modules
src/data/                    运行时数据注册表
src/resources/               逻辑资源注册表
src/features/<feature>/      各游戏功能自己的 domain/presentation
src/platform/                文件、平台和外部能力适配
tests/                       Godot 单元与真实场景测试
tools/                       数据、资产、架构和项目入口
docs/                        精简的架构与生产指南
authoring/                   Godot Resource authoring source（不进入发行包）
addons/                      editor-only plugins（不进入发行包）
```

## 从哪里继续

- 技术层和依赖方向：[ARCHITECTURE.md](docs/ARCHITECTURE.md)
- 策划表分类和新增表：[DATA_AND_CONFIG.md](docs/DATA_AND_CONFIG.md)
- 美术、动画、音频、VFX 管线：[ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md)
- 新 Feature / 新机制 / UI 扩展：[EXTENDING.md](docs/EXTENDING.md)
- 测试、性能和发布：[TESTING_AND_RELEASE.md](docs/TESTING_AND_RELEASE.md)
- WebApp / EXE 分辨率确认与打包：[PACKAGING.md](docs/PACKAGING.md)
- Godot API、引擎行为和版本差异：[OFFICIAL_GODOT_DOCS.md](docs/OFFICIAL_GODOT_DOCS.md)

## 默认边界

- 默认是离线单机底座；联机权威、预测、回滚需另做架构阶段。
- 示例是 2D UI，但核心不依赖游戏品类；3D/物理项目在 Feature 与资产 policy 中扩展。
- 不内置 ECS、全局 EventBus、万能行为 DSL、FMOD、Spine、Sentry 或商店 SDK。
- CSV 是协作友好的默认策划源；大型团队可以替换为 XLSX/数据库，但必须保持同一 Schema/校验/生成契约。

许可证见 [LICENSE](LICENSE)。
