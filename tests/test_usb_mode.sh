#!/bin/bash
# ============================================================================
# DMS USB Mode Test Suite
# ============================================================================
# Test specifications for USB kit detection, environment setup, and management
# Following TDD approach - write tests first, then implement
#
# Run with: ./tests/test_usb_mode.sh
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

    # Create mock DMS structure
    mkdir -p "$TEST_DIR/dms"
    mkdir -p "$TEST_DIR/dms/lib"
    mkdir -p "$TEST_DIR/dms/tools/bin"
    mkdir -p "$TEST_DIR/dms/databases/clamav"
    mkdir -p "$TEST_DIR/dms/databases/yara"
    mkdir -p "$TEST_DIR/dms/cache"

    # Copy actual lib files if they exist
    if [ -f "$DMS_ROOT/lib/usb_mode.sh" ]; then
        cp "$DMS_ROOT/lib/usb_mode.sh" "$TEST_DIR/dms/lib/"
    fi
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
# TEST SUITE: USB Mode Detection
# ============================================================================

test_detect_usb_environment_with_manifest() {
    # Given: Script running from directory with .dms_kit_manifest.json
    cat > "$TEST_DIR/.dms_kit_manifest.json" << 'EOF'
{
  "kit_version": "1.0.0",
  "mode": "full",
  "dms_version": "2.1"
}
EOF

    # Source the module
    if [ -f "$TEST_DIR/dms/lib/usb_mode.sh" ]; then
        source "$TEST_DIR/dms/lib/usb_mode.sh"

        # When: detect_usb_environment() is called
        DMS_SCRIPT_PATH="$TEST_DIR/dms/malware_scan.sh"
        detect_usb_environment

        # Then: USB_MODE=true, KIT_MANIFEST set, returns 0
        assert_equals "true" "$USB_MODE" "USB_MODE should be true"
        assert_file_exists "$KIT_MANIFEST" "KIT_MANIFEST should point to valid file"
    else
        # Module not yet implemented - test should fail
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_detect_usb_environment_without_manifest() {
    # Given: Script running from directory without manifest
    rm -f "$TEST_DIR/.dms_kit_manifest.json"

    if [ -f "$TEST_DIR/dms/lib/usb_mode.sh" ]; then
        source "$TEST_DIR/dms/lib/usb_mode.sh"

        # When: detect_usb_environment() is called
        DMS_SCRIPT_PATH="$TEST_DIR/dms/malware_scan.sh"
        local result=0
        detect_usb_environment || result=$?

        # Then: USB_MODE=false, returns 1
        assert_equals "false" "$USB_MODE" "USB_MODE should be false"
        assert_equals "1" "$result" "Should return 1 when no manifest"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_detect_kit_mode_full() {
    # Given: Manifest with mode="full", tools/ and databases/ exist
    cat > "$TEST_DIR/.dms_kit_manifest.json" << 'EOF'
{
  "kit_version": "1.0.0",
  "mode": "full",
  "dms_version": "2.1"
}
EOF

    # Ensure tools and databases exist
    touch "$TEST_DIR/dms/tools/bin/clamscan"
    touch "$TEST_DIR/dms/databases/clamav/main.cvd"

    if [ -f "$TEST_DIR/dms/lib/usb_mode.sh" ]; then
        source "$TEST_DIR/dms/lib/usb_mode.sh"

        DMS_SCRIPT_PATH="$TEST_DIR/dms/malware_scan.sh"
        detect_usb_environment

        # Then: KIT_MODE="full"
        assert_equals "full" "$KIT_MODE" "KIT_MODE should be full"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_detect_kit_mode_minimal() {
    # Given: Manifest with mode="minimal", no tools/
    cat > "$TEST_DIR/.dms_kit_manifest.json" << 'EOF'
{
  "kit_version": "1.0.0",
  "mode": "minimal",
  "dms_version": "2.1"
}
EOF

    # Remove tools directory
    rm -rf "$TEST_DIR/dms/tools"

    if [ -f "$TEST_DIR/dms/lib/usb_mode.sh" ]; then
        source "$TEST_DIR/dms/lib/usb_mode.sh"

        DMS_SCRIPT_PATH="$TEST_DIR/dms/malware_scan.sh"
        detect_usb_environment

        # Then: KIT_MODE="minimal"
        assert_equals "minimal" "$KIT_MODE" "KIT_MODE should be minimal"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

# ============================================================================
# TEST SUITE: USB Environment Setup
# ============================================================================

test_setup_usb_environment_full_mode() {
    # Given: USB_MODE=true, KIT_MODE="full"
    cat > "$TEST_DIR/.dms_kit_manifest.json" << 'EOF'
{
  "kit_version": "1.0.0",
  "mode": "full",
  "dms_version": "2.1"
}
EOF

    touch "$TEST_DIR/dms/tools/bin/clamscan"
    touch "$TEST_DIR/dms/databases/clamav/main.cvd"

    if [ -f "$TEST_DIR/dms/lib/usb_mode.sh" ]; then
        source "$TEST_DIR/dms/lib/usb_mode.sh"

        DMS_SCRIPT_PATH="$TEST_DIR/dms/malware_scan.sh"
        detect_usb_environment
        setup_usb_environment

        # Then: PATH includes tools/bin, CLAMDB_DIR points to databases/clamav
        assert_contains "$PATH" "$TEST_DIR/dms/tools/bin" "PATH should include tools/bin"
        assert_equals "$TEST_DIR/dms/databases/clamav" "$CLAMDB_DIR" "CLAMDB_DIR should point to bundled databases"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_setup_usb_environment_minimal_mode() {
    # Given: USB_MODE=true, KIT_MODE="minimal"
    cat > "$TEST_DIR/.dms_kit_manifest.json" << 'EOF'
{
  "kit_version": "1.0.0",
  "mode": "minimal",
  "dms_version": "2.1"
}
EOF

    rm -rf "$TEST_DIR/dms/tools"

    if [ -f "$TEST_DIR/dms/lib/usb_mode.sh" ]; then
        source "$TEST_DIR/dms/lib/usb_mode.sh"

        DMS_SCRIPT_PATH="$TEST_DIR/dms/malware_scan.sh"
        detect_usb_environment
        setup_usb_environment

        # Then: PORTABLE_MODE=true, PORTABLE_TOOLS_DIR set
        assert_equals "true" "$PORTABLE_MODE" "PORTABLE_MODE should be true"
        assert_true "[ -n \"\$PORTABLE_TOOLS_DIR\" ]" "PORTABLE_TOOLS_DIR should be set"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_setup_usb_environment_readonly_usb() {
    # Given: USB_MODE=true, USB would be read-only
    # (simulate by checking writable test)
    cat > "$TEST_DIR/.dms_kit_manifest.json" << 'EOF'
{
  "kit_version": "1.0.0",
  "mode": "minimal",
  "dms_version": "2.1"
}
EOF

    if [ -f "$TEST_DIR/dms/lib/usb_mode.sh" ]; then
        source "$TEST_DIR/dms/lib/usb_mode.sh"

        # Make USB_ROOT read-only for test
        chmod -w "$TEST_DIR/dms" 2>/dev/null || true

        DMS_SCRIPT_PATH="$TEST_DIR/dms/malware_scan.sh"
        detect_usb_environment
        setup_usb_environment

        # Restore permissions
        chmod +w "$TEST_DIR/dms" 2>/dev/null || true

        # Then: Falls back to /tmp for tool downloads
        assert_contains "$PORTABLE_TOOLS_DIR" "/tmp" "Should fall back to /tmp when USB read-only"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

# ============================================================================
# TEST SUITE: Kit Manifest Management
# ============================================================================

test_parse_manifest_valid_json() {
    # Given: Valid .dms_kit_manifest.json
    cat > "$TEST_DIR/.dms_kit_manifest.json" << 'EOF'
{
  "kit_version": "1.0.0",
  "created_date": "2026-01-21T00:00:00Z",
  "last_updated": "2026-01-21T00:00:00Z",
  "mode": "full",
  "dms_version": "2.1",
  "databases": {
    "clamav": {
      "version": "27500",
      "date": "2026-01-21"
    },
    "yara": {
      "qu1cksc0pe_date": "2026-01-21"
    }
  }
}
EOF

    if [ -f "$TEST_DIR/dms/lib/usb_mode.sh" ]; then
        source "$TEST_DIR/dms/lib/usb_mode.sh"

        # When: parse_kit_manifest() is called
        parse_kit_manifest "$TEST_DIR/.dms_kit_manifest.json"

        # Then: Returns kit_version, mode, database versions
        assert_equals "1.0.0" "$MANIFEST_KIT_VERSION" "kit_version should be 1.0.0"
        assert_equals "full" "$MANIFEST_MODE" "mode should be full"
        assert_equals "27500" "$MANIFEST_CLAMAV_VERSION" "clamav version should be 27500"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_parse_manifest_missing_file() {
    # Given: No manifest file
    rm -f "$TEST_DIR/.dms_kit_manifest.json"

    if [ -f "$TEST_DIR/dms/lib/usb_mode.sh" ]; then
        source "$TEST_DIR/dms/lib/usb_mode.sh"

        # When: parse_kit_manifest() is called
        local result=0
        parse_kit_manifest "$TEST_DIR/.dms_kit_manifest.json" || result=$?

        # Then: Returns error, sets defaults
        assert_equals "1" "$result" "Should return error for missing file"
        assert_equals "unknown" "$MANIFEST_KIT_VERSION" "Should set default kit_version"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_create_manifest_minimal() {
    # Given: Empty target directory
    local target="$TEST_DIR/new_kit"
    mkdir -p "$target/dms"

    if [ -f "$TEST_DIR/dms/lib/usb_mode.sh" ]; then
        source "$TEST_DIR/dms/lib/usb_mode.sh"

        # When: create_kit_manifest() with mode="minimal"
        create_kit_manifest "$target" "minimal"

        # Then: Creates valid JSON manifest with correct fields
        assert_file_exists "$target/.dms_kit_manifest.json" "Manifest should be created"

        local mode=$(grep -o '"mode": *"[^"]*"' "$target/.dms_kit_manifest.json" | cut -d'"' -f4)
        assert_equals "minimal" "$mode" "Mode should be minimal"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_create_manifest_full() {
    # Given: Directory with tools and databases
    local target="$TEST_DIR/full_kit"
    mkdir -p "$target/dms/tools/bin"
    mkdir -p "$target/dms/databases/clamav"
    touch "$target/dms/tools/bin/clamscan"
    touch "$target/dms/databases/clamav/main.cvd"

    if [ -f "$TEST_DIR/dms/lib/usb_mode.sh" ]; then
        source "$TEST_DIR/dms/lib/usb_mode.sh"

        # When: create_kit_manifest() with mode="full"
        create_kit_manifest "$target" "full"

        # Then: Creates manifest with mode=full
        assert_file_exists "$target/.dms_kit_manifest.json" "Manifest should be created"

        local mode=$(grep -o '"mode": *"[^"]*"' "$target/.dms_kit_manifest.json" | cut -d'"' -f4)
        assert_equals "full" "$mode" "Mode should be full"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

# ============================================================================
# TEST SUITE: Kit Update Mechanism
# ============================================================================

test_update_kit_no_network() {
    # Given: USB_MODE=true, no network connectivity (simulated)
    cat > "$TEST_DIR/.dms_kit_manifest.json" << 'EOF'
{"kit_version": "1.0.0", "mode": "full"}
EOF

    if [ -f "$DMS_ROOT/lib/update_manager.sh" ]; then
        source "$DMS_ROOT/lib/update_manager.sh"

        # Mock network check to fail
        check_network_connectivity() { return 1; }
        export -f check_network_connectivity

        USB_MODE=true
        USB_ROOT="$TEST_DIR"

        # When: update_usb_kit() is called
        local result=0
        update_usb_kit || result=$?

        # Then: Returns error, does not modify kit
        assert_equals "1" "$result" "Should return error with no network"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_update_kit_readonly_usb() {
    # Given: USB_MODE=true, network available, USB read-only
    cat > "$TEST_DIR/.dms_kit_manifest.json" << 'EOF'
{"kit_version": "1.0.0", "mode": "full"}
EOF

    if [ -f "$DMS_ROOT/lib/update_manager.sh" ]; then
        source "$DMS_ROOT/lib/update_manager.sh"

        # Mock network check to succeed
        check_network_connectivity() { return 0; }
        export -f check_network_connectivity

        USB_MODE=true
        USB_ROOT="$TEST_DIR"

        # Make read-only
        chmod -w "$TEST_DIR" 2>/dev/null || true

        # When: update_usb_kit() is called
        local result=0
        update_usb_kit || result=$?

        # Restore
        chmod +w "$TEST_DIR" 2>/dev/null || true

        # Then: Returns error with helpful message
        assert_equals "1" "$result" "Should return error when USB read-only"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

# ============================================================================
# TEST SUITE: Full Kit Builder
# ============================================================================

test_build_full_kit_insufficient_space() {
    # This test is difficult to simulate - skip for now
    # Given: Target with < 2GB free space
    # When: build_full_kit() is called
    # Then: Returns error, no partial files created

    if [ -f "$DMS_ROOT/lib/kit_builder.sh" ]; then
        source "$DMS_ROOT/lib/kit_builder.sh"

        # Mock disk space check
        get_available_space_mb() { echo "500"; }  # Only 500MB
        export -f get_available_space_mb

        local result=0
        build_full_kit "$TEST_DIR/insufficient_space_kit" || result=$?

        assert_equals "1" "$result" "Should fail with insufficient space"
        assert_false "[ -d \"$TEST_DIR/insufficient_space_kit/dms\" ]" "Should not create partial kit"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_build_full_kit_creates_structure() {
    # Given: Sufficient space, network available (simulated)
    if [ -f "$DMS_ROOT/lib/kit_builder.sh" ]; then
        source "$DMS_ROOT/lib/kit_builder.sh"

        # Mock functions for testing
        get_available_space_mb() { echo "10000"; }
        check_network_connectivity() { return 0; }
        download_portable_tools() { return 0; }
        download_databases() { return 0; }
        export -f get_available_space_mb check_network_connectivity download_portable_tools download_databases

        local target="$TEST_DIR/new_full_kit"

        # When: build_full_kit() is called
        build_full_kit "$target"

        # Then: Creates tools/, databases/, cache/ directories
        assert_dir_exists "$target/dms/tools" "tools/ should be created"
        assert_dir_exists "$target/dms/databases" "databases/ should be created"
        assert_dir_exists "$target/dms/cache" "cache/ should be created"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

test_build_full_kit_creates_manifest() {
    # Given: Completed kit build
    if [ -f "$DMS_ROOT/lib/kit_builder.sh" ]; then
        source "$DMS_ROOT/lib/kit_builder.sh"

        # Mock functions
        get_available_space_mb() { echo "10000"; }
        check_network_connectivity() { return 0; }
        download_portable_tools() { return 0; }
        download_databases() { return 0; }
        export -f get_available_space_mb check_network_connectivity download_portable_tools download_databases

        local target="$TEST_DIR/kit_with_manifest"

        # When: build_full_kit() finishes
        build_full_kit "$target"

        # Then: .dms_kit_manifest.json exists with mode="full"
        assert_file_exists "$target/.dms_kit_manifest.json" "Manifest should exist"

        local mode=$(grep -o '"mode": *"[^"]*"' "$target/.dms_kit_manifest.json" | cut -d'"' -f4)
        assert_equals "full" "$mode" "Manifest mode should be full"
    else
        echo "  (Module not implemented yet)"
        return 1
    fi
}

# ============================================================================
# TEST SUITE: CLI Integration
# ============================================================================

test_cli_update_kit_flag() {
    # Test that --update-kit flag is recognized by main script
    if [ -f "$DMS_ROOT/malware_scan.sh" ]; then
        # Check the script contains the flag handling
        if grep -q -- "--update-kit)" "$DMS_ROOT/malware_scan.sh"; then
            # Check DO_UPDATE_KIT is set to true
            if grep -q "DO_UPDATE_KIT=true" "$DMS_ROOT/malware_scan.sh"; then
                return 0
            fi
        fi
        echo "  Flag --update-kit not properly handled in main script"
        return 1
    else
        echo "  (Main script not found)"
        return 1
    fi
}

test_cli_build_full_kit_flag() {
    # Test that --build-full-kit flag is recognized by main script
    if [ -f "$DMS_ROOT/malware_scan.sh" ]; then
        # Check the script contains the flag handling
        if grep -q -- "--build-full-kit)" "$DMS_ROOT/malware_scan.sh"; then
            # Check DO_BUILD_KIT is set to true
            if grep -q "DO_BUILD_KIT=true" "$DMS_ROOT/malware_scan.sh"; then
                return 0
            fi
        fi
        echo "  Flag --build-full-kit not properly handled in main script"
        return 1
    else
        echo "  (Main script not found)"
        return 1
    fi
}

test_cli_kit_target_option() {
    # Test that --kit-target option is recognized by main script
    if [ -f "$DMS_ROOT/malware_scan.sh" ]; then
        # Check the script contains the option handling
        if grep -q -- "--kit-target)" "$DMS_ROOT/malware_scan.sh"; then
            # Check KIT_TARGET is being set
            if grep -q 'KIT_TARGET="\$2"' "$DMS_ROOT/malware_scan.sh"; then
                return 0
            fi
        fi
        echo "  Option --kit-target not properly handled in main script"
        return 1
    else
        echo "  (Main script not found)"
        return 1
    fi
}

# ============================================================================
# TEST SUITE: Launcher Script
# ============================================================================

test_launcher_sets_paths() {
    # Given: run-dms.sh executed from USB root
    if [ -f "$DMS_ROOT/run-dms.sh" ]; then
        # Source it in a subshell to capture variables
        (
            source "$DMS_ROOT/run-dms.sh" --dry-run 2>/dev/null || true

            assert_true "[ -n \"\$DMS_ROOT\" ]" "DMS_ROOT should be set"
            assert_true "[ -n \"\$DMS_TOOLS\" ]" "DMS_TOOLS should be set"
            assert_true "[ -n \"\$DMS_DATABASES\" ]" "DMS_DATABASES should be set"
        )
    else
        echo "  (Launcher not implemented yet)"
        return 1
    fi
}

test_launcher_adds_tools_to_path() {
    # Given: run-dms.sh executed
    if [ -f "$DMS_ROOT/run-dms.sh" ]; then
        (
            source "$DMS_ROOT/run-dms.sh" --dry-run 2>/dev/null || true

            assert_contains "$PATH" "tools/bin" "PATH should include tools/bin"
        )
    else
        echo "  (Launcher not implemented yet)"
        return 1
    fi
}

# ============================================================================
# Main Test Runner
# ============================================================================

print_header() {
    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  DMS USB Mode Test Suite${NC}"
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

    print_section "USB Mode Detection"
    run_test "detect_usb_environment_with_manifest" test_detect_usb_environment_with_manifest || true
    run_test "detect_usb_environment_without_manifest" test_detect_usb_environment_without_manifest || true
    run_test "detect_kit_mode_full" test_detect_kit_mode_full || true
    run_test "detect_kit_mode_minimal" test_detect_kit_mode_minimal || true

    print_section "USB Environment Setup"
    run_test "setup_usb_environment_full_mode" test_setup_usb_environment_full_mode || true
    run_test "setup_usb_environment_minimal_mode" test_setup_usb_environment_minimal_mode || true
    run_test "setup_usb_environment_readonly_usb" test_setup_usb_environment_readonly_usb || true

    print_section "Kit Manifest Management"
    run_test "parse_manifest_valid_json" test_parse_manifest_valid_json || true
    run_test "parse_manifest_missing_file" test_parse_manifest_missing_file || true
    run_test "create_manifest_minimal" test_create_manifest_minimal || true
    run_test "create_manifest_full" test_create_manifest_full || true

    print_section "Kit Update Mechanism"
    run_test "update_kit_no_network" test_update_kit_no_network || true
    run_test "update_kit_readonly_usb" test_update_kit_readonly_usb || true

    print_section "Full Kit Builder"
    run_test "build_full_kit_insufficient_space" test_build_full_kit_insufficient_space || true
    run_test "build_full_kit_creates_structure" test_build_full_kit_creates_structure || true
    run_test "build_full_kit_creates_manifest" test_build_full_kit_creates_manifest || true

    print_section "CLI Integration"
    run_test "cli_update_kit_flag" test_cli_update_kit_flag || true
    run_test "cli_build_full_kit_flag" test_cli_build_full_kit_flag || true
    run_test "cli_kit_target_option" test_cli_kit_target_option || true

    print_section "Launcher Script"
    run_test "launcher_sets_paths" test_launcher_sets_paths || true
    run_test "launcher_adds_tools_to_path" test_launcher_adds_tools_to_path || true

    print_summary

    # Exit with failure if any tests failed
    [ $TESTS_FAILED -eq 0 ]
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
