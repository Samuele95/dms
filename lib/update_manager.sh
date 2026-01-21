#!/bin/bash
# ============================================================================
# DMS Update Manager Module
# ============================================================================
# Database and tool update functions for USB kit maintenance
#
# This module handles updating ClamAV databases, YARA rules, and optionally
# tools within a DMS USB kit.
#
# Usage:
#   source lib/update_manager.sh
#   update_usb_kit
# ============================================================================

# ============================================================================
# Update Manager Variables
# ============================================================================

declare -g UPDATE_VERBOSE="${UPDATE_VERBOSE:-false}"
declare -g UPDATE_CLAMAV="${UPDATE_CLAMAV:-true}"
declare -g UPDATE_YARA="${UPDATE_YARA:-true}"
declare -g UPDATE_TOOLS="${UPDATE_TOOLS:-false}"

# URLs for YARA rules (same as main script)
declare -g YARA_QU1CKSC0PE_URL="${YARA_QU1CKSC0PE_URL:-https://github.com/CYB3RMX/Qu1cksc0pe/archive/refs/heads/master.zip}"
declare -g YARA_SIGNATURE_BASE_URL="${YARA_SIGNATURE_BASE_URL:-https://github.com/Neo23x0/signature-base/archive/refs/heads/master.zip}"

# ============================================================================
# Network Connectivity
# ============================================================================

# Check if network is available
# Returns: 0 if network available, 1 otherwise
check_network_connectivity() {
    # Try multiple methods

    # Method 1: ping common DNS servers
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        return 0
    fi

    # Method 2: ping Google DNS
    if ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
        return 0
    fi

    # Method 3: Try DNS resolution
    if host google.com &>/dev/null; then
        return 0
    fi

    # Method 4: Try curl/wget
    if command -v curl &>/dev/null; then
        if curl -s --connect-timeout 3 -o /dev/null http://www.google.com 2>/dev/null; then
            return 0
        fi
    elif command -v wget &>/dev/null; then
        if wget -q --timeout=3 --spider http://www.google.com 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# ============================================================================
# USB Kit Update Functions
# ============================================================================

# Update USB kit databases and optionally tools
# Requires USB_MODE=true and USB_ROOT set
# Returns: 0 on success, 1 on error
update_usb_kit() {
    local force="${1:-false}"

    # Verify USB mode
    if [ "$USB_MODE" != "true" ] || [ -z "$USB_ROOT" ]; then
        echo "Error: Not running from USB kit" >&2
        return 1
    fi

    # Check network connectivity
    if ! check_network_connectivity; then
        echo "Error: No network connectivity available" >&2
        return 1
    fi

    # Check if USB is writable
    if [ "$USB_WRITABLE" != "true" ]; then
        local test_file="$USB_ROOT/.dms_write_test_$$"
        if ! touch "$test_file" 2>/dev/null; then
            echo "Error: USB kit is read-only. Cannot update." >&2
            echo "  Try remounting with write permissions or use a different USB." >&2
            return 1
        fi
        rm -f "$test_file"
    fi

    local updates_performed=0
    local errors=0

    echo "Updating DMS USB Kit..."
    echo "USB Root: $USB_ROOT"
    echo ""

    # Update ClamAV databases
    if [ "$UPDATE_CLAMAV" = "true" ]; then
        echo "Updating ClamAV databases..."
        if update_clamav_databases_on_usb; then
            echo "  ClamAV databases updated successfully"
            ((updates_performed++))
        else
            echo "  Warning: ClamAV database update failed" >&2
            ((errors++))
        fi
    fi

    # Update YARA rules
    if [ "$UPDATE_YARA" = "true" ]; then
        echo "Updating YARA rules..."
        if update_yara_rules_on_usb; then
            echo "  YARA rules updated successfully"
            ((updates_performed++))
        else
            echo "  Warning: YARA rules update failed" >&2
            ((errors++))
        fi
    fi

    # Update manifest
    if [ $updates_performed -gt 0 ]; then
        echo "Updating kit manifest..."
        if [ -f "$KIT_MANIFEST" ]; then
            update_kit_manifest "$KIT_MANIFEST"
        fi
    fi

    echo ""
    echo "Update complete: $updates_performed successful, $errors errors"

    [ $errors -eq 0 ]
}

# ============================================================================
# ClamAV Database Updates
# ============================================================================

# Update ClamAV databases in USB kit
# Returns: 0 on success, 1 on error
update_clamav_databases_on_usb() {
    local db_dir="$USB_ROOT/dms/databases/clamav"

    # Create directory if needed
    mkdir -p "$db_dir" 2>/dev/null || {
        echo "  Error: Cannot create ClamAV database directory" >&2
        return 1
    }

    # Check for freshclam
    local freshclam_cmd=""
    if [ -x "$USB_ROOT/dms/tools/bin/freshclam" ]; then
        freshclam_cmd="$USB_ROOT/dms/tools/bin/freshclam"
    elif command -v freshclam &>/dev/null; then
        freshclam_cmd="freshclam"
    else
        echo "  Error: freshclam not found" >&2
        return 1
    fi

    # Create temporary config for freshclam
    local temp_config=$(mktemp)
    cat > "$temp_config" << EOF
DatabaseDirectory $db_dir
DatabaseMirror database.clamav.net
DNSDatabaseInfo current.cvd.clamav.net
ConnectTimeout 30
ReceiveTimeout 300
EOF

    # Run freshclam
    local result=0
    if [ "$UPDATE_VERBOSE" = "true" ]; then
        "$freshclam_cmd" --config-file="$temp_config" --verbose 2>&1
        result=$?
    else
        "$freshclam_cmd" --config-file="$temp_config" --quiet 2>&1
        result=$?
    fi

    rm -f "$temp_config"

    # Record version info
    if [ $result -eq 0 ]; then
        local version="unknown"
        if command -v sigtool &>/dev/null && [ -f "$db_dir/main.cvd" ]; then
            version=$(sigtool --info "$db_dir/main.cvd" 2>/dev/null | grep "Version:" | awk '{print $2}') || version="unknown"
        fi
        echo "$version" > "$db_dir/version.txt"
        date -u +"%Y-%m-%dT%H:%M:%SZ" > "$db_dir/updated.txt"
    fi

    return $result
}

# ============================================================================
# YARA Rules Updates
# ============================================================================

# Update YARA rules in USB kit
# Returns: 0 on success, 1 on error
update_yara_rules_on_usb() {
    local rules_dir="$USB_ROOT/dms/databases/yara"

    # Create directory if needed
    mkdir -p "$rules_dir" 2>/dev/null || {
        echo "  Error: Cannot create YARA rules directory" >&2
        return 1
    }

    local errors=0
    local temp_dir=$(mktemp -d)

    # Download Qu1cksc0pe rules
    echo "    Downloading Qu1cksc0pe rules..."
    if _download_and_extract_rules "$YARA_QU1CKSC0PE_URL" "$temp_dir/qu1cksc0pe" "Qu1cksc0pe-master"; then
        # Copy YARA rules
        if [ -d "$temp_dir/qu1cksc0pe/Qu1cksc0pe-master/Systems/Multiple/YaraRules_Multiple" ]; then
            cp -r "$temp_dir/qu1cksc0pe/Qu1cksc0pe-master/Systems/Multiple/YaraRules_Multiple"/* "$rules_dir/" 2>/dev/null || true
        fi
        if [ -d "$temp_dir/qu1cksc0pe/Qu1cksc0pe-master/Systems/Windows/YaraRules_Windows" ]; then
            cp -r "$temp_dir/qu1cksc0pe/Qu1cksc0pe-master/Systems/Windows/YaraRules_Windows"/* "$rules_dir/" 2>/dev/null || true
        fi
        echo "$YARA_QU1CKSC0PE_URL" > "$rules_dir/qu1cksc0pe_source.txt"
        date -u +"%Y-%m-%d" > "$rules_dir/qu1cksc0pe_date.txt"
    else
        echo "    Warning: Failed to download Qu1cksc0pe rules" >&2
        ((errors++))
    fi

    # Download Neo23x0 signature-base rules
    echo "    Downloading signature-base rules..."
    if _download_and_extract_rules "$YARA_SIGNATURE_BASE_URL" "$temp_dir/sigbase" "signature-base-master"; then
        # Copy YARA rules
        if [ -d "$temp_dir/sigbase/signature-base-master/yara" ]; then
            cp -r "$temp_dir/sigbase/signature-base-master/yara"/* "$rules_dir/" 2>/dev/null || true
        fi
        echo "$YARA_SIGNATURE_BASE_URL" > "$rules_dir/signature_base_source.txt"
        date -u +"%Y-%m-%d" > "$rules_dir/signature_base_date.txt"
    else
        echo "    Warning: Failed to download signature-base rules" >&2
        ((errors++))
    fi

    # Cleanup
    rm -rf "$temp_dir"

    # Recompile YARA cache if needed
    if [ $errors -lt 2 ]; then
        recompile_yara_cache_on_usb
    fi

    [ $errors -eq 0 ]
}

# Download and extract a rules archive
# Arguments: url, target_dir, expected_inner_dir
_download_and_extract_rules() {
    local url="$1"
    local target_dir="$2"
    local inner_dir="$3"

    mkdir -p "$target_dir"
    local zip_file="$target_dir/rules.zip"

    # Download
    if command -v curl &>/dev/null; then
        curl -sL -o "$zip_file" "$url" || return 1
    elif command -v wget &>/dev/null; then
        wget -q -O "$zip_file" "$url" || return 1
    else
        echo "Error: Neither curl nor wget available" >&2
        return 1
    fi

    # Extract
    if command -v unzip &>/dev/null; then
        unzip -q -o "$zip_file" -d "$target_dir" || return 1
    else
        echo "Error: unzip not available" >&2
        return 1
    fi

    rm -f "$zip_file"
    return 0
}

# Recompile YARA rules cache
recompile_yara_cache_on_usb() {
    local rules_dir="$USB_ROOT/dms/databases/yara"
    local cache_dir="$USB_ROOT/dms/cache"

    # Skip if no yarac
    local yarac_cmd=""
    if [ -x "$USB_ROOT/dms/tools/bin/yarac" ]; then
        yarac_cmd="$USB_ROOT/dms/tools/bin/yarac"
    elif command -v yarac &>/dev/null; then
        yarac_cmd="yarac"
    else
        echo "    Note: yarac not available, skipping cache compilation"
        return 0
    fi

    mkdir -p "$cache_dir" 2>/dev/null

    # Find all .yar and .yara files
    local rule_files=()
    while IFS= read -r -d '' file; do
        rule_files+=("$file")
    done < <(find "$rules_dir" -type f \( -name "*.yar" -o -name "*.yara" \) -print0 2>/dev/null)

    if [ ${#rule_files[@]} -eq 0 ]; then
        echo "    No YARA rules found to compile"
        return 0
    fi

    echo "    Compiling ${#rule_files[@]} YARA rule files..."

    # Compile rules to cache
    local compiled_cache="$cache_dir/compiled_rules.yarc"
    if "$yarac_cmd" "${rule_files[@]}" "$compiled_cache" 2>/dev/null; then
        echo "    YARA cache compiled successfully"
        return 0
    else
        echo "    Warning: Some YARA rules failed to compile" >&2
        return 1
    fi
}

# ============================================================================
# Version Check Functions
# ============================================================================

# Check if ClamAV databases need updating
# Returns: 0 if update needed, 1 if up to date
check_clamav_update_needed() {
    local db_dir="$USB_ROOT/dms/databases/clamav"
    local updated_file="$db_dir/updated.txt"

    # If no timestamp file, update needed
    [ ! -f "$updated_file" ] && return 0

    # Check age (default: update if older than 7 days)
    local max_age_days="${CLAMAV_UPDATE_INTERVAL_DAYS:-7}"
    local updated_ts=$(date -d "$(cat "$updated_file" 2>/dev/null)" +%s 2>/dev/null) || return 0
    local now_ts=$(date +%s)
    local age_days=$(( (now_ts - updated_ts) / 86400 ))

    [ $age_days -ge $max_age_days ]
}

# Check if YARA rules need updating
# Returns: 0 if update needed, 1 if up to date
check_yara_update_needed() {
    local rules_dir="$USB_ROOT/dms/databases/yara"
    local date_file="$rules_dir/qu1cksc0pe_date.txt"

    # If no date file, update needed
    [ ! -f "$date_file" ] && return 0

    # Check age (default: update if older than 14 days)
    local max_age_days="${YARA_UPDATE_INTERVAL_DAYS:-14}"
    local updated_ts=$(date -d "$(cat "$date_file" 2>/dev/null)" +%s 2>/dev/null) || return 0
    local now_ts=$(date +%s)
    local age_days=$(( (now_ts - updated_ts) / 86400 ))

    [ $age_days -ge $max_age_days ]
}

# ============================================================================
# Status and Information
# ============================================================================

# Print update status for USB kit
print_usb_kit_update_status() {
    if [ "$USB_MODE" != "true" ]; then
        echo "Not running from USB kit"
        return 1
    fi

    echo "USB Kit Update Status"
    echo "====================="
    echo ""

    # ClamAV status
    echo "ClamAV Databases:"
    local clam_db="$USB_ROOT/dms/databases/clamav"
    if [ -d "$clam_db" ] && [ -f "$clam_db/main.cvd" ]; then
        echo "  Status:   Installed"
        [ -f "$clam_db/version.txt" ] && echo "  Version:  $(cat "$clam_db/version.txt")"
        [ -f "$clam_db/updated.txt" ] && echo "  Updated:  $(cat "$clam_db/updated.txt")"
        if check_clamav_update_needed; then
            echo "  Action:   Update recommended"
        else
            echo "  Action:   Up to date"
        fi
    else
        echo "  Status:   Not installed"
        echo "  Action:   Update required"
    fi
    echo ""

    # YARA status
    echo "YARA Rules:"
    local yara_rules="$USB_ROOT/dms/databases/yara"
    if [ -d "$yara_rules" ] && [ -n "$(ls -A "$yara_rules"/*.yar 2>/dev/null)" ]; then
        local rule_count=$(find "$yara_rules" -name "*.yar" -o -name "*.yara" 2>/dev/null | wc -l)
        echo "  Status:   Installed ($rule_count rule files)"
        [ -f "$yara_rules/qu1cksc0pe_date.txt" ] && echo "  Qu1cksc0pe:     $(cat "$yara_rules/qu1cksc0pe_date.txt")"
        [ -f "$yara_rules/signature_base_date.txt" ] && echo "  Signature-base: $(cat "$yara_rules/signature_base_date.txt")"
        if check_yara_update_needed; then
            echo "  Action:   Update recommended"
        else
            echo "  Action:   Up to date"
        fi
    else
        echo "  Status:   Not installed"
        echo "  Action:   Update required"
    fi
    echo ""

    # Network status
    echo "Network:"
    if check_network_connectivity; then
        echo "  Status:   Available"
    else
        echo "  Status:   Not available"
    fi
    echo ""

    # Writable status
    echo "USB Kit:"
    if [ "$USB_WRITABLE" = "true" ]; then
        echo "  Writable: Yes"
    else
        echo "  Writable: No (updates not possible)"
    fi

    return 0
}
