# 完整工程 ZIP

源码归档用于交接可编辑工程，运行入口为压缩包内 `佣兵小镇/project.godot`。这是开发工程制品，平台导出按 [PACKAGING.md](PACKAGING.md) 的显示契约执行。

```powershell
python tools/scaffold.py build --output "F:/T8demo/佣兵小镇-工程源码.zip"
python tools/scaffold.py check --output "F:/T8demo/佣兵小镇-工程源码.zip"
```

Godot 不在 PATH 时增加 `--godot <Godot 控制台可执行文件>`。输出文件已存在时停止，使用新的名称即可；`python tools/project.py scaffold` 默认输出到 `build/佣兵小镇-工程源码.zip`。

保留代码、场景、技能 authoring、策划 CSV/schema、重建后的 generated 文件、完整 `art_source/` 和 `assets/`、资源导入设置、插件、工具、测试、开发文档、许可证、资源来源登记及必要空目录。`art_source/` 内的编辑源文件、骨骼、贴图、音频与溯源 JSON 一并保留。

排除 `.godot/`、`.import/`、Git、Python/Node 缓存、旧 build/dist、validation/reports、`.impeccable/review/` 验收截图、日志、临时文件、备份、旧 ZIP/EXE/PCK/APK 及本机来源索引。保留资源旁的 `.png.import` 等导入设置；其内容可在首次导入时重建引擎缓存。

流程为：选择文件 → 在输出目录下创建独立临时工程 → 重建策划数据与资产清单 → 干净 Godot 导入 → 编译技能图 → 重建 release 指纹 → 完整 `project.py check` → ZIP64 流式压缩 → 对 ZIP 每个文件检查 CRC/SHA-256 并与通过检查的临时工程比对 → 删除本次创建的临时目录。源工程的引擎缓存不会因归档而清空。

归档清单保留既有 `scaffold-manifest.json` 格式，使用当前项目名称，每个文件登记路径、大小和 SHA-256。旧清单不会作为源文件再次进入归档。重复路径、不安全路径、遗漏入口、禁止文件、损坏内容和清单不匹配都会拒绝通过。

本机来源索引不随包交付；临时工程中的对应文档链接注明未随包提供，并指向 `THIRD_PARTY.md`。指向排除验收截图/日志的链接改为文字说明，保留历史记录但不留下失效链接。源目录内的文档保持原链接。

本轮按职责拆分数据字段校验、CSV/schema/引用校验、跨表约束与生成入口；导出配置检查独立于导出流程；技能图测试按执行、控制流、子图、资源/服务分组，共用测试夹具；编辑器的节点目录和详情/调试侧栏独立于图画布。玩法和 Save/RNG 契约保持现状。

干净导入同时校正了战力位图字体的资源登记：`power.fnt` 由 Godot 的 BMFont 导入器接管 `power_font.png`，其图集不再重复登记成可单独加载的纹理。字体、图集及来源文件完整保留，以首次导入后的实际资源类型完成验证。
