# 测试、性能与发布

## 默认验证层

| 层 | 当前入口 | 目的 |
|---|---|---|
| 数据/引用 | Python pipeline tests | schema、ID、外键、类型、范围、确定性生成 |
| 资产/预算 | asset pipeline tests | source/runtime、policy、尺寸/字节、hash、license、consumer |
| 纯领域 | `tests/test_*.gd` | Action/Command/Hook、状态 owner、RNG、Save |
| Scene 集成 | `test_runner.gd` 内 smoke | `.tscn`、资源导入、Composition Root、UI→Intent |
| 架构 | `architecture_lint.py` | 跨层依赖、Node、随机、Autoload、动态固定 UI、ID 分支 |
| 运行烟测 | Godot `--quit-after` | 主场景真实启动无脚本错误 |

`python tools/project.py check` 顺序执行全部六层，并同时检查进程输出中的 `SCRIPT ERROR`/`TEST FAILURE`，避免 Godot 导入返回 0 却隐藏解析错误。

## 新机制测试清单

至少覆盖正常、边界、非法输入、取消/失败、重复触发、对象已失效、随机复现、Save 恢复。若领域测试绕过表现，必须另有真实 Scene 测试验证资源、时序和清理。

## 性能预算

`quality_budgets.csv` 只提供可执行预算位置，示例阈值不是项目结论。立项时为目标平台、基准硬件和代表场景定义 frametime、内存/显存、加载、包体、纹理、粒子、音频 voice、对象/node/orphan 和长程增长预算。预算变化要有原因、负责人和基准结果。

长生命周期项目应增加多 seed 自动遍历、watchdog、状态 dump、资源/cache delta 与内存快照。它们是 nightly/里程碑门禁，不必拖慢每次本地修改。

## 发布清单

正式流水线应生成：commit/version、Godot/SDK/依赖版本、许可证/SBOM、数据与资产 manifest、导出 preset、测试结果、符号/崩溃 release、制品 SHA-256、签名/depot 信息和回滚目标。

本仓库的 `python tools/project.py release` 会生成当前 release allowlist 输入的路径、字节数、逐文件/组合 SHA-256；`check` 会阻止清单漂移。真正导出后仍需为 EXE/PCK/Web 包再次生成制品级 hash 和签名记录。

发行 allowlist 默认排除：`art_source/`、`authoring/`、`addons/`、`data/source/`、`data/schema/`、`tools/`、`tests/`、`docs/`、editor plugin 源和调试秘密。`data/generated/`、`assets/runtime/`、`assets/generated/`、Scene 与运行时代码进入制品。

推荐 CI 的唯一必跑命令：

```text
python tools/project.py check --godot <Godot console executable>
```

平台导出、签名和上传是后续 stage；不要把 export templates 安装或 Web 导出强塞进每次开发反馈回路。

需要生成 WebApp 或 Windows EXE 时，必须先按 [PACKAGING.md](PACKAGING.md) 确认分辨率契约和适配矩阵，再运行目标 profile 的检查与导出；“Godot 导出成功”不等于“目标布局已适配”。
