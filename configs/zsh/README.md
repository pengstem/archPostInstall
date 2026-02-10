# Zsh Modules

This directory is linked to `~/.config/zsh` by `setup.sh`.

- `rc.d/` contains modular config snippets loaded by `~/.zshrc`.
- Files are loaded in lexical order, so numeric prefixes control startup order.
- Keep machine-specific secrets and overrides in `~/.zshrc.local` (not tracked in this repo).

## Current Load Order
- `00-instant-prompt.zsh`
- `10-oh-my-zsh.zsh`
- `20-env.zsh`
- `30-path.zsh`
- `40-tool-init.zsh`
- `50-aliases.zsh`
- `60-functions.zsh`
- `90-shell-options.zsh`
- `99-local-overrides.zsh`
