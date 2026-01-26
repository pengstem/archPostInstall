# OBS Studio (configs)

This repo tracks **OBS profiles + scene collections** (not the full `~/.config/obs-studio/` folder) to avoid syncing logs and other runtime files.

## What this config does

- **Recording format:** MKV (container; crash-safe)
- **Recording encoder:** NVIDIA NVENC **AV1** (CQP 23, preset p6, multipass qres)
- **Mic filters:** RNNoise noise suppression + limiter (-1 dB)
- **Recording path:** `/home/nastem/Videos`

## Notes

- MKV itself does **not** make files smaller; the **codec + rate control** does.
- If you run into editing/compat issues with AV1, switch the recording encoder to **NVENC HEVC/H.264** in OBS.
