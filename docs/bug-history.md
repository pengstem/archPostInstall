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
- Git history secrets: old `configs/zshrc` revisions contained live-looking values for `ANTHROPIC_AUTH_TOKEN`, `DEEPSEEK_API_KEY`, and `BRAVE_API_KEY`, so making the repository public would expose them even though the current tree was clean.
  Fix: replace all three values throughout every reachable commit with `[REDACTED]` using `git-filter-repo`, keep machine-local secrets in the already ignored `~/.zshrc.local`, and verify zero reachable occurrences while preserving the current source tree. Validated on 2026-08-09 with Git 2.55.0 and git-filter-repo 2.47.0, following GitHub's sensitive-data removal guidance as checked on 2026-08-09.
