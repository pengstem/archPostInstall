# Connect Plymouth theme

The theme files and animation frames in this directory come from
[`adi1090x/plymouth-themes`](https://github.com/adi1090x/plymouth-themes),
`pack_1/connect`, at commit
`5d8817458d764bff4ff9daae94cf1bbaabf16ede`.

- Upstream author: Aditya Shakya (`@adi1090x`)
- License: GPL-3.0; see `LICENSE`
- Imported: 2026-08-13
- Local addition: `connect.bmp` is a 32-bit Windows BMP converted from the
  unchanged upstream `progress-0.png`. It is embedded as the Zen UKI splash so
  systemd-stub and Plymouth display the same centered first frame.

The upstream `connect.script`, `connect.plymouth`, and `progress-*.png` files
are otherwise unmodified.
