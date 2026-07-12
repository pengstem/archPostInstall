# 重装系统后的恢复清单

审计日期：2026-07-12（Asia/Singapore）

本文档记录重装系统后的审计结果，以及仍需要在真实 GNOME 会话中执行的
操作。它是恢复清单，不属于项目的历史 Bug 记录。

## 已检查的内容

- 主机运行 Arch Linux、GNOME 50.3、pacman 7.1.0.r9、paru 2.1.0 和 Bash
  5.3.15。
- 主要用户目录链接已经指向此仓库，包括 Zsh、Kitty、Neovim、Fcitx5、Rime、
  桌面启动器、辅助脚本和三个 user systemd 单元文件。
- pacman、paru、pacman hook、软件包列表更新器、DPMS 和 TLP 配置的系统链接
  也已经指向此仓库。
- Fcitx5/Rime、终端、媒体播放器、文档阅读器、邮件和 OBS 配置目录都存在，
  并且已经链接到用户目录。
- 仓库中的 Bash 脚本均通过 `bash -n` 语法检查。当前环境没有安装
  ShellCheck，因此未进行 ShellCheck 检查。
- `configs/baidupcs/pcs_config.json` 在本地存在且被 Git 忽略。没有读取其内容，
  只将权限收紧为 `0600`。
- 已修复 `.gitmodules`，三个已被 Git 跟踪的 tmux gitlink 现在都可以从新克隆
  的仓库初始化。
- 已修复 `configs/applications/ratty.desktop`，改用有效的绝对配置路径；`%h`
  不是 freedesktop 桌面条目支持的字段代码。
- 所有已跟踪的桌面启动器都通过 `desktop-file-validate` 检查。Yazi 只报告了
  已存在的分类提示。`systemd-analyze verify` 无法返回可靠状态，因为当前
  沙箱拒绝 systemd 用户 socket 的凭据操作。

## 为什么无法在这里完成剩余配置

当前执行环境禁止提权。检查时得到的确切错误是：

~~~
sudo: /etc/sudo.conf is owned by uid 65534, should be 0
sudo: The "no new privileges" flag is set, which prevents sudo from running as root.
~~~

因此我没有在此环境中运行 `setup.sh`、安装软件包、写入
`/etc/sudoers.d` 或启用系统服务。这些操作需要真实安装系统和正常的用户会话。
此外，当前环境无法访问用户 D-Bus，所以无法查询 `systemctl --user` 的状态。

## 在真实系统中执行

请使用普通用户，在仓库根目录执行：

~~~
cd /home/nastem/Project/archPostInstall
sudo -v
./setup.sh
sudo visudo -cf /etc/sudoers.d/archpostinstall-tlp
~~~

对于已经正确建立的链接，`setup.sh` 是幂等的。它会安装 TLP sudoers 文件并
刷新系统链接，但不会创建下面提到的缺失 Nowledge Mem 启动脚本。

然后在已经登录的 GNOME 图形会话中执行：

~~~
mkdir -p ~/.local/share/gnome-shell/extensions ~/.themes ~/.local/share/icons
systemctl --user daemon-reload
systemctl --user enable --now archpostinstall-gnome-sync.path
systemctl --user enable --now archpostinstall-dpms-lock-monitor.service
systemctl --user --no-pager status archpostinstall-gnome-sync.path
systemctl --user --no-pager status archpostinstall-dpms-lock-monitor.service
~~~

如果用户 bus 不可用，请先登录 GNOME 图形会话；不要给这些命令加 `sudo`。

## 跟踪配置仍缺少的软件包

当前的 `scripts/pkglist.txt` 是重装后生成的用户软件包快照，我已保留它原样。
但它缺少多个已跟踪配置所需的软件包。旧的未跟踪文件
`scripts/pkglist_1.txt` 不能直接交给 pacman，因为它包含
`unwanted_packages.txt` 中标记为不需要的软件包，还包含字面量通配符
`qemu-*`。

完成正常的系统升级后，可以安装与仓库配置对应的官方仓库软件包：

~~~
sudo pacman -Syu --needed fcitx5 fcitx5-rime fcitx5-configtool fcitx5-gtk fcitx5-qt ghostty mpv tmux zellij zathura zathura-pdf-mupdf obs-studio isync msmtp neomutt bottom wezterm ratty baidupcs-go zed
~~~

上面的软件包名称已于 2026-07-12 根据当前配置的 Arch 仓库元数据确认。
软件包管理器仍可能显示最新的事务计划，请在确认后再接受。不要在没有逐项
确认前，根据 `unwanted_packages.txt` 执行删除软件包的命令。

仓库配置了 `xdg-desktop-portal-termfilechooser`，但审计时配置的软件包数据库中
找不到 `xdg-desktop-portal-termfilechooser` 或旧名称
`xdg-desktop-portal-termfilechooser-hunkyburrito-git`。安装前请先调查当前的
软件包或源码名称：

~~~
pacman -Ss termfilechooser
paru -Ss termfilechooser
~~~

仓库内的 `yazi-wrapper.sh` 已经链接完成；目前未解决的是 portal 后端软件包。

## GNOME 插件恢复

这次审计确认：插件 UUID 清单仍在 `docs/gnome-extensions.md`，但仓库的
`backups/gnome/` 没有任何压缩备份，当前 `~/.local/share/gnome-shell/extensions`
目录也不存在。因此无法直接从仓库解压恢复插件文件，只能重新安装。

最简单的方法是安装 GNOME 的 Extension Manager，然后根据清单搜索并安装插件：

```bash
sudo pacman -Syu --needed extension-manager gnome-shell-extensions
extension-manager
```

清单中的常规插件包括：AppIndicator、Bing Wallpaper、Blur my Shell、Clipboard
Indicator、Dash to Dock、Fuzzy App Search、Just Perfection、Lock Screen、User
Themes、Vitals、Advanced Alt-Tab 和 Hide Top Bar。安装完成后，可以用下面的命令
重新启用已经安装的插件：

```bash
gsettings set org.gnome.shell disable-user-extensions false
while IFS= read -r uuid; do
    [ -z "$uuid" ] || gnome-extensions enable "$uuid" 2>/dev/null || echo "未安装或不兼容：$uuid"
done < /home/nastem/Project/archPostInstall/docs/gnome-extensions.md
```

如果你想直接从 GNOME 官方插件网站安装，可以先安装浏览器连接器：

```bash
sudo pacman -Syu --needed gnome-browser-connector
```

然后打开 [extensions.gnome.org](https://extensions.gnome.org/)，搜索清单中的
插件并打开安装开关。GNOME 50 只应安装声明支持当前 Shell 版本的插件；旧版本
插件不要强行加载。

`course-table@pengstem` 和 `native-screenshot-copy-mode@nastem.github.com` 看起来
是个人或定制插件，仓库中没有它们的源码或压缩包。它们需要从旧系统、备份硬盘或
原始项目重新找回。如果找到 `.shell-extension.zip` 备份，可以这样安装：

```bash
gnome-extensions install --force /path/to/extension.shell-extension.zip
gnome-extensions enable 插件UUID
```

安装完后注销并重新登录 GNOME；如果某个插件无法安装，先在 Extension Manager
或 GNOME 插件网站确认它是否支持 GNOME 50。

### 12 个非自定义插件的官方页面

下面这些页面都对应 `docs/gnome-extensions.md` 中的普通插件 UUID，并且审计时
都能找到支持 GNOME 50 的可用版本：

- `appindicatorsupport@rgcjonas.gmail.com`：
  [AppIndicator and KStatusNotifierItem Support](https://extensions.gnome.org/extension/615/appindicator-support/)
- `BingWallpaper@ineffable-gmail.com`：
  [Bing Wallpaper](https://extensions.gnome.org/extension/1262/bing-wallpaper-changer/)
- `blur-my-shell@aunetx`：
  [Blur my Shell](https://extensions.gnome.org/extension/3193/blur-my-shell/)
- `clipboard-indicator@tudmotu.com`：
  [Clipboard Indicator](https://extensions.gnome.org/extension/779/clipboard-indicator/)
- `dash-to-dock@micxgx.gmail.com`：
  [Dash to Dock](https://extensions.gnome.org/extension/307/dash-to-dock/)
- `gnome-fuzzy-app-search@gnome-shell-extensions.Czarlie.gitlab.com`：
  [GNOME Fuzzy App Search](https://extensions.gnome.org/extension/3956/gnome-fuzzy-app-search/)
- `just-perfection-desktop@just-perfection`：
  [Just Perfection](https://extensions.gnome.org/extension/3843/just-perfection/)
- `lockscreen-extension@pratap.fastmail.fm`：
  [Lockscreen Extension](https://extensions.gnome.org/extension/7472/lockscreen-extension/)
- `user-theme@gnome-shell-extensions.gcampax.github.com`：
  [User Themes](https://extensions.gnome.org/extension/19/user-themes/)
- `Vitals@CoreCoding.com`：
  [Vitals](https://extensions.gnome.org/extension/1460/vitals/)
- `advanced-alt-tab@G-dH.github.com`：
  [AATWS (Advanced Alt-Tab Window Switcher)](https://extensions.gnome.org/extension/4412/advanced-alttab-window-switcher/)
- `hidetopbar@mathieu.bidon.ca`：
  [Hide Top Bar](https://extensions.gnome.org/extension/545/hide-top-bar/)

## TLP 与 power-profiles-daemon：需要你选择

当前系统安装了 `power-profiles-daemon`，而仓库中也包含 TLP 覆盖配置和 TLP
sudoers 策略。DPMS 脚本已经不再切换电源配置，因此 DPMS 本身不需要 TLP。
TLP 文档警告，TLP 和 `power-profiles-daemon` 会修改相互重叠的设置。

你可以保留当前 GNOME 电源配置并跳过 TLP，或者明确选择使用 TLP 并按照其冲突
处理方式配置。只有在确定使用 TLP 时，才执行类似下面的命令，并先检查事务计划：

~~~
sudo pacman -Syu --needed tlp tlp-rdw
sudo systemctl disable --now power-profiles-daemon.service
sudo systemctl enable --now tlp.service
~~~

不要让两个电源管理器同时运行。这里没有自动替你做这个选择，因为它会改变
系统的电源管理策略。

## 需要个人决定或仓库外文件的项目

### Nowledge Mem

当前工作树中，已跟踪的 `scripts/launchers/nowledge-mem-desktop.sh` 被删除了，
但桌面启动器和 `setup.sh` 仍然引用它。我没有擅自恢复可能是用户主动删除的文件。
如果你仍然需要 Nowledge Mem，请先检查旧文件，再有意恢复：

~~~
git show HEAD:scripts/launchers/nowledge-mem-desktop.sh
git restore --source=HEAD -- scripts/launchers/nowledge-mem-desktop.sh
chmod +x scripts/launchers/nowledge-mem-desktop.sh
~~~

预期的 AppImage `/home/nastem/Applications/nowledge-mem.AppImage` 也不存在，
所以恢复应用程序之前，桌面启动器无法工作。`QQ.AppImage` 和
`WeChat.AppImage` 已存在且可执行，但配置中的用户图标文件不存在；请恢复图标，
或接受通用图标。

OBS 配置的录制目录是 `/home/nastem/Videos/obs`。如果目录不存在，请创建：

~~~
mkdir -p ~/Videos/obs
~~~

### 已存在的工作树修改

下面这些修改在本次恢复中没有回滚，也没有加入提交：

- 大多数已跟踪文件存在 `100644 -> 100755` 权限模式变化。
- `scripts/pkglist.txt` 被缩减为当前安装系统的软件包快照。
- `configs/btop/btop.conf`、`configs/nvim/lazy-lock.json` 和 `configs/zshrc`
  存在实际内容变化。
- 三个 backup 目录中的 `.gitkeep` 文件被删除。
- 嵌套的 tmux 子模块存在本地修改。
- `.claude/`、`scripts/pkglist_1.txt` 和 `unwanted_packages.txt` 是未跟踪文件。

这些修改可能是重装系统时有意保留的内容，因此没有触碰。需要时，备份脚本会
自动重新创建空的备份目录。对于新克隆的仓库，可以用下面的命令初始化已经
修复的子模块配置：

~~~
git submodule sync --recursive
git submodule update --init --recursive
~~~

在当前仓库执行前，请先确认已经保留嵌套子模块中的本地修改。

## SSH 远程连接检查

本次审计确认 `openssh 10.4p1-2` 已安装，`sshd` 程序存在，且
`~/.ssh/authorized_keys` 文件存在并位于权限为 `0700` 的 `~/.ssh` 目录中。
但是当前执行环境隔离了网络命名空间，并且无法访问 systemd，因此无法在这里
确认 `sshd` 是否已启动、是否监听端口、局域网 IP 是什么，以及防火墙是否放行。

请在真实系统中执行：

```bash
sudo sshd -t
sudo systemctl status sshd.service
sudo systemctl enable --now sshd.service
sudo ss -lntp | grep -E '(:22|sshd)' || true
ip -br address
```

如果看到 `0.0.0.0:22` 或 `[::]:22`，说明 SSH 正在监听所有网络接口；如果只看到
`127.0.0.1:22`，其他机器不能直接连接。局域网内的另一台机器可以测试：

```bash
ssh nastem@你的局域网IP
```

如果连接失败，再检查防火墙：

```bash
sudo nft list ruleset
sudo ufw status verbose
```

不要为了临时测试直接把 SSH 端口暴露到互联网。跨互联网连接优先使用 Tailscale
或 WireGuard；如果确实要做端口转发，应使用 SSH 密钥登录、关闭密码登录，并限制
允许登录的用户和来源地址。

## 本次审计使用的参考资料

- [ArchWiki：systemd](https://wiki.archlinux.org/title/Systemd) —— 用户单元和
  `enable --now` 的行为。
- [ArchWiki：Fcitx5](https://wiki.archlinux.org/title/Fcitx5) —— 软件包拆分、
  Rime/GTK/Qt 集成及 Wayland 注意事项。
- [ArchWiki：软件包管理 FAQ](https://wiki.archlinux.org/index.php/Package_Management_FAQs)
  —— 系统升级和恢复软件包列表的建议。
- [TLP：power-profiles-daemon](https://linrunner.de/tlp/faq/ppd.html) —— TLP
  与 `power-profiles-daemon` 不应同时运行的原因。
- [GNOME 系统管理指南：Shell 插件](https://help.gnome.org/system-admin-guide/extensions.html)
  —— 用户插件目录和 UUID 规则。
- [GNOME Shell Extensions](https://extensions.gnome.org/about/) —— 官方插件网站
  和浏览器安装方式。
- [freedesktop.org Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry/desktop-entry-spec-latest.html)
  —— `Exec`、`TryExec` 和图标路径行为。
