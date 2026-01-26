#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

DEFAULT_CONFIG_PATH="$HOME/.config/archpostinstall/obs-autoedit.conf"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/archpostinstall/obs-autoedit"

usage() {
    cat <<'EOF'
Usage:
  archpostinstall obs-autoedit [--scan] [--dry-run] [--force] [file.mkv]

Modes:
  <file.mkv>  Process a single recording
  --scan      Scan OBS watch directory and process unprocessed recordings

Options:
  --dry-run   Only print the keep/cut plan, don't write output
  --force     Re-process even if the file was already processed
  -h, --help  Show this help

Config:
  ~/.config/archpostinstall/obs-autoedit.conf
EOF
}

log() {
    echo "[obs-autoedit] $*"
}

die() {
    echo "[obs-autoedit] ERROR: $*" >&2
    exit 1
}

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
}

load_config() {
    if [[ -f "$DEFAULT_CONFIG_PATH" ]]; then
        # shellcheck source=/dev/null
        source "$DEFAULT_CONFIG_PATH"
    fi

    OBS_AUTOEDIT_ENABLED="${OBS_AUTOEDIT_ENABLED:-1}"
    OBS_AUTOEDIT_WATCH_DIR="${OBS_AUTOEDIT_WATCH_DIR:-$HOME/Videos/obs}"
    OBS_AUTOEDIT_OUTPUT_DIR="${OBS_AUTOEDIT_OUTPUT_DIR:-$HOME/Videos/obs/edited}"
    OBS_AUTOEDIT_OUTPUT_SUFFIX="${OBS_AUTOEDIT_OUTPUT_SUFFIX:--autoedit}"
    OBS_AUTOEDIT_STABLE_SECONDS="${OBS_AUTOEDIT_STABLE_SECONDS:-3}"

    OBS_AUTOEDIT_SILENCE_DB="${OBS_AUTOEDIT_SILENCE_DB:--45dB}"
    OBS_AUTOEDIT_SILENCE_DURATION_SEC="${OBS_AUTOEDIT_SILENCE_DURATION_SEC:-1.5}"
    OBS_AUTOEDIT_FREEZE_NOISE="${OBS_AUTOEDIT_FREEZE_NOISE:-0.002}"
    OBS_AUTOEDIT_FREEZE_DURATION_SEC="${OBS_AUTOEDIT_FREEZE_DURATION_SEC:-1.5}"

    OBS_AUTOEDIT_PAD_SEC="${OBS_AUTOEDIT_PAD_SEC:-0.15}"
    OBS_AUTOEDIT_MIN_KEEP_SEC="${OBS_AUTOEDIT_MIN_KEEP_SEC:-0.25}"

    OBS_AUTOEDIT_ANALYZE_FPS="${OBS_AUTOEDIT_ANALYZE_FPS:-10}"
    OBS_AUTOEDIT_ANALYZE_WIDTH="${OBS_AUTOEDIT_ANALYZE_WIDTH:-640}"

    OBS_AUTOEDIT_VIDEO_CODEC="${OBS_AUTOEDIT_VIDEO_CODEC:-av1_nvenc}"
    OBS_AUTOEDIT_NVENC_PRESET="${OBS_AUTOEDIT_NVENC_PRESET:-p6}"
    OBS_AUTOEDIT_NVENC_TUNE="${OBS_AUTOEDIT_NVENC_TUNE:-hq}"
    OBS_AUTOEDIT_NVENC_RC="${OBS_AUTOEDIT_NVENC_RC:-constqp}"
    OBS_AUTOEDIT_NVENC_QP="${OBS_AUTOEDIT_NVENC_QP:-23}"
    OBS_AUTOEDIT_NVENC_MULTIPASS="${OBS_AUTOEDIT_NVENC_MULTIPASS:-qres}"
    OBS_AUTOEDIT_NVENC_LOOKAHEAD="${OBS_AUTOEDIT_NVENC_LOOKAHEAD:-16}"
    OBS_AUTOEDIT_NVENC_TEMPORAL_AQ="${OBS_AUTOEDIT_NVENC_TEMPORAL_AQ:-1}"
    OBS_AUTOEDIT_KEYINT_SEC="${OBS_AUTOEDIT_KEYINT_SEC:-2}"

    OBS_AUTOEDIT_AUDIO_CODEC="${OBS_AUTOEDIT_AUDIO_CODEC:-libopus}"
    OBS_AUTOEDIT_AUDIO_BITRATE="${OBS_AUTOEDIT_AUDIO_BITRATE:-128k}"
}

wait_for_stable_file() {
    local file="$1"
    local stable_seconds="$2"

    local last_size=""
    local stable_count=0

    while (( stable_count < stable_seconds )); do
        if [[ ! -f "$file" ]]; then
            die "File disappeared: $file"
        fi

        local size
        size="$(stat -c %s "$file" 2>/dev/null || echo "")"
        if [[ -z "$size" ]]; then
            die "Unable to stat file: $file"
        fi

        if [[ "$size" == "$last_size" ]]; then
            stable_count=$((stable_count + 1))
        else
            stable_count=0
            last_size="$size"
        fi

        sleep 1
    done
}

get_duration_sec() {
    local file="$1"
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -n 1
}

get_avg_fps() {
    local file="$1"
    local rate
    rate="$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -n 1)"
    if [[ -z "$rate" ]]; then
        echo ""
        return
    fi

    awk -F/ 'NF==2 && $2!=0 { printf "%.6f", $1/$2; exit } { exit }' <<<"$rate"
}

has_audio_stream() {
    local file="$1"
    local out
    out="$(ffprobe -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 "$file" 2>/dev/null || true)"
    [[ -n "$out" ]]
}

build_analysis_vf() {
    local parts=()

    if [[ "${OBS_AUTOEDIT_ANALYZE_WIDTH}" =~ ^[0-9]+$ ]] && (( OBS_AUTOEDIT_ANALYZE_WIDTH > 0 )); then
        parts+=("scale=${OBS_AUTOEDIT_ANALYZE_WIDTH}:-2:flags=bicubic")
    fi

    if [[ "${OBS_AUTOEDIT_ANALYZE_FPS}" =~ ^[0-9]+$ ]] && (( OBS_AUTOEDIT_ANALYZE_FPS > 0 )); then
        parts+=("fps=${OBS_AUTOEDIT_ANALYZE_FPS}")
    fi

    parts+=("freezedetect=n=${OBS_AUTOEDIT_FREEZE_NOISE}:d=${OBS_AUTOEDIT_FREEZE_DURATION_SEC}")

    local IFS=,
    echo "${parts[*]}"
}

compute_filter_complex() {
    local analysis_log="$1"
    local duration="$2"
    local has_audio="$3"

    python3 - "$analysis_log" "$duration" "$OBS_AUTOEDIT_PAD_SEC" "$OBS_AUTOEDIT_MIN_KEEP_SEC" "$has_audio" <<'PY'
import re
import sys

log_path = sys.argv[1]
duration = float(sys.argv[2])
pad = float(sys.argv[3])
min_keep = float(sys.argv[4])
has_audio = sys.argv[5] == "1"

silence_start_re = re.compile(r"silence_start:\s*([0-9.]+)")
silence_end_re = re.compile(r"silence_end:\s*([0-9.]+)")
freeze_start_re = re.compile(r"freeze_start:\s*([0-9.]+)")
freeze_end_re = re.compile(r"freeze_end:\s*([0-9.]+)")

silences = []
freezes = []

cur_silence = None
cur_freeze = None

with open(log_path, "r", encoding="utf-8", errors="replace") as f:
    for line in f:
        m = silence_start_re.search(line)
        if m:
            cur_silence = float(m.group(1))
            continue
        m = silence_end_re.search(line)
        if m and cur_silence is not None:
            end = float(m.group(1))
            if end > cur_silence:
                silences.append((cur_silence, end))
            cur_silence = None
            continue

        m = freeze_start_re.search(line)
        if m:
            cur_freeze = float(m.group(1))
            continue
        m = freeze_end_re.search(line)
        if m and cur_freeze is not None:
            end = float(m.group(1))
            if end > cur_freeze:
                freezes.append((cur_freeze, end))
            cur_freeze = None
            continue

if cur_silence is not None:
    silences.append((cur_silence, duration))
if cur_freeze is not None:
    freezes.append((cur_freeze, duration))

if not has_audio:
    silences = [(0.0, duration)]

def intersect(a, b):
    start = max(a[0], b[0])
    end = min(a[1], b[1])
    if end <= start:
        return None
    return (start, end)

cuts = []
for s in silences:
    for fr in freezes:
        inter = intersect(s, fr)
        if inter:
            cuts.append(inter)

def clamp(x, lo, hi):
    return max(lo, min(hi, x))

def merge(intervals, gap=0.0):
    if not intervals:
        return []
    intervals = sorted(intervals, key=lambda t: t[0])
    out = [intervals[0]]
    for s, e in intervals[1:]:
        ps, pe = out[-1]
        if s <= pe + gap:
            out[-1] = (ps, max(pe, e))
        else:
            out.append((s, e))
    return out

cuts = [(clamp(s - pad, 0.0, duration), clamp(e + pad, 0.0, duration)) for s, e in cuts]
cuts = [(s, e) for s, e in cuts if e > s]
cuts = merge(cuts, gap=0.05)

keeps = []
cursor = 0.0
for s, e in cuts:
    if s > cursor:
        keeps.append((cursor, s))
    cursor = max(cursor, e)
if cursor < duration:
    keeps.append((cursor, duration))

keeps = [(s, e) for s, e in keeps if (e - s) >= min_keep]

if not keeps:
    sys.exit(2)

v_parts = []
a_parts = []
for i, (s, e) in enumerate(keeps):
    v_parts.append(f"[0:v]trim=start={s:.6f}:end={e:.6f},setpts=PTS-STARTPTS[v{i}]")
    if has_audio:
        a_parts.append(f"[0:a]atrim=start={s:.6f}:end={e:.6f},asetpts=PTS-STARTPTS[a{i}]")

if has_audio:
    concat_inputs = "".join([f"[v{i}][a{i}]" for i in range(len(keeps))])
    concat = f"{concat_inputs}concat=n={len(keeps)}:v=1:a=1[v][a]"
    filters = ";".join(v_parts + a_parts + [concat])
else:
    concat_inputs = "".join([f"[v{i}]" for i in range(len(keeps))])
    concat = f"{concat_inputs}concat=n={len(keeps)}:v=1:a=0[v]"
    filters = ";".join(v_parts + [concat])

print(filters)
PY
}

process_file() {
    local input="$1"
    local dry_run="$2"
    local force="$3"

    if [[ ! -f "$input" ]]; then
        die "File not found: $input"
    fi

    mkdir -p "$CACHE_DIR"
    mkdir -p "$OBS_AUTOEDIT_OUTPUT_DIR"

    local lock_file="$CACHE_DIR/lock"
    exec 9>"$lock_file"
    flock -n 9 || { log "Another instance is running; skipping."; return; }

    local mtime size
    mtime="$(stat -c %Y "$input" 2>/dev/null || echo "")"
    size="$(stat -c %s "$input" 2>/dev/null || echo "")"
    if [[ -z "$mtime" || -z "$size" ]]; then
        die "Unable to stat: $input"
    fi

    local marker="$CACHE_DIR/$(basename "$input").${mtime}-${size}.done"
    if [[ -f "$marker" && "$force" != "1" ]]; then
        log "Already processed: $input"
        return
    fi

    log "Waiting for file to become stable..."
    wait_for_stable_file "$input" "$OBS_AUTOEDIT_STABLE_SECONDS"

    local duration
    duration="$(get_duration_sec "$input")"
    if [[ -z "$duration" ]]; then
        die "Unable to get duration from: $input"
    fi

    local has_audio=0
    if has_audio_stream "$input"; then
        has_audio=1
    fi

    local vf af
    vf="$(build_analysis_vf)"
    af="silencedetect=noise=${OBS_AUTOEDIT_SILENCE_DB}:d=${OBS_AUTOEDIT_SILENCE_DURATION_SEC}"

    local analysis_log
    analysis_log="$(mktemp)"

    log "Analyzing (silence + stillness)..."
    if (( has_audio )); then
        ffmpeg -hide_banner -nostdin -i "$input" -vf "$vf" -af "$af" -f null - 2>"$analysis_log"
    else
        ffmpeg -hide_banner -nostdin -i "$input" -vf "$vf" -an -f null - 2>"$analysis_log"
    fi

    local filter_complex
    if ! filter_complex="$(compute_filter_complex "$analysis_log" "$duration" "$has_audio")"; then
        log "No keep segments after trimming; skipping output for: $input"
        rm -f "$analysis_log"
        printf 'skipped\n' >"$marker"
        return
    fi
    rm -f "$analysis_log"

    log "Filter graph: $filter_complex"

    if [[ "$dry_run" == "1" ]]; then
        return
    fi

    local fps gop
    fps="$(get_avg_fps "$input")"
    gop="$(awk -v fps="${fps:-0}" -v keyint="${OBS_AUTOEDIT_KEYINT_SEC}" 'BEGIN{ if (fps<=0) { print 60; exit } printf "%d", int(fps*keyint+0.5) }')"

    local base_name out_file
    base_name="$(basename "$input")"
    base_name="${base_name%.*}"
    out_file="$OBS_AUTOEDIT_OUTPUT_DIR/${base_name}${OBS_AUTOEDIT_OUTPUT_SUFFIX}.mkv"

    log "Writing: $out_file"

    local ffmpeg_args=()
    ffmpeg_args+=(-hide_banner -nostdin -y -i "$input" -filter_complex "$filter_complex" -map "[v]")
    if (( has_audio )); then
        ffmpeg_args+=(-map "[a]")
    fi

    case "$OBS_AUTOEDIT_VIDEO_CODEC" in
        av1_nvenc)
            ffmpeg_args+=(
                -c:v av1_nvenc
                -preset "$OBS_AUTOEDIT_NVENC_PRESET"
                -tune "$OBS_AUTOEDIT_NVENC_TUNE"
                -rc "$OBS_AUTOEDIT_NVENC_RC"
                -qp "$OBS_AUTOEDIT_NVENC_QP"
                -multipass "$OBS_AUTOEDIT_NVENC_MULTIPASS"
                -rc-lookahead "$OBS_AUTOEDIT_NVENC_LOOKAHEAD"
                -temporal-aq "$OBS_AUTOEDIT_NVENC_TEMPORAL_AQ"
                -g "$gop"
                -pix_fmt yuv420p
            )
            ;;
        *)
            die "Unsupported video codec: $OBS_AUTOEDIT_VIDEO_CODEC"
            ;;
    esac

    if (( has_audio )); then
        ffmpeg_args+=(-c:a "$OBS_AUTOEDIT_AUDIO_CODEC" -b:a "$OBS_AUTOEDIT_AUDIO_BITRATE")
    fi

    ffmpeg "${ffmpeg_args[@]}" "$out_file"

    printf '%s\n' "$out_file" >"$marker"
    log "Done: $out_file"
}

scan_dir() {
    local dry_run="$1"
    local force="$2"

    if [[ ! -d "$OBS_AUTOEDIT_WATCH_DIR" ]]; then
        log "Watch dir does not exist: $OBS_AUTOEDIT_WATCH_DIR"
        return
    fi

    log "Scanning: $OBS_AUTOEDIT_WATCH_DIR"
    find "$OBS_AUTOEDIT_WATCH_DIR" -maxdepth 1 -type f -name "*.mkv" -print0 | while IFS= read -r -d '' f; do
        process_file "$f" "$dry_run" "$force" || true
    done
}

main() {
    require_cmd ffmpeg
    require_cmd ffprobe
    require_cmd python3
    require_cmd flock

    load_config

    if [[ "${OBS_AUTOEDIT_ENABLED}" != "1" ]]; then
        log "Disabled via config (OBS_AUTOEDIT_ENABLED!=1)."
        exit 0
    fi

    local scan=0
    local dry_run=0
    local force=0
    local input=""

    while (( $# > 0 )); do
        case "$1" in
            --scan)
                scan=1
                shift
                ;;
            --dry-run)
                dry_run=1
                shift
                ;;
            --force)
                force=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                input="$1"
                shift
                ;;
        esac
    done

    if (( scan )); then
        scan_dir "$dry_run" "$force"
        return
    fi

    if [[ -z "$input" ]]; then
        usage
        exit 1
    fi

    process_file "$input" "$dry_run" "$force"
}

main "$@"
