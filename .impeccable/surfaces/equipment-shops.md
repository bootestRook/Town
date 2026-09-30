# 装备店增量：防具店

模式：Operate。用户明确要求“防具店UI信息、逻辑等同武器店”，源截图钉住既有手绘奇幻方向，不运行概念抽签或新增审批。

THESIS：原项目四分页与真实制作、召唤、交易闭环。
OWN-WORLD：原切图、青黑撕边板、紫色链条建筑背景、源中文字体及位图战力。
STORY：按等级选择配方，材料打造到货架，召唤英雄实际到店，点击气泡分别交易上衣、裤子。
FIRST VIEWPORT：上方建筑/升级板，下方四列配方或英雄行，底部四页签和右箭头。
FORM：用户源截图固定结构，沿用武器店750×1334等比居中舞台；360×640全页缩放，750×1624上下留边。
FINISH：unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

源码边界：`equipment_shop_page.tscn`、`equipment_trade.tscn`、`equipment_dialog.tscn` 和对应 presentation 脚本；静态结构在场景，动态列表读快照，规则由 `TownEquipmentShop` / `TownWorkshop` 持有。武器与防具共享实现、独立建筑等级与300件容量。上衣2、裤子4分别购买一次。旧APK容量150，用户新版截图300优先。

测试数据：Lv3/主城3、860k/1635及三名已装备蓝防具的英雄只在捕获夹具中准备，真实初始化两店Lv1、英雄正常当前状态。测试通过公开装备接口让蓝防具成为真实实例，非页面假数据。交易背景按真实英雄品质，参考中的满级英雄姓名/数值不写死。正式一次性图纸只展示持有者；完整源数据含开发测试图纸，不默认发放。

上衣/裤子底部按钮文字来自源 BuildEquipSellPnl.prefab：上衣、裤子；源评价1/3；源 js_qipao_02 到店气泡。制作使用基础成品zb_1与本地命名RNG，完整源锻造动画、服务端随机分布、地图动态换装仍是既有范围边界。

验收证据：`validation/armor_shop/` 三尺寸四页签/交易、制作/最大数量/材料/预购/列表/分解/赠送/到店/双部位成交。`validation/armor_tests.log` 717断言；`validation/armor_capture.log` 原生鼠标回归；`validation/armor_weapon_regression.log` 武器959断言；`validation/armor_weapon_capture.log` 武器原生回归。

栅格出处：`art_source/equipment_shop/provenance.json`，562张源PNG及同名sidecar，源和运行1124份扫描0缺失。没有生成新美术或以参考截图充当界面。
