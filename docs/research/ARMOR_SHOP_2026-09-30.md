# 防具店四分页与双部位交易

## 用户要求与来源

按用户四张防具店截图和“防具店UI信息、逻辑等同武器店”实现。截图是参考，用户请求决定范围。源入口见 本机来源索引（未随包提供；[资源来源登记](../../THIRD_PARTY.md)）。原包证据包括 `c40_fangjudian`、`c51_tuzhi` / `c51_tuzhi_yicixing`、`c39_zhuangbei` / `c39_citiao` / `c39_shuxing`、`BuildEqCallItemCmpt.js`、`BuildEQItemCmpt.js`、`BuildEquipSellPnlCtrl.js`、`EquipmentModel.js` 及对应预制体/透明切图。

- 防具店为 building.9，上衣部位2、裤子部位4；15级配置、30种常规配方、36种一次性图纸、86种成品定义来自源表。
- Lv3一阶顺序：守望上衣、守望长裤、振奋上衣、振奋长裤、日冕护甲、日冕护腿。升4级需要主城4级及64,000金币。正式新游戏两店均为1级。
- 旧APK库存150，用户新版图300；采用300，两店分别计数。
- 源数据有8件名为“测试”的开发成品，基础属性是攻击；原样保留配置，只有持有对应图纸才显示，不默认发放。正常防具按源防御字段渲染和计算。
- 装备评价按当前等级 `js` 的同部位配方比较基础值：不足为评价1，达到为评价3。交易源 `buWeiBuyMap` 按部位记录，本次上衣、裤子各可购买一次；部位标签“上衣”“裤子”来自原预制体。

## 实际流程

配方和图纸按阶筛选，等级决定解锁。打造最大数量同时受材料、一次性图纸、单次10件与本店300容量约束，原子扣料并生成唯一实例。材料详情、预购接已有交易所，返回保留数量。

货架支持网格/列表、详情、锁定/解锁、多选分解，按源 `fj_id` 给收益。锁定、重复/失效序号、跨店操作均拒绝。英雄页读取真实品质、职业、元素、等级、星级、战力和两个装备槽及评价；点击已穿戴装备进入只读详情，无货架锁定按钮。英雄卡打开已有详情，返回保留防具店英雄分页。

召唤更新实际行走目标，英雄不瞬移；到店后即使空货架也持续等候。点击原 `js_qipao_02` 头顶气泡打开交易。两部位分别列候选，职业、锁定、属性提升、私有钱包和本部位已购买状态决定成交。不可交易按钮变暗；资金不足可赠送玩家金币。成交扣英雄钱包、增加玩家金币、从货架移除同一实例、换入对应部位、旧装备进入退休列表，并刷新真实战斗属性。关闭交易释放等待；重新到店重置两部位标记。

## 实现与维护

`TownEquipmentShop` 读取两店定义并提供公开规则，`TownOperations` 拥有 `state.equipment_shop`：calls按英雄记录目标店，trading/building记录当前交易，locked记录实例序号，purchased记录本次部位数组。`TownWorkshop` 执行真实购买。沿用注入的 `town.equipment` RNG，不新增框架契约或跨Feature依赖。

固定界面共用 `equipment_shop_page`、`equipment_dialog`、`equipment_trade`、`equipment_hero_row` 等 `.tscn` 和表现脚本，配置决定建筑和部位，动态创建仅用于列表项。防具显示两个固定槽位，武器显示一个。

`tools/import_equipment_shop_reference.py` 生成六张 `equipment_shop*` 源CSV，旧weapon专用脚本/表/路径已删除，`town_equipment` 只保留饰品2条。`tools/author_equipment_shop_scene.py` 和 `tools/author_equipment_theme.py` 生成场景与主题。原贴图562张，源/运行1124份都有来源、UUID、SHA256 sidecar，溯源扫描0缺失；汇总为 `art_source/equipment_shop/provenance.json`，未AI重画。

## 验证与范围

- `tests/test_armor_shop.gd`：717断言，`validation/armor_tests.log`。全66配方、消耗、两槽属性、分解、满仓/升级/跨店边界、真实到店等待、双部位交易、资金守恒、重新召唤及旧装备退休均覆盖。
- `tests/test_equipment_shop.gd`：武器回归959断言，`validation/armor_weapon_regression.log`。
- `tests/capture_armor_shop.gd` / `tests/capture_weapon_shop.gd`：Windows Godot实际鼠标回归，日志 `validation/armor_capture.log` / `validation/armor_weapon_capture.log`。防具另验证第二部位钱包不足、再次赠送后购买、已穿戴装备只读详情。
- `validation/armor_shop/`：750×1334、360×640、750×1624的四页签/交易，另有打造、材料预购、列表/分解、赠送、到店、双部位成交等证据。Lv3/主城3、860k/1635、材料和预装蓝防具仅为夹具，正式初始化不写死这些值。
- 原生防具回归44项检查、35张捕获，武器回归36项检查均通过。独立复核初审未发现新增重大视觉/状态问题；唯一旧文档修正获限定 `ship`，记录 `.impeccable/review/armor/`。
- 最终 `python tools/project.py check` 全部通过：25项Python测试、9177项Godot断言、数据/资产/架构校验、7988文件源指纹及运行冒烟；最终日志 `validation/armor_check_final.log` 无 `SCRIPT ERROR` / `ERROR`。这些结果不外推真机或导出包。

本轮延续武器店基础成品 `zb_1` 与源词条区间，不宣称完整还原服务端随机分布、全套锻造动画、地图动态换装或所有高阶材料产出。本轮未导出发行包、未做移动真机验证。
