#!/bin/bash
# ============================================================================
# DMS Kit Builder Module
# ============================================================================
# Full offline kit building logic for creating self-contained forensic kits
#
# This module creates a complete DMS kit with:
#   - All portable tools (ClamAV, YARA, etc.)
#   - Malware signature databases
#   - Compiled YARA rules cache
#   - Kit manifest
#
# Usage:
#   source lib/kit_builder.sh
#   build_full_kit /path/to/target
# ============================================================================

# ============================================================================
# Kit Builder Variables
# ============================================================================

declare -g KIT_VERBOSE="${KIT_VERBOSE:-false}"
declare -g KIT_MIN_SPACE_MB="${KIT_MIN_SPACE_MB:-2000}"  # Minimum 2GB required

# Tool download URLs
declare -g CLAMAV_PORTABLE_URL="${CLAMAV_PORTABLE_URL:-}"
declare -g YARA_PORTABLE_URL="${YARA_PORTABLE_URL:-}"

# ============================================================================
# Space Checking
# ============================================================================

# Get available space in MB at a path
# Arguments: path
# Returns: Available space in MB (stdout)
get_available_space_mb() {
    local path="$1"

    # Handle non-existent paths by checking parent
    while [ ! -d "$path" ] && [ "$path" != "/" ]; do
        path=$(dirname "$path")
    done

    if [ -d "$path" ]; then
        df -m "$path" 2>/dev/null | awk 'NR==2 {print $4}'
    else
        echo "0"
    fi
}

# Check if target has sufficient space for full kit
# Arguments: target_path
# Returns: 0 if sufficient, 1 if not
check_sufficient_space() {
    local target="$1"
    local required_mb="${2:-$KIT_MIN_SPACE_MB}"

    local available
    available=$(get_available_space_mb "$target")

    if [ -z "$available" ] || [ "$available" -lt "$required_mb" ]; then
        return 1
    fi

    return 0
}

# ============================================================================
# Kit Building Functions
# ============================================================================

# Build a complete offline DMS kit
# Arguments: target_directory
# Returns: 0 on success, 1 on error
build_full_kit() {
    local target="$1"

    if [ -z "$target" ]; then
        echo "Error: Target directory not specified" >&2
        return 1
    fi

    echo "Building Full DMS Kit"
    echo "====================="
    echo "Target: $target"
    echo ""

    # Check disk space
    echo "Checking disk space..."
    if ! check_sufficient_space "$target"; then
        local available
        available=$(get_available_space_mb "$target")
        echo "Error: Insufficient disk space" >&2
        echo "  Required: ${KIT_MIN_SPACE_MB} MB" >&2
        echo "  Available: ${available:-0} MB" >&2
        return 1
    fi
    echo "  Sufficient space available"

    # Check network connectivity
    echo "Checking network connectivity..."
    if type check_network_connectivity &>/dev/null; then
        if ! check_network_connectivity; then
            echo "Error: No network connectivity" >&2
            echo "  Full kit building requires network to download tools and databases" >&2
            return 1
        fi
    fi
    echo "  Network available"

    # Create directory structure
    echo ""
    echo "Creating directory structure..."
    if ! create_kit_directory_structure "$target"; then
        echo "Error: Failed to create directory structure" >&2
        return 1
    fi

    # Copy DMS scripts
    echo "Copying DMS scripts..."
    if ! copy_dms_scripts "$target"; then
        echo "Error: Failed to copy DMS scripts" >&2
        return 1
    fi

    # Download portable tools
    echo ""
    echo "Downloading portable tools..."
    if type download_portable_tools &>/dev/null; then
        if ! download_portable_tools "$target/dms/tools"; then
            echo "Warning: Some tools failed to download" >&2
        fi
    else
        _download_portable_tools_internal "$target/dms/tools"
    fi

    # Download databases
    echo ""
    echo "Downloading databases..."
    if type download_databases &>/dev/null; then
        if ! download_databases "$target/dms/databases"; then
            echo "Warning: Some databases failed to download" >&2
        fi
    else
        _download_databases_internal "$target/dms/databases"
    fi

    # Create manifest
    echo ""
    echo "Creating kit manifest..."
    if type create_kit_manifest &>/dev/null; then
        create_kit_manifest "$target" "full"
    else
        _create_basic_manifest "$target" "full"
    fi

    # Create launcher script
    echo "Creating launcher script..."
    create_launcher_script "$target"

    echo ""
    echo "Kit build complete!"
    echo "  Location: $target"
    echo "  Mode: full"
    echo ""
    echo "To use: $target/run-dms.sh <target> [options]"

    return 0
}

# Build a minimal kit (scripts only, no bundled tools)
# Arguments: target_directory
build_minimal_kit() {
    local target="$1"

    if [ -z "$target" ]; then
        echo "Error: Target directory not specified" >&2
        return 1
    fi

    echo "Building Minimal DMS Kit"
    echo "========================"
    echo "Target: $target"
    echo ""

    # Create directory structure
    echo "Creating directory structure..."
    mkdir -p "$target/dms/lib" 2>/dev/null || {
        echo "Error: Cannot create directories" >&2
        return 1
    }

    # Copy DMS scripts
    echo "Copying DMS scripts..."
    copy_dms_scripts "$target"

    # Create manifest
    echo "Creating kit manifest..."
    if type create_kit_manifest &>/dev/null; then
        create_kit_manifest "$target" "minimal"
    else
        _create_basic_manifest "$target" "minimal"
    fi

    # Create launcher script
    echo "Creating launcher script..."
    create_launcher_script "$target"

    echo ""
    echo "Minimal kit build complete!"
    echo "  Location: $target"
    echo "  Mode: minimal"
    echo ""
    echo "Tools will be downloaded on first run."

    return 0
}

# ============================================================================
# Directory Structure Creation
# ============================================================================

# Create the full kit directory structure
# Arguments: target_directory
create_kit_directory_structure() {
    local target="$1"

    local dirs=(
        "$target/dms"
        "$target/dms/lib"
        "$target/dms/tools"
        "$target/dms/tools/bin"
        "$target/dms/tools/lib"
        "$target/dms/databases"
        "$target/dms/databases/clamav"
        "$target/dms/databases/yara"
        "$target/dms/cache"
        "$target/dms/output"
        "$target/dms/logs"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" 2>/dev/null || {
            echo "  Error: Failed to create $dir" >&2
            return 1
        }
    done

    echo "  Created ${#dirs[@]} directories"
    return 0
}

# ============================================================================
# Script Copying
# ============================================================================

# Copy DMS scripts to target
# Arguments: target_directory
copy_dms_scripts() {
    local target="$1"
    local source_dir="${DMS_SOURCE_DIR:-$(dirname "$(dirname "${BASH_SOURCE[0]}")")}"

    # Copy main script
    if [ -f "$source_dir/malware_scan.sh" ]; then
        cp "$source_dir/malware_scan.sh" "$target/dms/"
        chmod +x "$target/dms/malware_scan.sh"
        echo "  Copied malware_scan.sh"
    fi

    # Copy config
    if [ -f "$source_dir/malscan.conf" ]; then
        cp "$source_dir/malscan.conf" "$target/dms/"
        echo "  Copied malscan.conf"
    fi

    # Copy lib modules
    if [ -d "$source_dir/lib" ]; then
        cp -r "$source_dir/lib"/* "$target/dms/lib/" 2>/dev/null || true
        echo "  Copied lib modules"
    fi

    # Copy templates if present
    if [ -d "$source_dir/templates" ]; then
        mkdir -p "$target/dms/templates"
        cp -r "$source_dir/templates"/* "$target/dms/templates/" 2>/dev/null || true
        echo "  Copied templates"
    fi

    return 0
}

# ============================================================================
# Tool Downloads
# ============================================================================

# Internal tool download function (fallback if not mocked)
_download_portable_tools_internal() {
    local tools_dir="$1"

    echo "  Note: Using portable tool installers from main script"

    # The main malware_scan.sh has install functions we can leverage
    local main_script="${DMS_SOURCE_DIR:-$(dirname "$(dirname "${BASH_SOURCE[0]}")")}/malware_scan.sh"

    if [ -f "$main_script" ]; then
        # Source needed functions
        local temp_source=$(mktemp)
        # Extract install functions
        sed -n '/^install_.*_portable/,/^}/p' "$main_script" > "$temp_source" 2>/dev/null

        # Set PORTABLE_TOOLS_DIR for installers
        export PORTABLE_TOOLS_DIR="$tools_dir"
        export PORTABLE_MODE=true

        # Source and call if available
        source "$temp_source" 2>/dev/null || true

        # Try to install ClamAV
        if type install_clamav_portable &>/dev/null; then
            echo "    Installing ClamAV..."
            install_clamav_portable 2>/dev/null || echo "      Warning: ClamAV install failed"
        fi

        # Try to install YARA
        if type install_yara_portable &>/dev/null; then
            echo "    Installing YARA..."
            install_yara_portable 2>/dev/null || echo "      Warning: YARA install failed"
        fi

        rm -f "$temp_source"
    fi

    return 0
}

# Internal database download function (fallback if not mocked)
_download_databases_internal() {
    local db_dir="$1"

    # Use update_manager if available
    if [ -f "$(dirname "${BASH_SOURCE[0]}")/update_manager.sh" ]; then
        source "$(dirname "${BASH_SOURCE[0]}")/update_manager.sh"

        # Temporarily set USB_ROOT for update functions
        local old_usb_root="$USB_ROOT"
        USB_ROOT="$(dirname "$db_dir")"

        echo "    Downloading ClamAV databases..."
        update_clamav_databases_on_usb 2>/dev/null || echo "      Warning: ClamAV database download failed"

        echo "    Downloading YARA rules..."
        update_yara_rules_on_usb 2>/dev/null || echo "      Warning: YARA rules download failed"

        USB_ROOT="$old_usb_root"
    else
        echo "    Note: update_manager.sh not found, skipping database downloads"
    fi

    return 0
}

# ============================================================================
# Manifest Creation (Fallback)
# ============================================================================

# Create a basic manifest if usb_mode.sh is not available
_create_basic_manifest() {
    local target="$1"
    local mode="${2:-full}"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$target/.dms_kit_manifest.json" << EOF
{
  "kit_version": "1.0.0",
  "created_date": "$timestamp",
  "last_updated": "$timestamp",
  "mode": "$mode",
  "dms_version": "2.1"
}
EOF

    return 0
}

# ============================================================================
# Launcher Script Creation
# ============================================================================

# Create the portable launcher script
# Arguments: target_directory
create_launcher_script() {
    local target="$1"

    cat > "$target/run-dms.sh" << 'LAUNCHER_EOF'
#!/bin/bash
# ============================================================================
# DMS Portable Launcher
# ============================================================================
# Launch DMS from USB kit with proper environment setup
# ============================================================================

# Determine script location
LAUNCHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Export DMS paths
export DMS_ROOT="$LAUNCHER_DIR/dms"
export DMS_TOOLS="$LAUNCHER_DIR/dms/tools"
export DMS_DATABASES="$LAUNCHER_DIR/dms/databases"

# Add tools to PATH
if [ -d "$DMS_TOOLS/bin" ]; then
    export PATH="$DMS_TOOLS/bin:$PATH"
fi

# Add libraries to LD_LIBRARY_PATH
if [ -d "$DMS_TOOLS/lib" ]; then
    export LD_LIBRARY_PATH="$DMS_TOOLS/lib:${LD_LIBRARY_PATH:-}"
fi

# Set database paths
if [ -d "$DMS_DATABASES/clamav" ]; then
    export CLAMDB_DIR="$DMS_DATABASES/clamav"
fi

if [ -d "$DMS_DATABASES/yara" ]; then
    export DMS_YARA_RULES_DIR="$DMS_DATABASES/yara"
fi

# Handle --dry-run for testing
if [ "$1" = "--dry-run" ]; then
    echo "DMS_ROOT=$DMS_ROOT"
    echo "DMS_TOOLS=$DMS_TOOLS"
    echo "DMS_DATABASES=$DMS_DATABASES"
    echo "PATH includes: $DMS_TOOLS/bin"
    exit 0
fi

# Check for main script
if [ ! -f "$DMS_ROOT/malware_scan.sh" ]; then
    echo "Error: malware_scan.sh not found at $DMS_ROOT" >&2
    exit 1
fi

# Launch DMS with all arguments
exec "$DMS_ROOT/malware_scan.sh" "$@"
LAUNCHER_EOF

    chmod +x "$target/run-dms.sh"
    echo "  Created run-dms.sh"

    return 0
}

# ============================================================================
# Kit Verification
# ============================================================================

# Verify kit integrity
# Arguments: kit_root
verify_kit() {
    local kit_root="$1"
    local errors=0

    echo "Verifying kit at $kit_root..."

    # Check manifest
    if [ ! -f "$kit_root/.dms_kit_manifest.json" ]; then
        echo "  Missing: .dms_kit_manifest.json"
        ((errors++))
    fi

    # Check main script
    if [ ! -f "$kit_root/dms/malware_scan.sh" ]; then
        echo "  Missing: dms/malware_scan.sh"
        ((errors++))
    fi

    # Check launcher
    if [ ! -f "$kit_root/run-dms.sh" ]; then
        echo "  Missing: run-dms.sh"
        ((errors++))
    fi

    # Check directories
    local required_dirs=("dms/lib" "dms/tools" "dms/databases")
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$kit_root/$dir" ]; then
            echo "  Missing directory: $dir"
            ((errors++))
        fi
    done

    if [ $errors -eq 0 ]; then
        echo "  Kit verification passed"
        return 0
    else
        echo "  Kit verification failed with $errors error(s)"
        return 1
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

# Print kit builder help
kit_builder_help() {
    cat << 'EOF'
DMS Kit Builder
===============

Build portable forensic kits for field deployment.

Usage:
  build_full_kit <target>     Build complete offline kit with all tools
  build_minimal_kit <target>  Build minimal kit (scripts only)
  verify_kit <kit_root>       Verify kit integrity

Kit Modes:
  full     - Complete offline operation (~1.2 GB)
             Includes: ClamAV, YARA, databases, rules
             Use when: No network at deployment site

  minimal  - Small footprint (~10 MB)
             Includes: Scripts only
             Use when: Network available at deployment site

Directory Structure:
  target/
  ├── .dms_kit_manifest.json   Kit metadata
  ├── run-dms.sh               Launcher script
  └── dms/
      ├── malware_scan.sh      Main scanner
      ├── malscan.conf         Configuration
      ├── lib/                 Modules
      ├── tools/               Portable tools
      ├── databases/           Signatures
      └── cache/               Compiled rules

Requirements:
  - Full kit: 2+ GB free space, network for downloads
  - Minimal kit: 50+ MB free space, no network needed

EOF
}
