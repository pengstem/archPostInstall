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
- `10-oh-my-zsh.zsh`
- `20-env.zsh`
- `30-path.zsh`
- `40-tool-init.zsh`
- `50-aliases.zsh`
- `60-functions.zsh`
- `90-shell-options.zsh`
- `99-local-overrides.zsh`

Oh My Zsh normally owns the single `compinit` call; `90-shell-options.zsh` only
provides a fallback when Oh My Zsh is unavailable. Add custom completion
directories to `fpath` before `10-oh-my-zsh.zsh` sources Oh My Zsh because
re-running `compinit` later can replace plugin registrations with stale
dump-file state.
