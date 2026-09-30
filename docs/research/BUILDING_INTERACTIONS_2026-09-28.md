# 建筑二级交互核查与 Demo 范围

后续实现已扩充：本文记录2026-09-28初版，不代表当前装备店配方/页面范围。现行四分页、全部源配方与交易分别见 [武器店](WEAPON_SHOP_2026-09-30.md) 和 [防具店](ARMOR_SHOP_2026-09-30.md)。

日期：2026-09-28。参考根目录：`F:/GameResearch/佣兵小镇`。以本地包和用户两张截图为主要依据；网络攻略用作交叉核对，不把不同版本的数值混入本地配置。

用户确认本轮实施选项 1、2、3：**交易所、医院、餐馆、旅馆、酒馆、武器店、防具店、饰品店，共八类。**

## 本轮可操作链

| 建筑 | 玩家操作 | 实际状态变化 | 英雄后续行为 |
|---|---|---|---|
| 交易所 | 点材料→设置预购数量→确认；英雄页可召唤；清空数量取消预购 | 下单不付款；英雄到店后按订单、携带数量和镇长余额成交；材料入镇长库存、钱入英雄钱包 | 缺少镇长资金时保留未完成订单；成交后继续满足需求 |
| 医院 | 纱布拖到中间操作台 | 按 1:1 消耗全部可用纱布并生成绷带，生产动画约 2 秒 | 生命低于 70% 时前往；付费并消耗成品、占床、12 秒基础治疗后离开 |
| 餐馆 | 面粉拖到操作台 | 生成甜甜圈 | 饥饿需求低于阈值时排队、消费、恢复 |
| 旅馆 | 动物毛拖到操作台 | 生成毛毯 | 疲劳需求低于阈值时排队、消费、恢复 |
| 酒馆 | 苹果拖到操作台 | 生成气泡果酒 | 心情低于阈值时排队、消费、恢复 |
| 武器店 | 选剑/弓/杖配方→数量→打造→仓库；出售页召唤英雄 | 铜块 10、狼牙 5 / 件；每件都有唯一实例 | 到店等待交易；点英雄头上装备图标或出售页“交易”→选装备→出售；按职业换装 |
| 防具店 | 选上衣/长裤配方→打造→出售 | 铜块 10、熊皮 5 / 件；基础售价 6000 | 英雄支付自己的金币，装备进入英雄对应槽位，旧装备进入退役清单 |
| 饰品店 | 选项链/戒指配方→打造→出售 | 使用二阶材料；基础售价 63100 | 同样经过到店、确认交易和换装；需要交易所升级才能持续收购二阶材料 |

拖到操作台外不扣材料。库存不足、余额不足、无空位、错误材料、重复出售、职业不符和没有装备提升均不能产生免费物品或重复扣费。关闭二级页面只切换表现，经营和英雄行为继续运行。再次打开读取当前状态。

医院五级在本地表中的价格加成为 21%，绷带基础售价 800，最终 968；治疗基础时间 12 秒。这与用户医院截图相符。交易所二级后低阶生活成品恢复比例按本地表降至 80%。

## 原包证据

所有路径相对参考根目录，来源仅用于研究与资产转换；没有复制商业业务 JS 到游戏。

- `02_代码模块/BuildLifePnlCtrl.js`：拖拽起止、投放区域、`startProduce` 按材料总量计算生产数量、生活建筑四种室内与机器切换、服务席位与升级阶段。
- `02_代码模块/CptProduce.js`、`CptHospitalProduce.js`：约两秒的生产动画。生产数据先确认，动画并非服务计时。
- `02_代码模块/BuildModel.js`、`Hero.js`：生活成品消费、金币结算、席位与 `buyDrugAndRecover` 的恢复时间/比例。
- `02_代码模块/ExchangeModel.js`、`PurchasePnlCtrl.js`、`ExchangePnlCtrl.js`：订单数量、取消、交易请求、英雄库存与召唤。
- `02_代码模块/EquipmentBuildPnlCtrl.js`、`ArmsLibCellPnlCtrl.js`、`EqDrawingsUsePnlCtrl.js`、`EquipmentModel.js`：配方选择、数量打造、待售实例、召唤与装备交易。
- `04_配置表/JSON原表/resources/common/json/`：`c22_item`、`c35_cc_value`、`c37_shenghuo_xiaohao`、`c36_jz_yiyuan/fandian/lvdian/jiudian`、`c41_trade`、`c40_wuqidian/fangjudian/shipingdian`、`c51_tuzhi`、`c39_zhuangbei`、`c39_shuxing`。
- `03_美术资源/04_预制体/resources/view/`：生活建筑 `life/BuildLifePnl` 及四个 `node*Produce`，交易所 `exchange/ExchangePnl`，装备店 `equipment/EquipmentBuildPnl`，共用标题 `common/CommonBuildLevelNode`。
- `07_核验与索引/精灵切图索引.json`、`Spine索引.json`、`结构资源索引.json`：精确 UUID 和原始文件映射。Spine 3.8.99 烘焙为本地 PNG 序列，保留透明背景和皮肤，不要求 Godot 安装 Spine 插件。

公开交叉证据：官方[游戏介绍及开发者说明](https://www.taptap.cn/app/542841)明确描述冒险、材料出售、生活需求和消费闭环；2024-09-28 的[装备打造与出售教学](https://www.taptap.cn/moment/589046115295300275)给出职业武器、打造、召唤、到店后手动出售步骤。后者是测试期资料，页面版本差异以本地包为准。

## 全部地图建筑核查

此表依据 `c33_jianzhu` 的 18 个建筑。所有建筑均已找到世界美术；以下二级入口/预制体也均已定位，**目前没有发现必须凭空补画的缺失页面**。页面存在不等于业务已实现。

| ID | 建筑 | 原包页面/入口（view 下） | 本轮 |
|---|---|---|---|
| 1 | 医院 | life/BuildLifePnl，bj4 / nodeHospitalProduce | 实装 |
| 2 | 餐馆 | life/BuildLifePnl，bj1 / nodeCattenProduce | 实装 |
| 3 | 旅馆 | life/BuildLifePnl，bj3 / nodeHotelProduce | 实装 |
| 4 | 酒馆 | life/BuildLifePnl，bj2 / nodeBarProduce | 实装 |
| 5 | 主城 | city/CityPnl；建筑解锁与等级条件 | 只使用演示等级条件值，主城页面待做 |
| 6 | 武器店 | equipment/EquipmentBuildPnl | 实装三张入门配方 |
| 7 | 交易所 | exchange/ExchangePnl | 实装一、二阶材料及升级 |
| 9 | 防具店 | equipment/EquipmentBuildPnl | 实装两张入门配方 |
| 10 | 饰品店 | equipment/EquipmentBuildPnl | 实装两张入门配方 |
| 11 | 复活祭坛 | buildPopup/BuildRevivePnl；复活与时长 | 已定位，待做 |
| 12 | 战斗号角 | bossPopup/BuildbossPnl；召唤 Boss | 已定位，待做 |
| 13 | 强化所 | equipment/StrengLibPnl；装备强化 | 已定位，待做 |
| 14 | 地下城 | GameBuildingPve→PveModel.reqPveInfo→pve/DungeonSelLevPnl | 已定位，待做；不是生产店 |
| 16 | 转生所 | reincarnation/ReincarnationPnl | 已定位，待做 |
| 20 | 修炼所 | train/BuildTrainPnl | 已定位，待做 |
| 25 | 召唤法阵 | monsterShow/MonsterCallPnl | 已定位，待做 |
| 26 | 公寓 | apartment/BuildApartmentPnl | 已定位，待做 |
| 27 | 知识神殿 | knowledge/BuildKnowledgePnl | 已定位，待做 |

另找到觉醒页面/代码，但不属于当前 `c33_jianzhu` 的 18 个地图摆放对象，暂不增加建筑。

## 已知差异与未核实项

- 本轮还原的是八类建筑的基础经营链，不是全部原游戏系统。高级图纸、随机星级/词条、强化洗练、分解/返还材料、钻石生产、广告、付费席位和全等级解锁仍在清单中。
- 原版装备生成、出售等请求最终由服务器返回结果；APK 不包含完整服务端算法。Demo 采用配置基础属性和基础售价，没有把推测随机结果标记为原版事实。原有装备保留在英雄退役清单，不擅自模拟强化材料返还。
- 英雄已替换为艾比、特伦斯、芭芭拉的原包身体/头发/面部组合，并接入前后待机、行走、攻击与死亡序列。装备替换改变实际生命、攻击、防御和所有权；完整装备外观附件仍待做。
- 后续英雄阶段已删除计时产出和预设途经点，改用导航格、建筑阻挡、角色避让、实际野外普通攻击和原表随机掉落；复活祭坛开放基础流程。详见 [英雄行为接入记录](HERO_BEHAVIORS_2026-09-28.md)。
- 为验证所有店铺，初始八类建筑已建成；主城条件值 5，生活店 5，装备店 1，交易所 1。初始材料与金币是 Demo 配置，非原游戏新档。所有建造前美术仍保留。
- 暂无跨进程存档；同一次运行中切页不会重置。完整长期经济平衡需等待真实战斗和成长接入后评估。

## 验证入口

`python tools/project.py check` 为全项目门禁。`tests/test_town_operations.gd` 验证原子生产、取消/部分成交、席位竞争、治疗时间、唯一装备转移、职业/余额条件与完整循环。`tests/capture_buildings.gd` 使用原生鼠标输入检查建筑点击、拖拽取消和生产、订单、打造、手动出售；截图与日志在 `validation/buildings/` 及 `validation/building_capture.log`。
