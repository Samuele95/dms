#!/bin/bash
# ============================================================================
# DMS Output Storage Test Suite
# ============================================================================
# Test specifications for output storage detection, selection, and management
# Following TDD approach - write tests first, then implement
#
# Run with: ./tests/test_output_storage.sh
# ============================================================================

set -euo pipefail

# Test framework colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory
TEST_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMS_ROOT="$(dirname "$SCRIPT_DIR")"

# ============================================================================
# Test Framework Functions
# ============================================================================

setup_test_environment() {
    TEST_DIR=$(mktemp -d)
    export TEST_DIR

    # Create mock mount points
    mkdir -p "$TEST_DIR/mnt/evidence"
    mkdir -p "$TEST_DIR/mnt/output"
    mkdir -p "$TEST_DIR/mnt/persistence"
}

teardown_test_environment() {
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [ "$expected" = "$actual" ]; then
        return 0
    else
        echo -e "  ${RED}ASSERT FAILED${NC}: Expected '$expected', got '$actual'"
        [ -n "$message" ] && echo "    $message"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-}"

    if eval "$condition"; then
        return 0
    else
        echo -e "  ${RED}ASSERT FAILED${NC}: Condition '$condition' is false"
        [ -n "$message" ] && echo "    $message"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-}"

    if ! eval "$condition"; then
        return 0
    else
        echo -e "  ${RED}ASSERT FAILED${NC}: Condition '$condition' is true (expected false)"
        [ -n "$message" ] && echo "    $message"
        return 1
    fi
}

assert_file_exists() {
    local filepath="$1"
    local message="${2:-}"

    if [ -f "$filepath" ]; then
        return 0
    else
        echo -e "  ${RED}ASSERT FAILED${NC}: File '$filepath' does not exist"
        [ -n "$message" ] && echo "    $message"
        return 1
    fi
}

assert_dir_exists() {
    local dirpath="$1"
    local message="${2:-}"

    if [ -d "$dirpath" ]; then
        return 0
    else
        echo -e "  ${RED}ASSERT FAILED${NC}: Directory '$dirpath' does not exist"
        [ -n "$message" ] && echo "    $message"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo -e "  ${RED}ASSERT FAILED${NC}: '$haystack' does not contain '$needle'"
        [ -n "$message" ] && echo "    $message"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    if [[ "$haystack" != *"$needle"* ]]; then
        return 0
    else
        echo -e "  ${RED}ASSERT FAILED${NC}: '$haystack' should not contain '$needle'"
        [ -n "$message" ] && echo "    $message"
        return 1
    fi
}

run_test() {
    local test_name="$1"
    local test_func="$2"

    ((TESTS_RUN++))
    echo -ne "  ${CYAN}TEST${NC}: $test_name ... "

    setup_test_environment

    local result=0
    if $test_func 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        result=1
    fi

    teardown_test_environment
    return $result
}

# ============================================================================
# TEST SUITE: Storage Detection
# ============================================================================

test_detect_available_storage() {
    # Given: System booted from live ISO
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        # Mock lsblk output
        mock_lsblk_output() {
            cat << 'EOF'
/dev/sda1 part ntfs 500G 0 part
/dev/sdb1 part ext4 16G 0 part
/dev/sdc1 part ext4 32G 0 part
EOF
        }

        lsblk() { mock_lsblk_output; }
        export -f lsblk

        # When: detect_available_storage() is called
        local storage=$(detect_available_storage "/dev/sda1")

        # Then: Returns list of writable non-evidence devices
        assert_not_contains "$storage" "/dev/sda" "Should exclude evidence device"
        assert_contains "$storage" "/dev/sdb1" "Should include available storage"
        assert_contains "$storage" "/dev/sdc1" "Should include available storage"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_detect_excludes_evidence_drive() {
    # Given: Scanning /dev/sda1
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        mock_lsblk_output() {
            cat << 'EOF'
/dev/sda1 part ntfs 200G 0 part
/dev/sda2 part ntfs 300G 0 part
/dev/sdb1 part ext4 32G 0 part
EOF
        }

        lsblk() { mock_lsblk_output; }
        export -f lsblk

        # When: detect_available_storage() is called with evidence device
        local storage=$(detect_available_storage "/dev/sda1")

        # Then: /dev/sda* excluded from storage options
        assert_not_contains "$storage" "/dev/sda1" "Should exclude evidence partition"
        assert_not_contains "$storage" "/dev/sda2" "Should exclude all evidence disk partitions"
        assert_contains "$storage" "/dev/sdb1" "Should include other devices"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_detect_identifies_persistence() {
    # Given: USB with persistence partition
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        # Mock lsblk with persistence partition
        mock_lsblk_output() {
            echo "/dev/sdb3 part ext4 8G 0 part "
        }

        # Mock label detection
        lsblk() {
            if [[ "$*" == *"LABEL"* ]]; then
                echo "persistence"
            else
                mock_lsblk_output
            fi
        }
        export -f lsblk

        # When: detect_available_storage() is called
        local storage=$(detect_available_storage "/dev/sda1")

        # Then: Persistence partition listed with "persistence" type
        assert_contains "$storage" "persistence" "Should identify persistence partition"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_detect_identifies_external_usb() {
    # Given: Second USB plugged in
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        # Mock removable detection
        is_removable_device() {
            [[ "$1" == "/dev/sdc"* ]] && return 0
            return 1
        }
        export -f is_removable_device

        mock_lsblk_output() {
            echo "/dev/sdc1 part ext4 64G 0 part "
        }

        lsblk() { mock_lsblk_output; }
        export -f lsblk

        # When: detect_available_storage() is called
        local storage=$(detect_available_storage "/dev/sda1")

        # Then: External USB listed with removable type
        assert_contains "$storage" "removable" "Should identify removable device"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_detect_identifies_internal_drive() {
    # Given: Internal drive available
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        is_removable_device() { return 1; }
        export -f is_removable_device

        mock_lsblk_output() {
            echo "/dev/sdb1 part ext4 500G 0 part "
        }

        lsblk() {
            if [[ "$*" == *"LABEL"* ]]; then
                echo "DATA"
            else
                mock_lsblk_output
            fi
        }
        export -f lsblk

        # When: detect_available_storage() is called
        local storage=$(detect_available_storage "/dev/sda1")

        # Then: Internal drive listed with internal type
        assert_contains "$storage" "internal" "Should identify internal device"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

# ============================================================================
# TEST SUITE: Storage Selection
# ============================================================================

test_select_output_cli() {
    # Given: --output-device /dev/sdc1 specified
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        # Mock mount
        mount() { echo "Mock mount: $*"; return 0; }
        export -f mount

        OUTPUT_DEVICE="/dev/sdc1"
        OUTPUT_MOUNT_POINT="$TEST_DIR/mnt/output"

        # When: setup_output_storage() is called
        setup_output_storage

        # Then: Uses specified device
        assert_equals "/dev/sdc1" "$OUTPUT_DEVICE" "Should use specified device"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_select_output_tmpfs() {
    # Given: --output-tmpfs specified
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        mount() { echo "Mock mount: $*"; return 0; }
        export -f mount

        USE_TMPFS_OUTPUT=true
        OUTPUT_MOUNT_POINT="$TEST_DIR/mnt/output"

        # When: setup_output_storage() is called
        setup_output_storage

        # Then: Uses tmpfs
        assert_equals "tmpfs" "$OUTPUT_TYPE" "Should use tmpfs"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

# ============================================================================
# TEST SUITE: Storage Mounting
# ============================================================================

test_mount_output_device_rw() {
    # Given: Selected output device
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        # Track mount call
        local mount_opts=""
        mount() {
            mount_opts="$*"
            # Create mount point if specified (handle missing args safely)
            local mp="${4:-$OUTPUT_MOUNT_POINT}"
            [ -n "$mp" ] && mkdir -p "$mp" 2>/dev/null || true
            return 0
        }
        export -f mount

        OUTPUT_DEVICE="/dev/sdc1"
        OUTPUT_MOUNT_POINT="$TEST_DIR/mnt/output"

        # When: mount_output_device() is called
        mount_output_device

        # Then: Mounted read-write
        assert_not_contains "$mount_opts" "-o ro" "Should not mount read-only"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_validate_output_writable() {
    # Given: Mounted output device
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        OUTPUT_MOUNT_POINT="$TEST_DIR/mnt/output"
        mkdir -p "$OUTPUT_MOUNT_POINT"
        chmod 755 "$OUTPUT_MOUNT_POINT"

        # When: validate_output_storage() is called
        local result=0
        validate_output_storage || result=$?

        # Then: Test write succeeds, returns true
        assert_equals "0" "$result" "Should validate writable storage"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_validate_output_not_writable() {
    # Given: Read-only mount point
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        OUTPUT_MOUNT_POINT="$TEST_DIR/mnt/readonly"
        mkdir -p "$OUTPUT_MOUNT_POINT"
        chmod 444 "$OUTPUT_MOUNT_POINT"

        # When: validate_output_storage() is called
        local result=0
        validate_output_storage || result=$?

        # Restore permissions for cleanup
        chmod 755 "$OUTPUT_MOUNT_POINT"

        # Then: Returns false
        assert_equals "1" "$result" "Should fail for read-only storage"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

# ============================================================================
# TEST SUITE: Case Directory Management
# ============================================================================

test_create_case_structure() {
    # Given: Valid output location
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        OUTPUT_MOUNT_POINT="$TEST_DIR/mnt/output"
        mkdir -p "$OUTPUT_MOUNT_POINT"

        # When: create_case_directory() is called
        local case_dir=$(create_case_directory)

        # Then: Creates case_YYYYMMDD_HHMMSS/ with proper structure
        assert_dir_exists "$case_dir" "Case directory should exist"
        assert_contains "$case_dir" "case_" "Should have case_ prefix"
        assert_dir_exists "$case_dir/findings" "findings/ should exist"
        assert_dir_exists "$case_dir/logs" "logs/ should exist"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_create_case_with_custom_name() {
    # Given: Custom case name specified
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        OUTPUT_MOUNT_POINT="$TEST_DIR/mnt/output"
        mkdir -p "$OUTPUT_MOUNT_POINT"
        CASE_NAME="incident_2026_001"

        # When: create_case_directory() is called
        local case_dir=$(create_case_directory)

        # Then: Uses custom name
        assert_contains "$case_dir" "incident_2026_001" "Should use custom case name"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_create_evidence_info_file() {
    # Given: Case directory created
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        OUTPUT_MOUNT_POINT="$TEST_DIR/mnt/output"
        mkdir -p "$OUTPUT_MOUNT_POINT"

        EVIDENCE_DEVICE="/dev/sda1"
        EVIDENCE_MD5="d41d8cd98f00b204e9800998ecf8427e"
        EVIDENCE_SHA256="e3b0c44298fc1c149afbf4c8996fb92427ae41e4"

        # When: create_evidence_info() is called
        local case_dir=$(create_case_directory)
        create_evidence_info "$case_dir"

        # Then: evidence_info.txt created with proper content
        assert_file_exists "$case_dir/evidence_info.txt" "evidence_info.txt should exist"

        local content=$(cat "$case_dir/evidence_info.txt")
        assert_contains "$content" "/dev/sda1" "Should contain evidence device"
        assert_contains "$content" "MD5" "Should contain MD5 hash"
        assert_contains "$content" "SHA256" "Should contain SHA256 hash"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_case_directory_structure() {
    # Given: Case created
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        OUTPUT_MOUNT_POINT="$TEST_DIR/mnt/output"
        mkdir -p "$OUTPUT_MOUNT_POINT"

        local case_dir=$(create_case_directory)

        # Then: All expected subdirectories exist
        assert_dir_exists "$case_dir/findings/malware_detections" "malware_detections should exist"
        assert_dir_exists "$case_dir/findings/suspicious_files" "suspicious_files should exist"
        assert_dir_exists "$case_dir/findings/carved_files" "carved_files should exist"
        assert_dir_exists "$case_dir/forensic_artifacts" "forensic_artifacts should exist"
        assert_dir_exists "$case_dir/logs/tool_output" "tool_output should exist"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

# ============================================================================
# TEST SUITE: Cleanup and Unmount
# ============================================================================

test_unmount_output_device() {
    # Given: Mounted output device
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        local unmount_called=false
        umount() { unmount_called=true; return 0; }
        export -f umount

        OUTPUT_MOUNT_POINT="$TEST_DIR/mnt/output"
        OUTPUT_DEVICE="/dev/sdc1"
        OUTPUT_MOUNTED=true

        # When: unmount_output_device() is called
        unmount_output_device

        # Then: Device is unmounted
        assert_true "$unmount_called" "Should call umount"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_warn_tmpfs_on_exit() {
    # Given: Using tmpfs output
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        OUTPUT_TYPE="tmpfs"
        local warning_shown=false

        # Mock print_warning
        print_warning() { warning_shown=true; }
        export -f print_warning

        # When: cleanup_output_storage() is called
        cleanup_output_storage

        # Then: Warning shown about data loss
        assert_true "$warning_shown" "Should warn about tmpfs data loss"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

# ============================================================================
# TEST SUITE: Error Handling
# ============================================================================

test_no_storage_available() {
    # Given: No writable storage detected
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        # Mock no storage
        detect_available_storage() { echo ""; }
        export -f detect_available_storage

        # When: setup_output_storage() called with no storage
        local result=0
        INTERACTIVE_MODE=false
        setup_output_storage || result=$?

        # Then: Returns error
        assert_equals "1" "$result" "Should return error when no storage"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_mount_failure_handling() {
    # Given: Mount fails
    if [ -f "$DMS_ROOT/lib/output_storage.sh" ]; then
        source "$DMS_ROOT/lib/output_storage.sh"

        mount() { return 1; }
        export -f mount

        OUTPUT_DEVICE="/dev/sdc1"
        OUTPUT_MOUNT_POINT="$TEST_DIR/mnt/output"

        # When: mount_output_device() fails
        local result=0
        mount_output_device || result=$?

        # Then: Error handled gracefully
        assert_equals "1" "$result" "Should return error on mount failure"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

# ============================================================================
# Main Test Runner
# ============================================================================

print_header() {
    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  DMS Output Storage Test Suite${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${YELLOW}▶ $1${NC}"
    echo "────────────────────────────────────────────────────────────────"
}

print_summary() {
    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  Test Summary${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "  ${GREEN}${BOLD}All tests passed!${NC}"
    else
        echo -e "  ${RED}${BOLD}Some tests failed.${NC}"
    fi
    echo ""
}

main() {
    print_header

    print_section "Storage Detection"
    run_test "detect_available_storage" test_detect_available_storage || true
    run_test "detect_excludes_evidence_drive" test_detect_excludes_evidence_drive || true
    run_test "detect_identifies_persistence" test_detect_identifies_persistence || true
    run_test "detect_identifies_external_usb" test_detect_identifies_external_usb || true
    run_test "detect_identifies_internal_drive" test_detect_identifies_internal_drive || true

    print_section "Storage Selection"
    run_test "select_output_cli" test_select_output_cli || true
    run_test "select_output_tmpfs" test_select_output_tmpfs || true

    print_section "Storage Mounting"
    run_test "mount_output_device_rw" test_mount_output_device_rw || true
    run_test "validate_output_writable" test_validate_output_writable || true
    run_test "validate_output_not_writable" test_validate_output_not_writable || true

    print_section "Case Directory Management"
    run_test "create_case_structure" test_create_case_structure || true
    run_test "create_case_with_custom_name" test_create_case_with_custom_name || true
    run_test "create_evidence_info_file" test_create_evidence_info_file || true
    run_test "case_directory_structure" test_case_directory_structure || true

    print_section "Cleanup and Unmount"
    run_test "unmount_output_device" test_unmount_output_device || true
    run_test "warn_tmpfs_on_exit" test_warn_tmpfs_on_exit || true

    print_section "Error Handling"
    run_test "no_storage_available" test_no_storage_available || true
    run_test "mount_failure_handling" test_mount_failure_handling || true

    print_summary

    # Exit with failure if any tests failed
    [ $TESTS_FAILED -eq 0 ]
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
