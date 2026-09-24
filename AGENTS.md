# Repository Guidelines

## Where Things Live
- `README.md` and `docs/README.md` describe the layout and workflows; `docs/commands.md` lists every command.
- `manifest.tsv` is the only source-to-target mapping. Add, move, or remove a config there, never by editing `setup.sh`.
- `docs/bug-history.md` tracks general (non-DPMS) config issues and fixes; append entries here instead of creating new history files.
- `docs/dpms-past-bugs.md` tracks DPMS pitfalls; update it when changing DPMS scripts/configs/timers.

## Coding Style & Naming Conventions
- Bash scripts use `#!/bin/bash` with `set -euo pipefail`.
- Indent with 4 spaces in shell scripts; use lower_snake_case for functions and UPPER_SNAKE_CASE for constants. `archpostinstall lint --fix` applies the formatting (`shfmt -i 4 -ci`).
- Scripts must not run as root; check `EUID` and use sudo for privileged steps.
- Keep configs under `configs/<tool>/...` mirroring their target paths.
- Use `.desktop` naming for application launchers in `configs/applications/`; resolve home paths with `$HOME` instead of hard-coding them.

## Research & Change Policy
- Before changing any configs or scripts, consult the latest official documentation and at least one reputable community reference for real-world behavior notes.
- If docs or behavior vary by version, call out the exact version and date used to validate the change.

## Testing Guidelines
- No automated test suite. Before committing script changes, run `archpostinstall lint` (bash -n, shellcheck, shfmt, Python syntax).
- `./setup.sh --dry-run` previews installs; `HOME=$(mktemp -d) ./setup.sh --group user --dry-run` exercises a fresh home.
- `archpostinstall doctor` must report no issues after `setup.sh` runs.
- Validate bootstrap-level changes in a VM or fresh install.

## Bug History
- When a bug is fixed or the user asks to record one, add a dated entry to `docs/bug-history.md`.
- For DPMS-related issues, record in `docs/dpms-past-bugs.md` instead.
- Do not create new bug-history files without explicit user approval.

## Commit & Pull Request Guidelines
- History mostly uses Conventional Commit prefixes (`feat:`, `fix:`, `chore:`), with occasional freeform messages. Prefer the prefix style and keep subjects short and imperative.
- Auto-commit: after making changes, stage and commit them without asking; pick the most accurate Conventional Commit prefix and concise subject.
- Prefer small, atomic commits; if changes naturally separate (e.g., code vs docs), split proactively. Avoid staging unrelated local edits unless explicitly requested.
- Formatting-only commits go into `.git-blame-ignore-revs`.
- PRs should include a brief summary, affected scripts/configs, and manual verification steps (for example, "ran ./setup.sh" or "ran archpostinstall doctor").

## Security & Configuration Tips
- Anything root reads or executes must be `sudo-copy`/`sudo-template` in `manifest.tsv`, never a symlink into this user-writable repo. After editing such a file, run `archpostinstall sync-system`.
- The pacman hook runs the root-owned wrapper `/usr/local/bin/archpostinstall-update-pkglist`, which drops to the repo owner via `runuser`; `scripts/update_pkglist.sh` refuses to run as root.
- `configs/baidupcs/pcs_config.json` is ignored; keep secrets there and use `pcs_config.json.example` as a template.
- App-generated files (`configs/rime/user.yaml`, `installation.yaml`, fcitx5 caches) are ignored to avoid churn.
- `setup.sh` backs up replaced targets as `<target>.bak_<epoch>`; `archpostinstall doctor` lists leftovers and `archpostinstall prune-backups` removes them after confirmation.
- If an app replaced a linked file with a regular one, use `archpostinstall adopt` rather than copying by hand.
