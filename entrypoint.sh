#!/bin/bash
set -e

# --- Configuration Variables ---
# These paths must match the paths used in the Dockerfile and docker-compose.yaml
CLASH_DIR="/opt/clash"
BIN_KERNEL="$CLASH_DIR/bin/mihomo"
BIN_YQ="$CLASH_DIR/bin/yq"
CONFIG_RAW="$CLASH_DIR/config.yaml"
CONFIG_MIXIN="$CLASH_DIR/mixin.yaml"
CONFIG_URL_FILE="$CLASH_DIR/url"
CONFIG_RUNTIME="$CLASH_DIR/runtime.yaml"

# --- Helper Functions ---
log() {
    echo "==> $1"
}

fatal() {
    echo "!! FATAL: $1" >&2
    exit 1
}

is_config_valid() {
    local config_file="$1"
    if [ ! -f "$config_file" ] || [ ! -s "$config_file" ]; then
        return 1
    fi
    "$BIN_KERNEL" -d "$CLASH_DIR" -f "$config_file" -t >/dev/null 2>&1
    return $?
}

# --- Main Execution ---
log "Clash container entrypoint started."

# Step 1: Determine the base configuration
# Check if a valid config.yaml exists.
if ! is_config_valid "$CONFIG_RAW"; then
    log "Local config.yaml is invalid or empty. Checking for subscription URL."
    # If not, try to download from the URL file.
    if [ -s "$CONFIG_URL_FILE" ]; then
        SUB_URL=$(cat "$CONFIG_URL_FILE")
        if [[ "$SUB_URL" == "YOUR_CLASH_SUBSCRIPTION_URL_HERE" || -z "$SUB_URL" ]]; then
            fatal "Subscription URL file contains placeholder or is empty. Please provide a valid URL in the 'url' file."
        fi

        log "Downloading configuration from subscription URL: $SUB_URL"
        # Use curl to download the subscription. Timeout after 30 seconds.
        if ! curl -L --silent --fail --show-error --connect-timeout 15 --max-time 30 -o "$CONFIG_RAW" "$SUB_URL"; then
            fatal "Failed to download configuration from the subscription link. Check the URL and your network."
        fi

        # Validate the downloaded configuration.
        if ! is_config_valid "$CONFIG_RAW"; then
            fatal "The configuration downloaded from the subscription link is invalid."
        fi
        log "Configuration downloaded and validated successfully."
    else
        fatal "config.yaml is invalid and no subscription URL was provided. Please provide a valid config.yaml or a subscription URL in the 'url' file."
    fi
fi

# Step 2: Merge the base config with the mixin config
log "Merging base configuration with mixin..."
if [ -f "$CONFIG_MIXIN" ] && [ -s "$CONFIG_MIXIN" ]; then
    "$BIN_YQ" eval-all '. as $item ireduce ({}; . *+ $item) | (.. | select(tag == "!!seq")) |= unique' \
        "$CONFIG_RAW" "$CONFIG_MIXIN" > "$CONFIG_RUNTIME"
else
    log "Mixin file is empty or does not exist, skipping merge."
    cp "$CONFIG_RAW" "$CONFIG_RUNTIME"
fi

# Step 3: Validate the final merged configuration
log "Validating final merged configuration..."
if ! is_config_valid "$CONFIG_RUNTIME"; then
    echo "!! Final configuration validation failed. Dumping invalid runtime.yaml for debugging:" >&2
    cat "$CONFIG_RUNTIME" >&2
    fatal "The generated runtime.yaml is invalid, please check your mixin.yaml."
fi
log "Final configuration is valid."

# Step 4: Start the main process
log "Starting mihomo..."
exec "$BIN_KERNEL" -d "$CLASH_DIR" -f "$CONFIG_RUNTIME"