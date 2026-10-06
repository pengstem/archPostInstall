# GNOME Shell extensions

## kimpanel@kde.org

Fcitx5's candidate window under GNOME Wayland. `manifest.tsv` links this whole directory to
`~/.local/share/gnome-shell/extensions/kimpanel@kde.org`. It is a locally patched build of
[wengxt/gnome-shell-extension-kimpanel](https://github.com/wengxt/gnome-shell-extension-kimpanel)
from before upstream's `Clutter.Orientation` port; `metadata.json` has no `version`, so GNOME never
replaces it from extensions.gnome.org. Do not overwrite it with a newer upstream build without
re-applying the patches below.

Local changes against upstream:
- `extension.js`: hide the panel indicator (the Fcitx tray icon stays the status UI) and apply the
  vertical/horizontal layout after the lookup table is refreshed.
- `panel.js`: read the cursor rectangle as `rect.width`/`rect.height`.
- `prefs.js`: `getPreferencesWidget()` instead of `fillPreferencesWindow()`.
- `stylesheet.css`: frosted-glass theme, see below.

Settings (`vertical`, `font`) live in dconf and are tracked in `configs/dconf/shell-extensions.ini`.

### Stylesheet and blur-my-shell

blur-my-shell (v74+) blurs every `popup-menu`/`popup-menu-content` actor, which includes this candidate
window, and sets its `border-radius` inline from the `menu-corner-radius` setting. The stylesheet is
built around that:
- The content box radius (20px) must equal blur-my-shell's `popup/menu-corner-radius`; candidate rows use
  the concentric 13px (20 - 1px border - 6px padding).
- blur-my-shell and the Orchis shell theme both style `.popup-menu-item` with `!important`, so the
  candidate rules use `!important` and extra classes to win.
- Rounded corners on the *dynamic* blur need the AUR package `gnome-rounded-blur`; without it the blur
  layer is a plain rectangle behind the rounded box. The library is built against the running Mutter, so
  rebuild it after every GNOME update: `paru -S --rebuild gnome-rounded-blur`. blur-my-shell's
  `rounded-blur-found` key reports whether it was picked up (it is filtered out of the dconf export).

After editing the stylesheet, reload with
`gnome-extensions disable kimpanel@kde.org && gnome-extensions enable kimpanel@kde.org`.
