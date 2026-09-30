# 战斗号角：源页面、野外集结与 BOSS 战

日期：2026-09-30。范围：建筑 12「战斗号角」、独立建筑页、真实地图英雄集结、BOSS 生成和战斗、消耗返还、宝箱及扫荡。沿用项目的进程内状态生命周期，不新增联网或存档契约。

## 来源与取舍

源档案入口见本机 `SOURCE_REFERENCE.md`。以下路径相对于拆解档案根目录；配置路径前缀为 `04_配置表/JSON原表/resources/common/`，代码位于 `02_代码模块/`。

| 来源 | 本次采用内容 |
| --- | --- |
| `json/c33_jianzhu.json` | 建筑 12 的名称、贴图和地图布局；源格位置 81,23，占地 8×8。 |
| `json/c36_jz_zhaohuan.json` | 30 级建筑、当前行升级金币费用与地下城通关门槛。1→2 级 30,000 金币，2→3 级 80,000 金币；30 级封顶。 |
| `json/c43_boss_zhaohuan.json`、`json/c2_guaiwu.json` | 30 档 BOSS、源生命/攻击/防御、30 秒准备及 600 秒战斗。2 级巨人为 103,617 / 516 / 323，界面缩写为 104k / 516 / 323。 |
| `json/c43_boss_shoufei.json`、`baseconf/c25_public.json` | 每日 4 次免费、召唤券 12001、钻石递增 50/100/150/200/250/300 后封顶、结束后 5 秒冷却。 |
| `json/c2_guaiwu_drop.json`、`json/c2_guaiwu_bx.json` | 地面及英雄掉落的概率和数量区间、宝箱普通奖励；未采用广告奖励。 |
| `SummonBossModel.js` | 准备/战斗/结束状态、全员到齐后最多再等 3 秒、失败和中止返还；扫荡准备 1.5 秒。 |
| `CptMapField.js`、`btMapField.js`、`AIStatePrepareBoss.js`、`AIStateWaitBossStart.js` | 清场、暂停普通怪刷新、真实英雄寻路与到达后等待。采用源地图出生格 20,25。 |
| `btCptBossViewField.js`、`Hero.js` | 战斗阶段生成 BOSS 并让参与英雄攻击；扫荡生成后约 0.3 秒结束。 |
| `BuildbossPnlCtrl.js`、原预制体和切图 | 建筑标题、升级栏、BOSS 轮播、属性与奖励、召唤和中止确认、帮助文本、旧宝箱替换确认。 |
| 用户本轮两张截图 | 地图入口及 Lv.2 页面视觉依据；保留扫荡和 5/10 次勾选。白色微信容器不是游戏 UI。 |

旧 APK 控制代码隐藏了扫荡按钮，用户的新截图明确显示该入口。本次以用户截图为 UI 依据，5/10 次通过已有单次扫荡顺序执行，并按实际资源预先确认总钻石费用；不将其描述为已复原原服批量请求。源宝箱配置有多个候选 ID、没有可证实的服务端选择权重，本地使用命名随机流等概率选择候选，再按源普通奖励范围结算。

英雄营地的「仅金币升级」是该建筑的专门要求，未扩展到战斗号角。号角保留源地下城升级门槛。正常新游戏从号角 1 级开始，截图中的 2 级、857k 金币和 1635 钻石只用于验证样本。

## 真实纵向路径

1. 点击地图号角打开页面。等级、资源、免费次数、属性和奖励来自领域快照，可预览锁定的高等级 BOSS；召唤仍受建筑实际等级约束。
2. 正常召唤按免费次数→召唤券→钻石选择当前消耗。钻石和未领取旧宝箱需要确认，取消弹窗不扣费。一次只扣当前挑战的费用，失败不预扣后续扫荡。
3. 召唤关闭建筑页，镜头移至野区。清除普通怪和遗留弹道，实际已出战且未派驻城镇的英雄沿既有导航移动，服务中的英雄完成当前服务后参加。不会瞬移到集合点；到达后显示等待状态并计入实际人数。
4. 默认准备 30 秒，全员到齐后剩余时间最多 3 秒。准备完成才创建真实 BOSS；未到齐的英雄继续赶往战场。BOSS 和英雄使用现有攻击序列、命中、伤害、生命与死亡规则。
5. 胜利发放源地面掉落及参与英雄的个人战利品，生成可点击的源宝箱。宝箱奖励只能领取一次；新宝箱只在下一次胜利时替换旧宝箱，取消或失败保留旧宝箱。
6. 全员倒下、超时或确认中止会返还本次消耗；重复中止不能重复退款。结束后恢复普通怪和英雄常规行为，并进入 5 秒冷却。
7. 首次击败对应等级后开放扫荡；5/10 次互斥勾选。扫荡遵守源快速战斗时序，逐次结算并领取宝箱，间隔仍有冷却。资源变化导致后续费用超出已确认额度时停止队列。

每日次数按 UTC+8 日界刷新，跨日中止不会把新一天的免费次数叠加至 4 次以上。集结/战斗时禁止移除或城镇派驻参与者，并与已有独立挑战互斥。地图上阵人数继续由英雄营地实际等级限制。

## 模块与资源

- `TownBattleHorn` 持有规则和 `state.horn`，通过 `TownOperations.horn_command()` 接收意图；静态等级表不在运行中修改。
- `TownHornEncounter` 连接现有导航、移动和战斗，`TownHornLoot` 使用注入的 `town.horn` 随机流。没有跨 Feature 依赖或新全局状态。
- 固定页面、奖励项模板和世界提示分别为 `battle_horn_page.tscn`、`horn_reward.tscn`、`horn_world.tscn`；表现脚本只读快照、发出意图。
- `main_horn_levels.csv`、`main_horn_chests.csv`、`main_horn_items.csv` 分别导入 30 档等级、87 条宝箱普通奖励和 95 条物品展示定义。schema 校验动画、道具图标、等级及时序引用。
- 原资源包括页面切图、6 套 BOSS 的正背面骨骼烘焙动作、攻击定义及特效。UI 资源逐项记录于 `art_source/battle_horn/provenance.json`，源图和运行时图均含来源说明。没有用整张截图替代交互界面。
- 骨骼图集按不超过 4096 宽的多行排列保存，保留原分辨率和透明边界。少量大图使用 `actor_atlas` 策略（8192×8192、16 MiB），常规地图贴图策略未放宽。巨人攻击特效根据源 Cocos 双轨偏移和透明度合成，不声称逐帧等同原引擎。

完整源资源重导顺序如下；先确认源查询入口可访问。日常只改配置可用 `--data-only`，只刷新切图及来源记录可用 `--art-only`，避免不必要地重置骨骼烘焙任务。

```text
python tools/import_battle_horn_reference.py
python tools/import_combat_reference.py
node tools/bake_hero_spine.cjs --missing
python tools/register_hero_assets.py
python tools/author_battle_horn_scene.py
python tools/project.py data
python tools/project.py assets
python tools/project.py release
python tools/project.py check
```

`author_building_scenes.py` 的 `shell()` 已登记 Horn 页面，现有 `main.tscn` 保留 HornWorld 实例。完整检查会执行 Godot 资源导入，不需要手工修改自动生成目录。

## 验证证据与边界

- `tests/test_battle_horn.gd`：69 条专项断言，覆盖等级/费用/门槛、真实移动与到齐、实战伤害、胜利/失败/超时、重复和跨日返还、宝箱单次领取、免费/券/付费连续扫荡及独立挑战互斥。初始三名英雄可以通过正常战斗击败首级 BOSS，未依赖强制扣血。日志 `validation/battle_horn/rules.log`。
- `tests/capture_battle_horn.gd`：18 项原生点击检查，覆盖地图建筑、轮播、帮助、资源确认、中止返还、5/10 次选择、扫荡和宝箱；日志 `validation/battle_horn/capture.log`。
- 同目录 11 张原生截图包含普通、锁定、集结、实战、帮助、取消、付费和宝箱状态。尺寸为 750×1334、360×640、750×1624；长屏沿用固定舞台居中留边，未进行移动真机验证。
- 独立终审发现的立绘遮挡、模态箭头层级已统一修正。`layout.json` 对巨人 idle 全部 40 帧检查，可见角顶最小 y=387.21875，位于升级文案底部 y=385 下方，不再遮挡；帮助和确认覆盖层的根节点位于背景箭头之上。限定修正复核结论见 `.impeccable/review/horn/verdict.md`，不作为全项目或全原版一致性认证。
- `python tools/project.py check` 最终通过：24 项 Python 测试、7231 条 Godot 断言、数据/资产管线、架构检查、源指纹及运行冒烟，无 `SCRIPT ERROR` 或 `ERROR` 标记。完整结果记录于 `validation/battle_horn/project_check.log`。
- 该实现覆盖本地召唤与战斗闭环。原服权重、联网与跨进程持久化、广告奖励、全套传送门出生特效及原引擎所有技能效果不属于已验证的完整复刻内容；本次未发布 Windows 或 Web 新导出包。

战斗号角二级验证样本（本机验收记录，未随工程归档）

真实英雄集结（本机验收记录，未随工程归档）
