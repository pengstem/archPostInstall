# GNOME Shell extensions

## kimpanel-style@nastem.github.com

Own extension that restyles the Fcitx5 candidate window drawn by
[kimpanel@kde.org](https://extensions.gnome.org/extension/261/kimpanel/). kimpanel itself is the
unmodified extensions.gnome.org build, so it updates on its own; this extension depends only on its CSS
class names (`kimpanel-popup-boxpointer`, `kimpanel-popup-content`, `kimpanel-label`,
`kimpanel-candidate-item`) and its `kimpanel` status-area role. `manifest.tsv` links the directory.

- `stylesheet.css`: frosted-glass candidate window. GNOME Shell loads the stylesheet of every enabled
  extension; each selector here carries one more class than kimpanel's own, so the result does not depend
  on load order.
- `extension.js`: hides kimpanel's top-bar indicator (the Fcitx tray icon already shows the state). It
  hides the status-area *container*, because kimpanel calls `show()` on the indicator button whenever
  input method properties change, and re-applies on `extension-state-changed` since kimpanel recreates
  the indicator when it is re-enabled.

Each GNOME major release: add the new version to `shell-version` in `metadata.json`, then log out and back
in (Shell reads extension metadata only at login). No `version` key, so extensions.gnome.org never touches
it. After editing the stylesheet, reload with
`gnome-extensions disable kimpanel-style@nastem.github.com && gnome-extensions enable kimpanel-style@nastem.github.com`.

Settings of kimpanel itself (`vertical`, `font`) live in dconf and are tracked in
`configs/dconf/shell-extensions.ini`.

### Stylesheet and blur-my-shell

blur-my-shell (v74+) blurs every `popup-menu`/`popup-menu-content` actor, which includes the candidate
window, and sets its `border-radius` inline from the `menu-corner-radius` setting. The stylesheet is
built around that:
- The content box radius (20px) must equal blur-my-shell's `popup/menu-corner-radius`; candidate rows use
  the concentric 13px (20 - 1px border - 6px padding).
- The width follows the content: `min-width: 0` on the boxpointer and content box overrides the shell
  theme's `.popup-menu { min-width: 10em }` (the boxpointer carries `popup-menu`).
- blur-my-shell and the Orchis shell theme both style `.popup-menu-item` with `!important`, so the
  candidate rules use `!important` and extra classes to win.
- Rounded corners on the *dynamic* blur need the AUR package `gnome-rounded-blur`; without it the blur
  layer is a plain rectangle behind the rounded box. The library links against Mutter's versioned
  libraries, so it breaks on every GNOME major release until rebuilt (51.x minor updates keep the
  library names). blur-my-shell's `rounded-blur-found` key reports whether it was picked up (it is
  filtered out of the dconf export).
