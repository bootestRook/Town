# Git 与美术资源

仓库为 [bootestRook/Town](https://github.com/bootestRook/Town)，默认分支 `main`。代码、场景、策划表、资源导入设置和可读的来源记录使用普通 Git；贴图、音频、字体、Spine 骨骼及常见美术编辑源文件使用 Git LFS。具体扩展名以根目录 `.gitattributes` 为准。

首次获取完整工程：

```powershell
git lfs install
git clone https://github.com/bootestRook/Town.git
cd Town
git lfs pull
git lfs fsck
python tools/project.py doctor
python tools/project.py release
python tools/project.py check
```

需要 Git、Git LFS、Python 3.10+ 和 Godot 4.7.1；美术回归测试使用 Pillow。运行入口为 `project.godot`。GitHub 的源码 ZIP 不作为完整美术交付，克隆时必须获取 LFS 对象；本机独立完整工程 ZIP 的流程见 [SOURCE_ARCHIVE.md](SOURCE_ARCHIVE.md)。

提交前运行项目检查和 `git lfs fsck`，通过后正常 `git add`、`git commit`、`git push`。LFS 的 clean/smudge 过滤器自动在 Git 中保存指针，在工作目录中保留真实美术文件；不要手动将工作目录资源改成指针，也不要配置跳过 LFS 上传。

`.gitignore` 排除引擎/Python/Node 缓存、构建输出、验收记录、日志、临时备份及本机来源索引。资源旁的 `.png.import` 等文件属于导入设置，必须提交；`.godot/` 和 `.import/` 目录属于引擎缓存。`art_source/` 与 `assets/runtime/` 均完整提交，generated 文件通过项目管线生成后提交。

`docs/research/SOURCE_REFERENCE.md` 仅在本机保留。仓库中的来源链接指向可移植的 `THIRD_PARTY.md`；指向本机验收截图/日志的链接改为文字说明，避免克隆工程出现失效链接。
