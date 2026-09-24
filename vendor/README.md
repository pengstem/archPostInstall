# vendor/

Third-party code pinned by this repository. Do not edit it here: local
settings live in `configs/`, and everything below is replaced on update.

| Path | Upstream | Kind | Linked from |
| --- | --- | --- | --- |
| `rime-frost/` | [gaboolic/rime-frost](https://github.com/gaboolic/rime-frost) | git submodule | `configs/rime/*` (per-file symlinks) |
| `thumbfast/` | [po5/thumbfast](https://github.com/po5/thumbfast) | git submodule | `configs/mpv/scripts/thumbfast.lua` |
| `uosc/` | [tomasklaen/uosc](https://github.com/tomasklaen/uosc) releases | release snapshot | `configs/mpv/scripts/uosc`, `configs/mpv/fonts` |

yazi plugins and flavors are not kept here: yazi's own package manager pins
them by revision and content hash in `configs/yazi/package.toml`, `setup.sh`
runs `ya pkg install` for missing ones, and `update-vendor yazi` upgrades them.

uosc is a snapshot of the release `uosc.zip` rather than a submodule because
its `ziggy` helper binary only exists in releases (the repository has the Go
source). Only `ziggy-linux` is kept.

Check and update everything with:

```bash
archpostinstall update-vendor --check   # report only
archpostinstall update-vendor           # update, stage, redeploy Rime, smoke-test mpv
```

`setup.sh` checks out the recorded submodule revisions on a fresh clone.
