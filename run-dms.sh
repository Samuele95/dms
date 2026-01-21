#!/bin/bash
# ============================================================================
# DMS Portable Launcher
# ============================================================================
# Launch DMS from USB kit with proper environment setup
#
# This script is placed at the USB root level and configures the environment
# for running DMS in portable mode.
#
# Usage:
#   ./run-dms.sh <target> [options]
#   ./run-dms.sh --dry-run          # For testing - prints environment vars
# ============================================================================

# Determine script location (resolve symlinks)
LAUNCHER_SCRIPT="${BASH_SOURCE[0]}"
while [ -L "$LAUNCHER_SCRIPT" ]; do
    LAUNCHER_DIR="$(cd "$(dirname "$LAUNCHER_SCRIPT")" && pwd)"
    LAUNCHER_SCRIPT="$(readlink "$LAUNCHER_SCRIPT")"
    [[ $LAUNCHER_SCRIPT != /* ]] && LAUNCHER_SCRIPT="$LAUNCHER_DIR/$LAUNCHER_SCRIPT"
done
LAUNCHER_DIR="$(cd "$(dirname "$LAUNCHER_SCRIPT")" && pwd)"

# ============================================================================
# Export DMS paths
# ============================================================================

export DMS_ROOT="$LAUNCHER_DIR/dms"
export DMS_TOOLS="$LAUNCHER_DIR/dms/tools"
export DMS_DATABASES="$LAUNCHER_DIR/dms/databases"

# Backwards compatibility
export USB_ROOT="$LAUNCHER_DIR"
export USB_MODE=true

# ============================================================================
# Configure PATH
# ============================================================================

# Add bundled tools to PATH
if [ -d "$DMS_TOOLS/bin" ]; then
    export PATH="$DMS_TOOLS/bin:$PATH"
fi

# Add libraries to LD_LIBRARY_PATH
if [ -d "$DMS_TOOLS/lib" ]; then
    export LD_LIBRARY_PATH="$DMS_TOOLS/lib:${LD_LIBRARY_PATH:-}"
fi

# ============================================================================
# Configure database paths
# ============================================================================

# Set ClamAV database directory
if [ -d "$DMS_DATABASES/clamav" ]; then
    export CLAMDB_DIR="$DMS_DATABASES/clamav"
fi

# Set YARA rules directory
if [ -d "$DMS_DATABASES/yara" ]; then
    export DMS_YARA_RULES_DIR="$DMS_DATABASES/yara"
fi

# ============================================================================
# Handle special arguments
# ============================================================================

# --dry-run: For testing - print environment and exit
if [ "$1" = "--dry-run" ]; then
    echo "DMS Portable Launcher - Environment Check"
    echo "=========================================="
    echo ""
    echo "Paths:"
    echo "  DMS_ROOT=$DMS_ROOT"
    echo "  DMS_TOOLS=$DMS_TOOLS"
    echo "  DMS_DATABASES=$DMS_DATABASES"
    echo ""
    echo "PATH includes:"
    echo "  $DMS_TOOLS/bin"
    echo ""
    echo "Database paths:"
    echo "  CLAMDB_DIR=${CLAMDB_DIR:-not set}"
    echo "  DMS_YARA_RULES_DIR=${DMS_YARA_RULES_DIR:-not set}"
    echo ""

    # Check main script
    if [ -f "$DMS_ROOT/malware_scan.sh" ]; then
        echo "Main script: Found"
    else
        echo "Main script: NOT FOUND"
    fi

    exit 0
fi

# --version: Show version info
if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
    echo "DMS Portable Launcher"
    if [ -f "$LAUNCHER_DIR/.dms_kit_manifest.json" ]; then
        echo -n "Kit version: "
        grep -o '"kit_version": *"[^"]*"' "$LAUNCHER_DIR/.dms_kit_manifest.json" | cut -d'"' -f4
        echo -n "DMS version: "
        grep -o '"dms_version": *"[^"]*"' "$LAUNCHER_DIR/.dms_kit_manifest.json" | cut -d'"' -f4
        echo -n "Kit mode: "
        grep -o '"mode": *"[^"]*"' "$LAUNCHER_DIR/.dms_kit_manifest.json" | cut -d'"' -f4
    fi
    exit 0
fi

# --help: Show basic help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "DMS Portable Launcher"
    echo ""
    echo "Usage: $0 <target> [options]"
    echo ""
    echo "Launcher options:"
    echo "  --dry-run     Show environment configuration and exit"
    echo "  --version     Show kit version information"
    echo "  --help        Show this help message"
    echo ""
    echo "All other options are passed to malware_scan.sh"
    echo "Run '$0 --scanner-help' to see scanner options."
    echo ""
    exit 0
fi

# --scanner-help: Pass through to show scanner help
if [ "$1" = "--scanner-help" ]; then
    shift
    set -- "--help" "$@"
fi

# ============================================================================
# Verify and launch main script
# ============================================================================

# Check for main script
if [ ! -f "$DMS_ROOT/malware_scan.sh" ]; then
    echo "Error: malware_scan.sh not found at $DMS_ROOT" >&2
    echo "" >&2
    echo "Expected location: $DMS_ROOT/malware_scan.sh" >&2
    echo "This launcher expects a DMS installation in the 'dms' subdirectory." >&2
    exit 1
fi

# Make sure it's executable
if [ ! -x "$DMS_ROOT/malware_scan.sh" ]; then
    chmod +x "$DMS_ROOT/malware_scan.sh" 2>/dev/null || {
        echo "Warning: Could not make malware_scan.sh executable" >&2
    }
fi

# Launch DMS with all arguments
exec "$DMS_ROOT/malware_scan.sh" "$@"
