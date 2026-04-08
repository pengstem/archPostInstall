# Core editor and pager settings.
export EDITOR='nvim'
export VISUAL='nvim'
export SUDO_EDITOR='nvim'
export MANPAGER='nvim +Man!'
export MANWIDTH=420

# Keep shell state out of the tracked repo even though ~/.config/zsh is symlinked here.
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
mkdir -p "${XDG_CACHE_HOME}/zsh" "${XDG_STATE_HOME}/zsh"
export HISTFILE="${XDG_STATE_HOME}/zsh/history"

# Tool directories used by later modules.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
export CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/Project/everything-claude-code}"
