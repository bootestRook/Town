# 0011 招募流程使用源界面与本地结算

沿用 TownMainSystems 组合、TownRecruitment 状态所有者和已注入的招募 RNG 流。移除 MainPanels 的旧招募路径，改为独立固定场景；展示动画只读取已经提交的结算回执，不决定随机结果、扣费或奖励。

沿用 CSV/schema 数据契约，扩充 main_recruit 的抽取权重，增加 main_recruit_rules 与 main_recruit_pool 配置；不新增 Autoload、依赖或存档迁移。卷轴使用现有 inventory 的 item.10001。

依据 RecruitHomePnlCtrl、RecruitModel、RecruitRefreshPnlCtrl、RecruitInterludeAnimPnlCtrl 及 c29_zm_*、c25_public。首抽一张卷轴，后续钻石、每日折扣、条件概率、重复转碎片、每次五经验，三人招完自动换批。主动换批提示支持本游戏日不再提醒。广告刷新在本地直接结算，商城只消费游戏钻石。

截图优先于旧 APK：新增截图所示心愿入口，但旧包无该版本服务端规则；心愿仅在拥有锤锤后可启用，其旧池条目权重为0，启用时赋予100的基础权重，再对入池权重乘2，仍遵守品质和子池的等级门槛。这是明确的 demo 规则。旧包停留 1800 秒、七折计算为 floor(180*0.7)=125；不伪装服务器精确复现。龙魂技能页属于截图导航，旧包没有同版本系统，保留入口并展示可查看的解锁状态，不凭空提供付费抽取。
