#!/usr/bin/env bash
# Shared by Linux and macOS. Windows consumes the same JSON extension manifest.
apply_firefox_policy() {
    local policy_path="$1" manifest="$2" temporary
    temporary="$(mktemp)" || return 1
    if [[ -f "$policy_path" ]]; then
        if ! jq -e 'type == "object"' "$policy_path" >/dev/null; then
            echo "Invalid existing Firefox policy; leaving it unchanged: $policy_path" >&2
            rm -f "$temporary"
            return 1
        fi
        cp "$policy_path" "$temporary"
    else
        printf '{}\n' > "$temporary"
    fi
    local merged
    merged="$(mktemp)" || { rm -f "$temporary"; return 1; }
    if ! jq --slurpfile intent "$manifest" '
        .policies //= {} |
        .policies.ExtensionSettings //= {} |
        reduce $intent[0].extensions[] as $ext (.;
            .policies.ExtensionSettings[$ext.id] = {
                installation_mode: "force_installed", install_url: $ext.install_url
            }) |
        .policies.DisableFirefoxStudies = true |
        .policies.DontCheckDefaultBrowser = false
    ' "$temporary" > "$merged"; then
        rm -f "$temporary" "$merged"
        return 1
    fi
    if [[ -f "$policy_path" ]] && cmp -s "$merged" "$policy_path"; then
        rm -f "$temporary" "$merged"
        return 0
    fi
    sudo mkdir -p "$(dirname "$policy_path")" || return 1
    if [[ -f "$policy_path" ]]; then
        sudo cp -p "$policy_path" "$policy_path.larry-$(date +%Y%m%d-%H%M%S).bak" || return 1
    fi
    sudo install -m 0644 "$merged" "$policy_path"
    local result=$?
    rm -f "$temporary" "$merged"
    return "$result"
}
