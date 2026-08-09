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
