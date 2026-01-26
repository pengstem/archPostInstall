# OBS Studio (configs)

This repo tracks **OBS profiles + scene collections** (not the full `~/.config/obs-studio/` folder) to avoid syncing logs and other runtime files.

## What this config does

- **Recording format:** MKV (container; crash-safe)
- **Recording encoder:** NVIDIA NVENC **AV1** (CQP 23, preset p6, multipass qres)
- **Mic filters:** RNNoise noise suppression + limiter (-1 dB)
- **Recording path:** `/home/nastem/Videos/obs`

## Live trimming (auto-pause idle while recording)

OBS cannot delete already-recorded segments from a file *while recording*. The practical way to “cut dead air while recording” is to **auto-pause** and **auto-resume** the recording.

This repo includes an OBS Lua script:

- Source: `configs/obs-studio/scripts/archpostinstall-auto-pause-idle.lua`
- Symlink target: `~/.config/obs-studio/scripts/archpostinstall-auto-pause-idle.lua`
- What it does: when **both** the mic is silent *and* the screen is (almost) still for a while, it pauses recording; it resumes on audio or motion.

Enable it in OBS:

1. Run `./setup.sh` to create the symlink(s).
2. OBS → **Tools** → **Scripts** → “+” → add the script from `~/.config/obs-studio/scripts/`.
3. Set `Audio source name` to match your mic source (e.g. `Mic/Aux`), then tune thresholds.
4. OBS → **Settings** → **Hotkeys** → bind `Toggle Auto-Pause Idle` to quickly enable/disable it.

## Notes

- MKV itself does **not** make files smaller; the **codec + rate control** does.
- If you run into editing/compat issues with AV1, switch the recording encoder to **NVENC HEVC/H.264** in OBS.
