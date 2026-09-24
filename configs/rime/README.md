# Rime / 白霜拼音

`~/.local/share/fcitx5/rime` 链接到本目录。上游由 `../../vendor/rime-frost`
Git 子模块管理，词库目录和方案通过相对软链接直接引用它，不需要更新脚本或复制文件。

## 日常更新

```bash
archpostinstall update-vendor --check rime   # 只看上游有什么新提交
archpostinstall update-vendor rime           # 快进子模块、暂存、尝试重新部署
git commit -m "chore(rime): update upstream dictionaries"
```

脚本会：

- 列出新提交和改动统计；
- 单独列出上游改动的 Lua 模块（它们运行在输入法里、能看到每一次按键），部署前请先审阅；
- 提示上游改动或删除了本目录用普通文件覆盖的文件（需要手动合并）；
- 提示上游新增、但本目录还没有软链接的顶层文件，以及上游删除后留下的断链；
- 通过 D-Bus 让 Fcitx5 重新加载 Rime，并检查词库是否真的重新编译；确认不了时会提示你在
  Rime 菜单里手动选择「重新部署」。

不要删除本目录的 `default.yaml` 软链接。

## 新机器

```bash
git submodule update --init -- vendor/rime-frost
```

这会检出主仓库记录的版本，通常处于 detached HEAD。准备手动追踪上游时：

```bash
cd vendor/rime-frost
git switch master
git pull --ff-only
```

若本地没有 `master` 分支，使用 `git switch --track origin/master`。
`setup.sh` 会初始化缺失的子模块，但不会自动升级上游。

## 个人配置

- `default.custom.yaml`：方案列表、F4 等切换键、候选数和开关记忆。
- `rime_frost*.custom.yaml`：保留原来的全拼/双拼行为、长词优先、反查与计算器前缀；辅助码使用上游的
  `table_translator@frost_aux`（单字）和 `lua_filter@*aux_lookup_filter`（词组/整句），触发键仍是 `` ` ``，
  例如 `shishi`b` → 事实。
- `custom_phrase.txt`：个人短语。
- `rime_frost.dict.yaml`：本地词库入口，保留原来的词库选择；导入的词库内容随子模块更新。
- `lua/`：修改过的模块保留为普通文件（计算器、纠错和置顶逻辑）；其余模块链接上游。
- `*.userdb/`、`user.yaml`、`sync/`、`build/`：用户数据和部署产物，不参与子模块更新。

编辑 `.custom.yaml` 和本地普通文件，避免直接编辑上游软链接目标。
上游新增顶层依赖文件时，需要补充相应软链接；已链接的词库目录内新增文件会直接可见。
上游若改变方案接口或重命名文件，应检查补丁和部署日志。

迁移验证环境：2026-09-12，librime `1:1.17.0-5`、fcitx5-rime `5.1.16-1`、
Git `2.55.0`。上游词库采用其新版词条和词频；本地用户词频数据库保持原位。

参考：[Rime 定制指南](https://github.com/rime/home/wiki/CustomizationGuide)、
[ArchWiki Rime](https://wiki.archlinux.org/title/Rime)、
[Git submodule](https://git-scm.com/docs/git-submodule)。
