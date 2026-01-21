#!/bin/bash
# ============================================================================
# DMS USB Mode Module
# ============================================================================
# USB kit detection, environment setup, and manifest handling
#
# This module enables DMS to run as a portable USB-based forensic kit with
# dual-mode operation:
#   - Minimal mode: Small footprint, downloads tools on-demand
#   - Full offline mode: Complete self-contained kit with bundled tools/databases
#
# Usage:
#   source lib/usb_mode.sh
#   detect_usb_environment
#   setup_usb_environment
# ============================================================================

# ============================================================================
# USB Mode Variables (exported for use by other modules)
# ============================================================================

# Core USB mode state
declare -g USB_MODE="${USB_MODE:-false}"
declare -g USB_ROOT="${USB_ROOT:-}"
declare -g KIT_MODE="${KIT_MODE:-none}"          # "none", "minimal", "full"
declare -g KIT_MANIFEST="${KIT_MANIFEST:-}"
declare -g USB_WRITABLE="${USB_WRITABLE:-false}"

# Directory paths (set by setup_usb_environment)
declare -g DMS_TOOLS_DIR="${DMS_TOOLS_DIR:-}"
declare -g DMS_DATABASES_DIR="${DMS_DATABASES_DIR:-}"
declare -g DMS_CACHE_DIR="${DMS_CACHE_DIR:-}"

# Compatibility with existing portable mode
declare -g PORTABLE_MODE="${PORTABLE_MODE:-false}"
declare -g PORTABLE_TOOLS_DIR="${PORTABLE_TOOLS_DIR:-}"

# ClamAV database directory (used by scanner)
declare -g CLAMDB_DIR="${CLAMDB_DIR:-}"

# Manifest parsed values
declare -g MANIFEST_KIT_VERSION="${MANIFEST_KIT_VERSION:-unknown}"
declare -g MANIFEST_MODE="${MANIFEST_MODE:-unknown}"
declare -g MANIFEST_DMS_VERSION="${MANIFEST_DMS_VERSION:-unknown}"
declare -g MANIFEST_CLAMAV_VERSION="${MANIFEST_CLAMAV_VERSION:-unknown}"
declare -g MANIFEST_YARA_VERSION="${MANIFEST_YARA_VERSION:-unknown}"
declare -g MANIFEST_CREATED_DATE="${MANIFEST_CREATED_DATE:-unknown}"
declare -g MANIFEST_LAST_UPDATED="${MANIFEST_LAST_UPDATED:-unknown}"

# ============================================================================
# USB Environment Detection
# ============================================================================

# Detect if running from a USB kit environment
# Sets: USB_MODE, USB_ROOT, KIT_MODE, KIT_MANIFEST
# Returns: 0 if USB kit detected, 1 otherwise
detect_usb_environment() {
    local script_path="${DMS_SCRIPT_PATH:-${BASH_SOURCE[1]:-$0}}"
    local script_dir

    # Resolve the actual script directory
    script_dir="$(cd "$(dirname "$script_path")" && pwd)"

    # Look for manifest in parent directory (USB root) or current directory
    local possible_roots=(
        "$(dirname "$script_dir")"    # Parent of dms/ directory
        "$script_dir"                  # Current directory
        "$(dirname "$(dirname "$script_dir")")"  # Two levels up
    )

    for root in "${possible_roots[@]}"; do
        local manifest="$root/.dms_kit_manifest.json"
        if [ -f "$manifest" ]; then
            USB_MODE=true
            USB_ROOT="$root"
            KIT_MANIFEST="$manifest"

            # Parse manifest to get kit mode
            parse_kit_manifest "$manifest"
            KIT_MODE="$MANIFEST_MODE"

            # Validate kit mode against actual directory structure
            _validate_kit_mode

            # Check if USB is writable
            _check_usb_writable

            return 0
        fi
    done

    # No manifest found - not running from USB kit
    USB_MODE=false
    USB_ROOT=""
    KIT_MODE="none"
    KIT_MANIFEST=""
    return 1
}

# Validate kit mode matches actual directory structure
_validate_kit_mode() {
    local dms_dir="$USB_ROOT/dms"

    # Check for full kit indicators
    if [ "$KIT_MODE" = "full" ]; then
        # Full kit should have tools and databases
        if [ ! -d "$dms_dir/tools" ] || [ ! -d "$dms_dir/databases" ]; then
            # Manifest says full but directories missing - downgrade to minimal
            KIT_MODE="minimal"
        fi
    fi

    # Check for minimal kit (no bundled tools)
    if [ "$KIT_MODE" = "minimal" ]; then
        # Minimal kit has no tools directory (or empty)
        if [ -d "$dms_dir/tools/bin" ] && [ -n "$(ls -A "$dms_dir/tools/bin" 2>/dev/null)" ]; then
            # Actually has tools - might be full
            if [ -d "$dms_dir/databases/clamav" ] && [ -n "$(ls -A "$dms_dir/databases/clamav" 2>/dev/null)" ]; then
                KIT_MODE="full"
            fi
        fi
    fi
}

# Check if USB root is writable
_check_usb_writable() {
    local test_file="$USB_ROOT/.dms_write_test_$$"

    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        USB_WRITABLE=true
    else
        USB_WRITABLE=false
    fi
}

# ============================================================================
# USB Environment Setup
# ============================================================================

# Configure environment paths for USB mode operation
# Must be called after detect_usb_environment()
# Sets: PATH, CLAMDB_DIR, DMS_TOOLS_DIR, DMS_DATABASES_DIR, etc.
setup_usb_environment() {
    if [ "$USB_MODE" != "true" ]; then
        return 1
    fi

    local dms_dir="$USB_ROOT/dms"

    case "$KIT_MODE" in
        full)
            _setup_full_mode "$dms_dir"
            ;;
        minimal)
            _setup_minimal_mode "$dms_dir"
            ;;
        *)
            # Unknown mode - treat as minimal
            _setup_minimal_mode "$dms_dir"
            ;;
    esac

    # Set common paths
    DMS_CACHE_DIR="$dms_dir/cache"
    [ -d "$DMS_CACHE_DIR" ] || mkdir -p "$DMS_CACHE_DIR" 2>/dev/null || DMS_CACHE_DIR="/tmp/dms-cache-$$"

    return 0
}

# Setup for full offline mode (bundled tools and databases)
_setup_full_mode() {
    local dms_dir="$1"

    # Set tool directories
    DMS_TOOLS_DIR="$dms_dir/tools"
    DMS_DATABASES_DIR="$dms_dir/databases"

    # Add bundled tools to PATH
    if [ -d "$DMS_TOOLS_DIR/bin" ]; then
        export PATH="$DMS_TOOLS_DIR/bin:$PATH"
    fi

    # Add library paths if present
    if [ -d "$DMS_TOOLS_DIR/lib" ]; then
        export LD_LIBRARY_PATH="${DMS_TOOLS_DIR}/lib:${LD_LIBRARY_PATH:-}"
    fi

    # Set ClamAV database directory
    if [ -d "$DMS_DATABASES_DIR/clamav" ]; then
        CLAMDB_DIR="$DMS_DATABASES_DIR/clamav"
        export CLAMDB_DIR
    fi

    # Set YARA rules directory if present
    if [ -d "$DMS_DATABASES_DIR/yara" ]; then
        export DMS_YARA_RULES_DIR="$DMS_DATABASES_DIR/yara"
    fi

    # Portable mode is false for full kit (tools already available)
    PORTABLE_MODE=false
    PORTABLE_TOOLS_DIR=""
}

# Setup for minimal mode (download tools on demand)
_setup_minimal_mode() {
    local dms_dir="$1"

    # Enable portable mode for on-demand tool downloads
    PORTABLE_MODE=true

    # Determine where to store downloaded tools
    if [ "$USB_WRITABLE" = "true" ]; then
        PORTABLE_TOOLS_DIR="$dms_dir/tools"
        DMS_DATABASES_DIR="$dms_dir/databases"
    else
        # USB is read-only - fall back to /tmp
        PORTABLE_TOOLS_DIR="/tmp/dms-tools-$$"
        DMS_DATABASES_DIR="/tmp/dms-databases-$$"
    fi

    DMS_TOOLS_DIR="$PORTABLE_TOOLS_DIR"

    # Create directories if they don't exist
    mkdir -p "$PORTABLE_TOOLS_DIR/bin" 2>/dev/null || true
    mkdir -p "$DMS_DATABASES_DIR/clamav" 2>/dev/null || true
    mkdir -p "$DMS_DATABASES_DIR/yara" 2>/dev/null || true

    # Add to PATH even if empty (tools will be downloaded there)
    if [ -d "$PORTABLE_TOOLS_DIR/bin" ]; then
        export PATH="$PORTABLE_TOOLS_DIR/bin:$PATH"
    fi

    # Set database directories
    CLAMDB_DIR="$DMS_DATABASES_DIR/clamav"
    export CLAMDB_DIR
    export DMS_YARA_RULES_DIR="$DMS_DATABASES_DIR/yara"
}

# ============================================================================
# Kit Manifest Management
# ============================================================================

# Parse kit manifest JSON file
# Sets: MANIFEST_* variables
# Returns: 0 on success, 1 on error
parse_kit_manifest() {
    local manifest_file="$1"

    # Reset to defaults
    MANIFEST_KIT_VERSION="unknown"
    MANIFEST_MODE="unknown"
    MANIFEST_DMS_VERSION="unknown"
    MANIFEST_CLAMAV_VERSION="unknown"
    MANIFEST_YARA_VERSION="unknown"
    MANIFEST_CREATED_DATE="unknown"
    MANIFEST_LAST_UPDATED="unknown"

    if [ ! -f "$manifest_file" ]; then
        return 1
    fi

    # Parse JSON using grep/sed (portable, no jq dependency)
    local content
    content=$(cat "$manifest_file" 2>/dev/null) || return 1

    # Extract top-level fields
    MANIFEST_KIT_VERSION=$(_json_get_string "$content" "kit_version")
    MANIFEST_MODE=$(_json_get_string "$content" "mode")
    MANIFEST_DMS_VERSION=$(_json_get_string "$content" "dms_version")
    MANIFEST_CREATED_DATE=$(_json_get_string "$content" "created_date")
    MANIFEST_LAST_UPDATED=$(_json_get_string "$content" "last_updated")

    # Extract nested database versions
    # ClamAV version is nested: databases.clamav.version
    MANIFEST_CLAMAV_VERSION=$(_json_get_nested_string "$content" "clamav" "version")

    # Set defaults for any empty values
    [ -z "$MANIFEST_KIT_VERSION" ] && MANIFEST_KIT_VERSION="unknown"
    [ -z "$MANIFEST_MODE" ] && MANIFEST_MODE="unknown"
    [ -z "$MANIFEST_DMS_VERSION" ] && MANIFEST_DMS_VERSION="unknown"
    [ -z "$MANIFEST_CLAMAV_VERSION" ] && MANIFEST_CLAMAV_VERSION="unknown"

    return 0
}

# Create a new kit manifest file
# Arguments: target_directory, mode ("minimal" or "full")
# Returns: 0 on success, 1 on error
create_kit_manifest() {
    local target_dir="$1"
    local mode="${2:-minimal}"
    local manifest_file="$target_dir/.dms_kit_manifest.json"

    # Get current timestamp in ISO 8601 format
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Get DMS version if available
    local dms_version="2.1"
    if [ -f "$target_dir/dms/malware_scan.sh" ]; then
        dms_version=$(grep -o 'VERSION="[^"]*"' "$target_dir/dms/malware_scan.sh" 2>/dev/null | head -1 | cut -d'"' -f2) || dms_version="2.1"
    fi

    # Detect database versions if present
    local clamav_version="not_installed"
    local clamav_date="not_installed"
    local yara_date="not_installed"

    if [ -d "$target_dir/dms/databases/clamav" ]; then
        # Try to read ClamAV database version
        if [ -f "$target_dir/dms/databases/clamav/version.txt" ]; then
            clamav_version=$(cat "$target_dir/dms/databases/clamav/version.txt" 2>/dev/null) || clamav_version="unknown"
        elif command -v sigtool &>/dev/null && [ -f "$target_dir/dms/databases/clamav/main.cvd" ]; then
            clamav_version=$(sigtool --info "$target_dir/dms/databases/clamav/main.cvd" 2>/dev/null | grep "Version:" | awk '{print $2}') || clamav_version="unknown"
        fi
        clamav_date=$(date -u +"%Y-%m-%d")
    fi

    if [ -d "$target_dir/dms/databases/yara" ]; then
        yara_date=$(date -u +"%Y-%m-%d")
    fi

    # Detect tool versions if present
    local tools_json=""
    if [ "$mode" = "full" ] && [ -d "$target_dir/dms/tools/bin" ]; then
        tools_json=',
  "tools": {'
        local first_tool=true

        if [ -x "$target_dir/dms/tools/bin/clamscan" ]; then
            local clam_ver
            clam_ver=$("$target_dir/dms/tools/bin/clamscan" --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1) || clam_ver="unknown"
            tools_json+="
    \"clamav\": \"$clam_ver\""
            first_tool=false
        fi

        if [ -x "$target_dir/dms/tools/bin/yara" ]; then
            local yara_ver
            yara_ver=$("$target_dir/dms/tools/bin/yara" --version 2>/dev/null) || yara_ver="unknown"
            [ "$first_tool" = false ] && tools_json+=","
            tools_json+="
    \"yara\": \"$yara_ver\""
        fi

        tools_json+='
  }'
    fi

    # Write manifest
    cat > "$manifest_file" << EOF
{
  "kit_version": "1.0.0",
  "created_date": "$timestamp",
  "last_updated": "$timestamp",
  "mode": "$mode",
  "dms_version": "$dms_version",
  "databases": {
    "clamav": {
      "version": "$clamav_version",
      "date": "$clamav_date"
    },
    "yara": {
      "qu1cksc0pe_date": "$yara_date",
      "signature_base_date": "$yara_date"
    }
  }$tools_json
}
EOF

    return 0
}

# Update manifest with new timestamp and optionally new database versions
# Arguments: manifest_file [clamav_version] [yara_date]
update_kit_manifest() {
    local manifest_file="$1"
    local clamav_version="${2:-}"
    local yara_date="${3:-}"

    if [ ! -f "$manifest_file" ]; then
        return 1
    fi

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Read current manifest
    local content
    content=$(cat "$manifest_file")

    # Update last_updated timestamp
    content=$(echo "$content" | sed "s/\"last_updated\": *\"[^\"]*\"/\"last_updated\": \"$timestamp\"/")

    # Update ClamAV version if provided
    if [ -n "$clamav_version" ]; then
        content=$(echo "$content" | sed "s/\"version\": *\"[^\"]*\"/\"version\": \"$clamav_version\"/")
    fi

    # Write back
    echo "$content" > "$manifest_file"

    return 0
}

# ============================================================================
# JSON Parsing Helpers (no external dependencies)
# ============================================================================

# Extract a string value from JSON by key (simple top-level only)
_json_get_string() {
    local json="$1"
    local key="$2"

    echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/'
}

# Extract a nested string value (one level deep, e.g., databases.clamav.version)
_json_get_nested_string() {
    local json="$1"
    local parent="$2"
    local key="$3"

    # Find the section starting with parent key and extract the nested key
    # This is a simplified parser - works for our manifest format
    echo "$json" | grep -A 10 "\"$parent\"" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/'
}

# ============================================================================
# Utility Functions
# ============================================================================

# Get information about current USB kit status
get_usb_kit_info() {
    if [ "$USB_MODE" != "true" ]; then
        echo "Not running from USB kit"
        return 1
    fi

    echo "USB Kit Status"
    echo "=============="
    echo "USB Root:     $USB_ROOT"
    echo "Kit Mode:     $KIT_MODE"
    echo "Manifest:     $KIT_MANIFEST"
    echo "USB Writable: $USB_WRITABLE"
    echo ""
    echo "Kit Version:  $MANIFEST_KIT_VERSION"
    echo "DMS Version:  $MANIFEST_DMS_VERSION"
    echo "Last Updated: $MANIFEST_LAST_UPDATED"
    echo ""
    echo "Directories:"
    echo "  Tools:      ${DMS_TOOLS_DIR:-not set}"
    echo "  Databases:  ${DMS_DATABASES_DIR:-not set}"
    echo "  Cache:      ${DMS_CACHE_DIR:-not set}"

    return 0
}

# Check if running in USB mode
is_usb_mode() {
    [ "$USB_MODE" = "true" ]
}

# Check if kit is full offline mode
is_full_kit() {
    [ "$USB_MODE" = "true" ] && [ "$KIT_MODE" = "full" ]
}

# Check if kit is minimal mode
is_minimal_kit() {
    [ "$USB_MODE" = "true" ] && [ "$KIT_MODE" = "minimal" ]
}

# ============================================================================
# Module Initialization
# ============================================================================

# Auto-detect USB environment when module is sourced (optional)
# Uncomment below to auto-detect on source:
# detect_usb_environment 2>/dev/null || true
