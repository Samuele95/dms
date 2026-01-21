#!/bin/bash
# ============================================================================
# DMS Output Storage Module
# ============================================================================
# Output storage detection, selection, and management for forensic scans
#
# This module handles:
#   - Detection of available writable storage (excluding evidence drives)
#   - Safe output device mounting
#   - Case directory structure creation
#   - Evidence information documentation
#
# Usage:
#   source lib/output_storage.sh
#   detect_available_storage "/dev/sda1"  # Evidence device to exclude
#   setup_output_storage
#   create_case_directory
# ============================================================================

# ============================================================================
# Output Storage Variables
# ============================================================================

# Configuration
declare -g OUTPUT_DEVICE="${OUTPUT_DEVICE:-}"
declare -g OUTPUT_MOUNT_POINT="${OUTPUT_MOUNT_POINT:-/mnt/dms-output}"
declare -g OUTPUT_TYPE="${OUTPUT_TYPE:-device}"    # "device", "tmpfs", "path"
declare -g OUTPUT_MOUNTED="${OUTPUT_MOUNTED:-false}"
declare -g USE_TMPFS_OUTPUT="${USE_TMPFS_OUTPUT:-false}"
declare -g CASE_NAME="${CASE_NAME:-}"
declare -g INTERACTIVE_MODE="${INTERACTIVE_MODE:-true}"

# Evidence information (set before creating evidence info)
declare -g EVIDENCE_DEVICE="${EVIDENCE_DEVICE:-}"
declare -g EVIDENCE_TYPE="${EVIDENCE_TYPE:-}"
declare -g EVIDENCE_MD5="${EVIDENCE_MD5:-}"
declare -g EVIDENCE_SHA1="${EVIDENCE_SHA1:-}"
declare -g EVIDENCE_SHA256="${EVIDENCE_SHA256:-}"

# Current case directory
declare -g CURRENT_CASE_DIR="${CURRENT_CASE_DIR:-}"

# Boot device detection (to exclude from output options)
declare -g BOOT_DEVICE="${BOOT_DEVICE:-}"

# ============================================================================
# Storage Detection Functions
# ============================================================================

# Detect available writable storage devices
# Arguments: evidence_device (device to exclude)
# Returns: List of available devices in format: device|size|label|type
detect_available_storage() {
    local evidence_device="${1:-}"

    # Extract base device from partition (e.g., /dev/sda1 -> /dev/sda)
    local evidence_base=""
    if [ -n "$evidence_device" ]; then
        evidence_base=$(echo "$evidence_device" | sed 's/[0-9]*$//')
    fi

    # Detect boot device if not set
    if [ -z "$BOOT_DEVICE" ]; then
        _detect_boot_device
    fi

    local storage_options=()

    # Get list of block devices
    local lsblk_output
    lsblk_output=$(lsblk -nrpo NAME,TYPE,FSTYPE,SIZE,RO,TYPE,MOUNTPOINT 2>/dev/null) || return 1

    while IFS=' ' read -r dev type fstype size ro devtype mount rest; do
        # Skip non-partition entries
        [[ "$type" != "part" ]] && continue

        # Skip if read-only
        [[ "$ro" == "1" ]] && continue

        # Skip evidence device and all its partitions
        if [ -n "$evidence_base" ]; then
            [[ "$dev" == "$evidence_base"* ]] && continue
        fi

        # Skip boot device
        if [ -n "$BOOT_DEVICE" ]; then
            local boot_base=$(echo "$BOOT_DEVICE" | sed 's/[0-9]*$//')
            [[ "$dev" == "$boot_base"* ]] && continue
        fi

        # Skip system mount points
        [[ "$mount" == "/" || "$mount" == "/boot"* || "$mount" == "/usr"* ]] && continue

        # Get label
        local label
        label=$(lsblk -no LABEL "$dev" 2>/dev/null) || label=""

        # Determine device type
        local device_type
        device_type=$(_classify_device "$dev" "$label")

        # Format: device|size|label|type
        storage_options+=("$dev|$size|${label:-unnamed}|$device_type")

    done <<< "$lsblk_output"

    # Output all options
    printf '%s\n' "${storage_options[@]}"
}

# Classify a device as persistence, removable, or internal
_classify_device() {
    local dev="$1"
    local label="$2"

    # Check for persistence partition
    if [[ "${label,,}" == "persistence" ]]; then
        echo "persistence"
        return
    fi

    # Check if removable
    if is_removable_device "$dev"; then
        echo "removable"
        return
    fi

    # Default to internal
    echo "internal"
}

# Check if a device is removable (USB, SD card, etc.)
is_removable_device() {
    local dev="$1"

    # Extract base device name (e.g., /dev/sdc1 -> sdc)
    local base_name
    base_name=$(basename "$dev" | sed 's/[0-9]*$//')

    # Check /sys/block for removable flag
    local removable_file="/sys/block/$base_name/removable"
    if [ -f "$removable_file" ]; then
        local removable
        removable=$(cat "$removable_file" 2>/dev/null)
        [[ "$removable" == "1" ]] && return 0
    fi

    # Check for USB in device path
    if readlink -f "/sys/block/$base_name" 2>/dev/null | grep -q "usb"; then
        return 0
    fi

    return 1
}

# Detect the boot device
_detect_boot_device() {
    # Try to find device containing /
    BOOT_DEVICE=$(findmnt -n -o SOURCE / 2>/dev/null) || true

    # If running from live ISO, try to find the ISO device
    if [ -z "$BOOT_DEVICE" ] || [ "$BOOT_DEVICE" = "overlay" ]; then
        # Look for live boot device
        if [ -f /run/live/medium/.disk/info ]; then
            BOOT_DEVICE=$(findmnt -n -o SOURCE /run/live/medium 2>/dev/null) || true
        fi
    fi
}

# ============================================================================
# Storage Setup Functions
# ============================================================================

# Setup output storage based on configuration
# Uses OUTPUT_DEVICE, USE_TMPFS_OUTPUT, or interactive selection
# Returns: 0 on success, 1 on failure
setup_output_storage() {
    # If tmpfs requested, use RAM
    if [ "$USE_TMPFS_OUTPUT" = "true" ]; then
        OUTPUT_TYPE="tmpfs"
        _setup_tmpfs_output
        return $?
    fi

    # If specific device provided, use it
    if [ -n "$OUTPUT_DEVICE" ]; then
        OUTPUT_TYPE="device"
        return 0  # Device will be mounted when needed
    fi

    # If specific path provided and writable
    if [ -n "$OUTPUT_PATH" ] && [ -w "$OUTPUT_PATH" ]; then
        OUTPUT_TYPE="path"
        OUTPUT_MOUNT_POINT="$OUTPUT_PATH"
        return 0
    fi

    # Try to auto-detect available storage
    local storage
    storage=$(detect_available_storage "$EVIDENCE_DEVICE")

    if [ -z "$storage" ]; then
        if [ "$INTERACTIVE_MODE" = "true" ]; then
            print_warning "No writable storage detected"
            print_warning "Plug in external USB or use --output-tmpfs for RAM storage"
        fi
        return 1
    fi

    # If interactive mode, would prompt user (not implemented in module)
    # For now, just take first available
    local first_device
    first_device=$(echo "$storage" | head -1 | cut -d'|' -f1)

    if [ -n "$first_device" ]; then
        OUTPUT_DEVICE="$first_device"
        OUTPUT_TYPE="device"
        return 0
    fi

    return 1
}

# Setup tmpfs (RAM-based) output
_setup_tmpfs_output() {
    OUTPUT_TYPE="tmpfs"
    OUTPUT_MOUNT_POINT="${OUTPUT_MOUNT_POINT:-/mnt/dms-output}"

    mkdir -p "$OUTPUT_MOUNT_POINT" 2>/dev/null || {
        # Try fallback location
        OUTPUT_MOUNT_POINT="/tmp/dms-output-$$"
        mkdir -p "$OUTPUT_MOUNT_POINT"
    }

    # Mount tmpfs if not already a tmpfs
    if ! mount | grep -q "$OUTPUT_MOUNT_POINT.*tmpfs"; then
        mount -t tmpfs -o size=1G tmpfs "$OUTPUT_MOUNT_POINT" 2>/dev/null || {
            # If mount fails (no root), just use the directory
            true
        }
    fi

    OUTPUT_MOUNTED=true
    return 0
}

# ============================================================================
# Device Mounting Functions
# ============================================================================

# Mount the output device
# Returns: 0 on success, 1 on failure
mount_output_device() {
    if [ -z "$OUTPUT_DEVICE" ]; then
        return 1
    fi

    # Create mount point
    mkdir -p "$OUTPUT_MOUNT_POINT" 2>/dev/null || {
        echo "Error: Cannot create mount point $OUTPUT_MOUNT_POINT" >&2
        return 1
    }

    # Check if already mounted
    if mount | grep -q "^$OUTPUT_DEVICE.*$OUTPUT_MOUNT_POINT"; then
        OUTPUT_MOUNTED=true
        return 0
    fi

    # Mount the device (read-write)
    if ! mount "$OUTPUT_DEVICE" "$OUTPUT_MOUNT_POINT" 2>/dev/null; then
        # Try with explicit rw option
        if ! mount -o rw "$OUTPUT_DEVICE" "$OUTPUT_MOUNT_POINT" 2>/dev/null; then
            echo "Error: Failed to mount $OUTPUT_DEVICE" >&2
            return 1
        fi
    fi

    OUTPUT_MOUNTED=true
    return 0
}

# Unmount the output device
unmount_output_device() {
    if [ "$OUTPUT_MOUNTED" != "true" ]; then
        return 0
    fi

    if [ -n "$OUTPUT_MOUNT_POINT" ]; then
        # Sync before unmount
        sync

        # Try to unmount
        if umount "$OUTPUT_MOUNT_POINT" 2>/dev/null; then
            OUTPUT_MOUNTED=false
            return 0
        else
            echo "Warning: Could not unmount $OUTPUT_MOUNT_POINT" >&2
            return 1
        fi
    fi

    return 0
}

# ============================================================================
# Validation Functions
# ============================================================================

# Validate that output storage is writable
# Returns: 0 if writable, 1 if not
validate_output_storage() {
    local test_file="$OUTPUT_MOUNT_POINT/.dms_write_test_$$"

    # Try to create a test file
    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        return 0
    fi

    return 1
}

# ============================================================================
# Case Directory Management
# ============================================================================

# Create case directory structure
# Returns: Path to case directory (stdout)
create_case_directory() {
    local case_base="${OUTPUT_MOUNT_POINT}/cases"
    local case_name="${CASE_NAME:-}"

    # Generate case name if not provided
    if [ -z "$case_name" ]; then
        case_name="case_$(date +%Y%m%d_%H%M%S)"
    fi

    local case_dir="$case_base/$case_name"

    # Create directory structure
    mkdir -p "$case_dir"
    mkdir -p "$case_dir/findings/malware_detections"
    mkdir -p "$case_dir/findings/suspicious_files"
    mkdir -p "$case_dir/findings/carved_files"
    mkdir -p "$case_dir/forensic_artifacts/persistence"
    mkdir -p "$case_dir/forensic_artifacts/execution"
    mkdir -p "$case_dir/forensic_artifacts/timeline"
    mkdir -p "$case_dir/logs/tool_output"

    # Store current case directory
    CURRENT_CASE_DIR="$case_dir"

    echo "$case_dir"
}

# Create evidence information file
# Arguments: case_directory
create_evidence_info() {
    local case_dir="$1"

    if [ -z "$case_dir" ] || [ ! -d "$case_dir" ]; then
        return 1
    fi

    local info_file="$case_dir/evidence_info.txt"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

    cat > "$info_file" << EOF
═══════════════════════════════════════════════════════════════════
DMS FORENSIC SCAN - EVIDENCE INFORMATION
═══════════════════════════════════════════════════════════════════

Case Created:     $timestamp
Examiner System:  $(hostname 2>/dev/null || echo "unknown")
DMS Version:      ${DMS_VERSION:-unknown}

EVIDENCE SOURCE
───────────────
Device:           ${EVIDENCE_DEVICE:-unknown}
Type:             ${EVIDENCE_TYPE:-unknown}
EOF

    # Add filesystem info if available
    if [ -n "$EVIDENCE_DEVICE" ] && [ -b "$EVIDENCE_DEVICE" ]; then
        local fs_type
        fs_type=$(blkid -o value -s TYPE "$EVIDENCE_DEVICE" 2>/dev/null) || fs_type="unknown"
        local fs_size
        fs_size=$(lsblk -ndo SIZE "$EVIDENCE_DEVICE" 2>/dev/null) || fs_size="unknown"

        cat >> "$info_file" << EOF
Filesystem:       $fs_type
Size:             $fs_size
EOF

        # Try to get serial number
        local serial
        local base_dev=$(echo "$EVIDENCE_DEVICE" | sed 's/[0-9]*$//')
        serial=$(udevadm info --query=property --name="$base_dev" 2>/dev/null | grep "ID_SERIAL=" | cut -d'=' -f2) || serial=""
        if [ -n "$serial" ]; then
            echo "Serial:           $serial" >> "$info_file"
        fi
    fi

    # Add integrity hashes if available
    if [ -n "$EVIDENCE_MD5" ] || [ -n "$EVIDENCE_SHA256" ]; then
        cat >> "$info_file" << EOF

INTEGRITY HASHES (pre-scan)
───────────────────────────
EOF
        [ -n "$EVIDENCE_MD5" ] && echo "MD5:              $EVIDENCE_MD5" >> "$info_file"
        [ -n "$EVIDENCE_SHA1" ] && echo "SHA1:             $EVIDENCE_SHA1" >> "$info_file"
        [ -n "$EVIDENCE_SHA256" ] && echo "SHA256:           $EVIDENCE_SHA256" >> "$info_file"
    fi

    # Add mount status
    cat >> "$info_file" << EOF

MOUNT STATUS
────────────
EOF

    # Check if evidence is mounted
    local evidence_mount
    evidence_mount=$(findmnt -n -o TARGET "$EVIDENCE_DEVICE" 2>/dev/null) || evidence_mount="Not mounted"
    local mount_opts
    mount_opts=$(findmnt -n -o OPTIONS "$EVIDENCE_DEVICE" 2>/dev/null) || mount_opts=""

    echo "Mounted:          ${evidence_mount:-Not mounted}" >> "$info_file"
    [ -n "$mount_opts" ] && echo "Mount Options:    $mount_opts" >> "$info_file"

    # Add output storage info
    cat >> "$info_file" << EOF

OUTPUT STORAGE
──────────────
Device:           ${OUTPUT_DEVICE:-${OUTPUT_TYPE:-unknown}}
EOF

    if [ -n "$OUTPUT_DEVICE" ]; then
        local out_label
        out_label=$(lsblk -no LABEL "$OUTPUT_DEVICE" 2>/dev/null) || out_label=""
        [ -n "$out_label" ] && echo "Label:            $out_label" >> "$info_file"
    fi

    echo "Mounted:          Read-write at $OUTPUT_MOUNT_POINT" >> "$info_file"

    # Footer
    cat >> "$info_file" << EOF
═══════════════════════════════════════════════════════════════════
EOF

    return 0
}

# ============================================================================
# Cleanup Functions
# ============================================================================

# Cleanup output storage on exit
cleanup_output_storage() {
    # Warn about tmpfs data loss
    if [ "$OUTPUT_TYPE" = "tmpfs" ]; then
        print_warning "WARNING: Output was stored in RAM (tmpfs)"
        print_warning "Data will be LOST when the system shuts down!"
        print_warning "Copy important files to persistent storage before shutdown."
    fi

    # Unmount if we mounted it
    if [ "$OUTPUT_MOUNTED" = "true" ] && [ "$OUTPUT_TYPE" = "device" ]; then
        echo "Unmounting output storage..."
        unmount_output_device
    fi
}

# ============================================================================
# Helper Functions
# ============================================================================

# Print warning message (can be overridden by main script)
print_warning() {
    if type -t print_message &>/dev/null; then
        print_message "warning" "$1"
    else
        echo "WARNING: $1" >&2
    fi
}

# Get storage summary for display
get_storage_summary() {
    echo "Output Storage Summary"
    echo "======================"
    echo "Type:        $OUTPUT_TYPE"
    echo "Device:      ${OUTPUT_DEVICE:-N/A}"
    echo "Mount Point: $OUTPUT_MOUNT_POINT"
    echo "Mounted:     $OUTPUT_MOUNTED"
    echo "Case Dir:    ${CURRENT_CASE_DIR:-Not created}"

    if [ "$OUTPUT_TYPE" = "tmpfs" ]; then
        echo ""
        echo "⚠️  WARNING: Using tmpfs - data will be lost on reboot!"
    fi
}

# ============================================================================
# Interactive Selection (placeholder for TUI integration)
# ============================================================================

# Display storage options for user selection
# This would be called from TUI - placeholder implementation
display_storage_options() {
    local evidence_device="$1"
    local storage_list

    storage_list=$(detect_available_storage "$evidence_device")

    if [ -z "$storage_list" ]; then
        echo "No writable storage detected."
        echo "Options:"
        echo "  1. Plug in external USB drive"
        echo "  2. Use --output-tmpfs for RAM storage (data lost on reboot)"
        echo "  3. Use --output-path to specify a writable directory"
        return 1
    fi

    echo "Available Output Storage:"
    echo "========================="

    local idx=1
    while IFS='|' read -r dev size label dtype; do
        local icon
        case "$dtype" in
            persistence) icon="💾" ;;
            removable)   icon="🔌" ;;
            internal)    icon="💿" ;;
            *)           icon="📁" ;;
        esac

        printf "  %d. %s %s (%s) - %s [%s]\n" "$idx" "$icon" "$dev" "$size" "$label" "$dtype"
        ((idx++))
    done <<< "$storage_list"

    echo ""
    echo "  $idx. RAM only (tmpfs) - ⚠️ Data lost on reboot"

    return 0
}
