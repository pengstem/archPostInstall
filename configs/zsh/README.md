# Zsh Modules

This directory is linked to `~/.config/zsh` by `setup.sh`.

- `rc.d/` contains modular config snippets loaded by `~/.zshrc`.
- Files are loaded in lexical order, so numeric prefixes control startup order.
- Keep machine-specific secrets and overrides in `~/.zshrc.local` (not tracked in this repo).
- Keep `~/.zshrc` loader-only: environment variables belong in `20-env.zsh`,
  executable search paths in `30-path.zsh`, and tool startup code in
  `40-tool-init.zsh`.

## Current Load Order
- `00-instant-prompt.zsh`
- `05-user-bin.zsh`
- `08-shell-state.zsh`
- `10-oh-my-zsh.zsh`
- `20-env.zsh`
- `30-path.zsh`
- `40-tool-init.zsh`
- `50-aliases.zsh`
- `60-functions.zsh`
- `85-fortune-cowsay.zsh`
- `90-shell-options.zsh`
- `95-local-overrides.zsh`
- `99-interactive-plugins.zsh`

`08-shell-state.zsh` defines the XDG cache/state directories, history file, and
`ZSH_COMPDUMP` before Oh My Zsh starts. This keeps completion dumps under
`~/.cache/zsh/` instead of recreating `~/.zcompdump-*` in the home directory.

Oh My Zsh normally owns the single `compinit` call; `90-shell-options.zsh` only
provides a fallback when Oh My Zsh is unavailable. Add custom completion
directories to `fpath` before `10-oh-my-zsh.zsh` sources Oh My Zsh because
re-running `compinit` later can replace plugin registrations with stale
dump-file state.

Powerlevel10k is the sole Zsh prompt owner: `00-instant-prompt.zsh` loads its
instant prompt, `10-oh-my-zsh.zsh` selects the theme, and `40-tool-init.zsh`
loads the tracked `~/.p10k.zsh`. Keep other prompt initializers disabled in Zsh.

`99-interactive-plugins.zsh` loads the Pacman-managed autosuggestions and syntax
highlighting scripts after custom widgets and local overrides. Keep syntax
highlighting last, and do not also clone these plugins into Oh My Zsh.

## Startup Benchmark

Measure the bare interpreter, the normal interactive configuration, and the
login-shell path with the same warm 30-run workload:

```sh
hyperfine --warmup 5 --runs 30 \
    'zsh -dfi -c exit' \
    'zsh -i -c exit' \
    'zsh -l -i -c exit'
```

Use the median to compare revisions and the 95th percentile to spot startup
jitter. The login-shell result also includes `/etc/zsh/zprofile` and the
distribution's `/etc/profile.d/*.sh` hooks, so it is not a measurement of this
repository alone.
