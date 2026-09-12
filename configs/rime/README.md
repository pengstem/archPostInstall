# Rime / 白霜拼音

`~/.local/share/fcitx5/rime` 链接到本目录。上游由 `../../vendor/rime-frost`
Git 子模块管理，词库目录和方案通过相对软链接直接引用它，不需要更新脚本或复制文件。

## 日常更新

```bash
cd /home/nastem/Project/archPostInstall/vendor/rime-frost
git pull --ff-only
```

随后在 Fcitx5 的 Rime 菜单选择「重新部署」，编译完成后新词库才生效。
`git pull` 本身不会触发重新部署。不要删除本目录的 `default.yaml` 软链接。

如需把更新后的上游版本记录到 dotfiles 仓库：

```bash
cd /home/nastem/Project/archPostInstall
git add vendor/rime-frost
git commit -m "chore(rime): update upstream dictionaries"
```

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
- `rime_frost*.custom.yaml`：保留原来的全拼/双拼行为、辅助码、长词优先、反查与计算器前缀。
- `custom_phrase.txt`：个人短语。
- `rime_frost.dict.yaml`：本地词库入口，保留原来的词库选择；导入的词库内容随子模块更新。
- `lua/`：修改过的模块保留为普通文件（包括辅助码、计算器、纠错和置顶逻辑）；其余模块链接上游。
- `*.userdb/`、`user.yaml`、`sync/`、`build/`：用户数据和部署产物，不参与子模块更新。

编辑 `.custom.yaml` 和本地普通文件，避免直接编辑上游软链接目标。
上游新增顶层依赖文件时，需要补充相应软链接；已链接的词库目录内新增文件会直接可见。
上游若改变方案接口或重命名文件，应检查补丁和部署日志。

迁移验证环境：2026-09-12，librime `1:1.17.0-5`、fcitx5-rime `5.1.16-1`、
Git `2.55.0`。上游词库采用其新版词条和词频；本地用户词频数据库保持原位。

参考：[Rime 定制指南](https://github.com/rime/home/wiki/CustomizationGuide)、
[ArchWiki Rime](https://wiki.archlinux.org/title/Rime)、
[Git submodule](https://git-scm.com/docs/git-submodule)。
