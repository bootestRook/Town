# 编码代理项目规则

## 目标

保持这是一个小型、可运行的 Godot 研发底座。具体游戏规则属于 Feature，不属于框架核心。

## 开始工作

1. 阅读 `README.md`。
2. 只阅读 `docs/` 中与当前任务有关的指南。
3. 只有 Godot API、引擎行为或版本差异影响任务时，才按 `docs/OFFICIAL_GODOT_DOCS.md` 查询本地官方文档。
4. 首次运行 `python tools/project.py doctor`；交付前运行 `python tools/project.py check`。
5. 查询原 APK 或拆包来源时，本机先读 `docs/research/SOURCE_REFERENCE.md`；Git/ZIP 不提交该文件，可移植资源登记见 [THIRD_PARTY.md](THIRD_PARTY.md)。

## 模块边界

- `src/foundation/`：只放轻引擎依赖的基础原语；不得依赖 Feature、UI 或项目数据。
- `src/runtime/`：Action/Hook 执行契约；不得依赖 Node 或具体 Feature。
- `src/features/<name>/domain/`：持有该 Feature 的状态和规则；不得访问 Node、查询场景或操作 UI。
- `src/features/<name>/presentation/`：读取快照和事件并提交 Intent；不得写入领域状态。
- `src/app/`：只负责组合根和生命周期。
- `data/source/` 与 `art_source/`：人工编辑的源文件。
- `data/generated/` 与 `assets/generated/`：自动生成，禁止手工修改。

## 硬性规则

- 静态 Definition 数据在运行时不可变；可变值必须存放在有明确所有者的 Instance/State 中。
- 状态变更必须通过 Command 或状态所属 Feature 的公开接口完成。
- 玩法随机必须使用注入的命名 `RngSet` 流；表现随机必须使用独立随机流。
- 领域事件只描述已经发生的事实，表现提示负责响应；动画和特效不得决定规则结果。
- 固定 UI 结构必须保存在 `.tscn` 中；代码只能创建真正动态的列表项。
- 未经用户明确要求，禁止在游戏画面自行添加说明文字、操作提示、标题/状态栏、导航入口或功能按钮。原型说明与验证放在文档和测试中，不得擅自变成游戏 UI。
- 共享代码不得根据具体 Definition 或内容 ID 进行分支。
- 调用 Godot API 前必须按 `docs/OFFICIAL_GODOT_DOCS.md` 查询目标引擎导出的签名；不得凭记忆假设类、方法或参数存在。
- 最终打包前必须按 `docs/PACKAGING.md` 确认目标、分辨率、伸缩策略和适配矩阵；`tools/package.py check` 未通过不得发布导出。
- WebApp 必须交付根目录含 `index.html` 且不超过 100,000,000 字节的 ZIP；颜色和字体问题按 `docs/WEB_EXPORT_PARITY.md` 验收。
- 打包分辨率默认读取 `project.godot`；特殊值必须说明并同步项目。导出前须清缓存、重建生成物和源指纹，禁止复用旧输出。
- 未编写 ADR 前，不得新增 Autoload、全局 EventBus、第三方依赖、数据格式、Save/RNG 契约变更或跨 Feature 依赖。
- 所有文本保持 UTF-8 无 BOM、LF 换行。

## 常用命令

```text
python tools/project.py data     # 校验 CSV/schema 并重新生成运行时 JSON
python tools/project.py assets   # 校验源资产和运行时资产并重新生成清单
python tools/project.py run      # 运行项目
python tools/project.py check    # 执行管线、架构、Godot 和运行冒烟检查
```

## 完成标准

- 最小但真实的纵向路径可以正常工作。
- 无效数据、错误引用和错误路径都有测试。
- `python tools/project.py check` 通过，且没有 `SCRIPT ERROR` 或 `ERROR` 标记。
- 只有契约或工作流发生变化时才修改文档。
