# Bug History

This file tracks notable configuration issues, their root causes, and the fixes applied.

## 2026-02-05
- Alacritty (GNOME Wayland): background became opaque after setting `startup_mode = "Fullscreen"`.
  Fix: change `startup_mode` to `Maximized` (or `Windowed`) in `configs/alacritty/alacritty.toml`.
- Zellij: F7 keybind failed because `bunx` was missing.
  Fix: prefer `bunx` if available, otherwise fall back to `npx` in `configs/zellij/config.kdl`.

## 2026-03-19
- Kitty watermark: the top-right signature looked diagonally tilted and sat slightly too high/left.
  Fix: remove the baked-in SVG rotation, shift the artwork down/right within the canvas, and regenerate `configs/kitty/nastem-signature.png` from the updated source.

## 2026-03-25
- Yazi `g n`: opening GNOME Files from the manager could hand Nautilus a malformed doubled path such as `"/path"/"/path"`.
  Fix: replace the inline nested `shell` snippet with a dedicated launcher script at `scripts/launchers/yazi-open-nautilus.sh`, and wire it through `configs/yazi/keymap.toml` and `setup.sh`.

## 2026-04-08
- Hyde install: it injected `~/.zshenv` and extra dotfiles into the repo-backed `configs/zsh/`, which diverted Zsh away from the repo's modular startup and left the workspace dirty with generated cache files.
  Fix: remove the Hyde-generated Zsh files, move the home-level Hyde leftovers into `~/.config/cfg_backups/*_codex_hyde_cleanup/`, and redirect Zsh history / compdump output to `~/.local/state/zsh/` and `~/.cache/zsh/`.

## 2026-06-08
- GNOME backup pruning: `backup_themes_extensions.sh` used an unquoted glob array and `ls -t` to detect/prune archives, which was fragile and noisy under ShellCheck.
  Fix: use `find` for existence checks and compare mtimes with `stat` before pruning older archives.

## 2026-08-09
- Codex CLI Zsh completion: Oh My Zsh registered `codex` completion, but later `compinit -C` calls in `90-shell-options.zsh` and the Grok installer block reloaded the stale `~/.zcompdump` and removed the `codex -> _codex` mapping.
  Fix: let Oh My Zsh own completion initialization, move the Grok completion directory into `fpath` before Oh My Zsh loads, and remove the two later `compinit` calls. Validated on 2026-08-09 with Codex CLI 0.147.0, Zsh 5.9.2, and Oh My Zsh commit `99aaf58d`.
- Zsh modular loader: installer fragments accumulated after the `rc.d` loader, sourcing Bun completion three times and Opam initialization twice while also duplicating PATH entries.
  Fix: restore `configs/zshrc` to a loader-only file, keep the existing single Bun/Opam initialization in `40-tool-init.zsh`, and move the Grok and LoongArch toolchain paths into `30-path.zsh`. Validated on 2026-08-09 with Zsh 5.9.2.
- Zsh prompt ownership: Powerlevel10k and Starship were both initialized, adding competing `precmd` and `preexec` hooks even though only Powerlevel10k had a tracked configuration.
  Fix: keep Powerlevel10k as the sole Zsh prompt and stop running `starship init zsh`; retain the Starship package for optional use in other shells. Validated on 2026-08-09 with Powerlevel10k 1.20.17 and Starship 1.26.0.
- Zsh startup performance: `40-tool-init.zsh` ran `thefuck --alias` eagerly, launching its Python application in every interactive shell even when command correction was never used. A direct module profile attributed about 137.8 ms to that call.
  Fix: install a lightweight placeholder and generate TheFuck's upstream Zsh function only on the first `fuck` invocation in each shell. In matched Hyperfine 1.20.0 benchmarks (5 warmups, 30 runs), normal interactive startup median fell from 297.8 ms to 162.3 ms (45.5% less), while the 95th percentile fell from 302.2 ms to 165.1 ms. Login-shell median fell from 407.0 ms to 273.7 ms; its remaining extra cost is dominated by the system-owned VapourSynth 77-2 profile hook, not this repository. Validated on 2026-08-09 with Zsh 5.9.2 and TheFuck 3.32-13.
- Zsh plugin ownership and dead integrations: autosuggestions and syntax highlighting were installed both by Pacman and as Oh My Zsh Git clones; the `archlinux` plugin exposed the unsafe standalone `pacman -Sy` alias; an upstream `sudo` widget was overwritten by a second local implementation; and unused Starship, Opam, TheFuck, NVM, Qwen, and web/Git helper integrations remained configured.
  Fix: use the Pacman-managed autosuggestions 0.7.1 and syntax-highlighting 0.8.0 scripts in their documented final load order, retain only the Codex/fzf/fzf-tab/sudo Oh My Zsh plugins, remove the duplicate clones and dead integrations, and remove Starship 1.26.0, Opam 2.5.2, and TheFuck 3.32-13 from the machine and package list. In matched Hyperfine 1.20.0 benchmarks (5 warmups, 30 runs), normal interactive startup median fell from 162.3 ms to 147.9 ms (8.9% less), with the 95th percentile falling from 165.1 ms to 150.7 ms. The cumulative median reduction from the original 297.8 ms baseline is 50.3%. Validated on 2026-08-09 with Zsh 5.9.2, following current ArchWiki and upstream plugin load-order guidance checked the same day.
- Git history secrets: old `configs/zshrc` revisions contained live-looking values for `ANTHROPIC_AUTH_TOKEN`, `DEEPSEEK_API_KEY`, and `BRAVE_API_KEY`, so making the repository public would expose them even though the current tree was clean.
  Fix: replace all three values throughout every reachable commit with `[REDACTED]` using `git-filter-repo`, keep machine-local secrets in the already ignored `~/.zshrc.local`, and verify zero reachable occurrences while preserving the current source tree. Validated on 2026-08-09 with Git 2.55.0 and git-filter-repo 2.47.0, following GitHub's sensitive-data removal guidance as checked on 2026-08-09.
- Zsh cache ordering and home portability: XDG state variables were loaded after Oh My Zsh, so its `compinit` still wrote `~/.zcompdump-trinity-5.9.2`; the kitty-scrollback widget also embedded `/home/nastem` in its editor path.
  Fix: load XDG cache/state variables, `HISTFILE`, and `ZSH_COMPDUMP` from `08-shell-state.zsh` before Oh My Zsh, and derive the kitty-scrollback path from `$HOME`. After generating the new cache, move the two old home-level dump files to Trash. In matched Hyperfine 1.20.0 benchmarks (5 warmups, 30 runs), normal interactive startup had a 147.0 ms median and 150.3 ms 95th percentile, versus 147.9 ms and 150.7 ms before the change; login-shell median was 261.4 ms, versus 262.2 ms before. Validated on 2026-08-09 with Zsh 5.9.2 and Oh My Zsh commit `99aaf58d`, following the Zsh 5.9 completion dump documentation and current ArchWiki Zsh guidance checked the same day.
- PDF default application: no user-level `application/pdf` default was persisted, GNOME's Papers default was unavailable, and the user-local Chrome desktop entry became the fallback.
  Fix: set Zathura's MuPDF desktop entry as the PDF default in tracked `configs/mimeapps.list`, preserve the existing user associations, and link the file through `setup.sh`. Validated on 2026-08-09 with xdg-utils 1.2.1-2 and Zathura 2026.07.18-1, following the freedesktop.org MIME Applications 1.0.1 specification and current ArchWiki guidance checked the same day.

## 2026-08-13
- Plymouth theme packaging: symlinking `/usr/share/plymouth/themes/connect` to the repository caused mkinitcpio's `plymouth` hook to archive the resolved `/home/.../configs/plymouth/themes/connect` path, so the theme was present in the initramfs but unavailable at its configured `/usr/share/...` path.
  Fix: deploy the theme directory and `plymouthd.conf` as regular root-owned files with `cp --reflink=auto`, while retaining symlinks for the mkinitcpio, cmdline, and Zen preset inputs that are consumed only at build time. The first failed build was restored from its recorded Zen UKI backup before retrying.
- Boot splash rollback: the installer's `die` helper called `exit`, bypassing the inherited `ERR` trap and therefore skipping the promised automatic rollback after a post-build verification failure.
  Fix: return a failing status from `die` so `set -E` reaches the rollback trap. Validated with a trap probe and a successful second `linux-zen` build whose extracted UKI contained Connect, Plymouth, all four NVIDIA modules, and no `nouveau`; the LTS UKI hash remained unchanged.

## 2026-08-24
- GNOME screensaver shortcut: `Super+F11` was registered and `gsd-media-keys` launched the configured command, but the launcher failed with `required command not found: tte`. The current TTE runtime was installed by uv at `~/.local/bin/tte`, while the GNOME/systemd session `PATH` omitted `~/.local/bin`.
  Fix: resolve `tte` from `PATH`, `UV_TOOL_BIN_DIR`, `XDG_BIN_HOME`, or uv's default XDG user executable directory before launching it, and delay the global activity watch for two seconds so the initiating shortcut's key release cannot dismiss the window. Validated with the same reduced `PATH` exported by the GNOME user session, an actual full-screen start, idempotent PID tracking, and a clean stop. Checked against uv's executable-directory documentation and Arch community reports about user-systemd/desktop launchers omitting `~/.local/bin` on 2026-08-24.
