# Yazi wrapper: enter yazi and cd to its last working directory on exit.
y() {
    local tmp cwd
    tmp="$(mktemp -t 'yazi-cwd.XXXXXX')"
    yazi "$@" --cwd-file="$tmp"

    if [[ -r "$tmp" ]]; then
        cwd="$(<"$tmp")"
        if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
            builtin cd -- "$cwd"
        fi
    fi

    rm -f -- "$tmp"
}

shouldi() {
    local todo sohash lastchar index so

    if (( $# == 0 )); then
        echo 'What are you up to bad boy?'
        return 88
    fi

    todo="$*"
    sohash="$(printf '%s' "$todo" | sha256sum | awk '{print $1}')"
    lastchar="${sohash: -1}"
    index=$((16#$lastchar))
    so="${sohash: -$index:1}"

    if [[ "$so" =~ [13579bdf] ]]; then
        echo " Why don't we just fuck it up?"
        return 0
    fi

    echo ' Forget about it, we will make it up~'
}

# Interactive Qwen 3.5 model launcher via Ollama.
# Uses fzf in menu mode with vim-style navigation; defaults to no-thinking mode.
qwen() {
    if ! command -v ollama &>/dev/null; then
        echo 'ollama is not installed.' >&2
        return 1
    fi
    if ! command -v fzf &>/dev/null; then
        echo 'fzf is not installed.' >&2
        return 1
    fi

    local -A model_info=(
        ['0.8B  ~1.0 GB   Ultra-light']='qwen3.5:0.8b'
        ['2B    ~2.7 GB   Light']='qwen3.5:2b'
        ['4B    ~3.4 GB   Balanced']='qwen3.5:4b'
        ['9B    ~6.6 GB   Full']='qwen3.5:9b'
    )

    local display_order=(
        '0.8B  ~1.0 GB   Ultra-light'
        '2B    ~2.7 GB   Light'
        '4B    ~3.4 GB   Balanced'
        '9B    ~6.6 GB   Full'
    )

    local selection model
    selection=$(printf '%s\n' "${display_order[@]}" | fzf \
        --header '  Qwen 3.5 - Select Model Size (j/k navigate, Enter or l select)' \
        --no-input \
        --pointer '>' \
        --border rounded \
        --border-label ' qwen3.5 ' \
        --border-label-pos center \
        --height 40% \
        --layout reverse \
        --cycle \
        --no-sort \
        --no-info \
        --bind 'j:down,k:up,l:accept,q:abort' \
        --color 'border:#7aa2f7,label:#bb9af7,header:#e0af68' \
        --color 'pointer:#f7768e,prompt:#7aa2f7,fg+:#c0caf5,bg+:#33467c' \
    ) || return 0

    model="${model_info[$selection]}"
    if [[ -z "$model" ]]; then
        echo 'unknown qwen model selection.' >&2
        return 1
    fi

    echo "Starting ${model} (no-think, /set think to enable)..."
    ollama run --think=false "$model"
}
