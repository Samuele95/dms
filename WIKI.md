# DMS Wiki - Technical Reference

> Complete technical documentation for DMS (Drive Malware Scan) v2.1

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Input Specifications](#3-input-specifications)
4. [Scanning Modules](#4-scanning-modules)
5. [Interactive Mode](#5-interactive-mode)
6. [Configuration Reference](#6-configuration-reference)
7. [CLI Reference](#7-cli-reference)
8. [Output Formats](#8-output-formats)
9. [Error Handling](#9-error-handling)
10. [Security & Forensic Integrity](#10-security--forensic-integrity)
11. [Dependencies](#11-dependencies)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Overview

### 1.1 Purpose and Scope

DMS (Drive Malware Scan) is an advanced malware detection and forensic analysis tool designed for digital forensics investigators and incident response teams. It provides comprehensive drive scanning capabilities using multiple detection engines and analysis techniques.

### 1.2 Target Environment

| Requirement | Specification |
|-------------|---------------|
| Primary Platform | Tsurugi Linux |
| Compatible Systems | Debian/Ubuntu, Fedora/RHEL, Arch Linux |
| Required Privileges | Root access for block device operations |
| Shell Requirements | Bash 4.0+ with associative array support |
| Terminal | 80+ columns recommended, Unicode support for TUI |

### 1.3 Key Metrics

| Metric | Value |
|--------|-------|
| Script Size | ~4,850 lines of Bash |
| Scanning Engines | 12+ integrated techniques |
| Configuration Parameters | 30+ tunable options |
| YARA Rule Categories | 4 (Windows, Linux, Android, Documents) |
| Report Formats | 3 (Text, HTML, JSON) |
| Supported Image Formats | 3 (Block Device, EWF, Raw) |

### 1.4 Design Principles

- **Forensic Integrity**: Read-only operations preserve evidence
- **Portable**: Zero-dependency mode downloads tools automatically
- **Comprehensive**: Multiple detection engines in one tool
- **User-Friendly**: Interactive TUI for guided operation
- **Actionable**: Reports include prioritized recommendations

---

## 2. Architecture

### 2.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         DMS v2.1                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Input     │  │   Config    │  │   CLI / Interactive     │ │
│  │  Handler    │  │   Loader    │  │        Parser           │ │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘ │
│         │                │                     │               │
│         └────────────────┴─────────────────────┘               │
│                          │                                      │
│  ┌───────────────────────▼───────────────────────────────────┐ │
│  │                   Scan Orchestrator                        │ │
│  │  • Sequential or Parallel execution                        │ │
│  │  • Checkpoint/Resume support                               │ │
│  │  • Graceful error handling                                 │ │
│  └───────────────────────┬───────────────────────────────────┘ │
│                          │                                      │
│  ┌───────────────────────▼───────────────────────────────────┐ │
│  │                   Scanning Modules                         │ │
│  │ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │ │
│  │ │ ClamAV  │ │  YARA   │ │ Binwalk │ │ Strings │           │ │
│  │ │ 1M+ sig │ │ 4 cats  │ │firmware │ │  IOCs   │           │ │
│  │ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │ │
│  │ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │ │
│  │ │ Entropy │ │ Carving │ │  Bulk   │ │ Hashes  │           │ │
│  │ │ >7.5/8  │ │foremost │ │Extractor│ │MD5/SHA  │           │ │
│  │ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │ │
│  │ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │ │
│  │ │BootSect │ │ Slack   │ │VirusT. │ │ Rootkit │           │ │
│  │ │  MBR    │ │ Space   │ │  API    │ │chkroot  │           │ │
│  │ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │ │
│  └───────────────────────────────────────────────────────────┘ │
│                          │                                      │
│  ┌───────────────────────▼───────────────────────────────────┐ │
│  │                  Report Generator                          │ │
│  │  • Text report with ASCII formatting                       │ │
│  │  • HTML report with styling                                │ │
│  │  • JSON report for automation                              │ │
│  │  • Actionable guidance with priorities                     │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow

```
Input (Device/Image)
        │
        ▼
┌───────────────────┐
│  Input Validation │
│  & Type Detection │───► Auto-detect: block / ewf / raw
└─────────┬─────────┘     Mount EWF if needed
          │
          ▼
┌───────────────────┐
│  Chunked Reading  │───► Split into CHUNK_SIZE MB segments
└─────────┬─────────┘     (Default: 500MB per chunk)
          │
          ▼
┌───────────────────┐       ┌─────────────────────────┐
│  Mode Selection   │       │  FULL MODE              │
│                   │──────►│  • Entire device        │
│  full | slack     │       │  • All allocated data   │
└─────────┬─────────┘       └─────────────────────────┘
          │                 ┌─────────────────────────┐
          └────────────────►│  SLACK MODE             │
                            │  • Unallocated only     │
                            │  • Deleted file recovery│
                            └─────────────────────────┘
          │
          ▼
┌───────────────────┐       ┌─────────────────────────┐
│  Scan Execution   │──────►│ PARALLEL (if enabled)   │
│                   │       │ • ClamAV ──┐            │
│                   │       │ • YARA ────┼─► Faster   │
│                   │       │ • Binwalk ─┤            │
│                   │       │ • Strings ─┘            │
└─────────┬─────────┘       └─────────────────────────┘
          │
          ▼
┌───────────────────┐
│ Result Aggregation│───► Collect all findings
│ + Guidance Gen    │     Generate recommendations
└─────────┬─────────┘     Prioritize by severity
          │
          ▼
┌───────────────────┐
│  Report Output    │───► Text + HTML + JSON
└───────────────────┘
```

### 2.3 Module Responsibilities

| Module | Responsibility | Key Functions |
|--------|----------------|---------------|
| Input Handler | Validates input, detects type, mounts EWF | `validate_device()`, `detect_input_type()` |
| Config Loader | Loads settings with override precedence | `load_config()` |
| Scan Orchestrator | Coordinates execution, handles errors | `run_scan()`, `run_parallel_scans()` |
| ClamAV Scanner | Signature-based malware detection | `scan_clamav()` |
| YARA Scanner | Pattern-based threat detection | `scan_yara()`, `scan_yara_category()` |
| Binwalk Scanner | Embedded file analysis | `scan_binwalk()` |
| Strings Analyzer | IOC extraction | `scan_strings()` |
| Entropy Analyzer | Encrypted/packed detection | `scan_entropy()` |
| File Carver | Deleted file recovery | `scan_file_carving()` |
| Bulk Extractor | Artifact extraction | `scan_bulk_extractor()` |
| Slack Extractor | Unallocated space analysis | `extract_slack_space()` |
| Report Generator | Formatted output generation | `generate_report()`, `generate_html_report()`, `generate_json_report()` |

---

## 3. Input Specifications

### 3.1 Supported Formats

| Format | Extensions | Description | Auto-Detected |
|--------|------------|-------------|---------------|
| Block Device | `/dev/sdX`, `/dev/nvmeXnY` | Physical drives and partitions | Yes |
| EWF Image | `.E01`, `.E02`, `.Ex01`, `.L01`, `.Lx01` | Expert Witness Format forensic images | Yes |
| Raw Image | `.raw`, `.dd`, `.img`, `.bin` | Raw disk dumps | Yes |

### 3.2 Auto-Detection Algorithm

```bash
# Pseudocode for input type detection
function detect_input_type(path):
    if is_block_device(path):
        return "block_device"

    if is_regular_file(path):
        extension = get_extension(path)

        if extension matches /\.[EL](x)?[0-9]+$/i:
            return "ewf"

        if extension in [".raw", ".dd", ".img", ".bin"]:
            return "raw_image"

    return "unknown"
```

### 3.3 EWF Image Handling

When an EWF image is detected:

1. **Segment Discovery**: Locates all segments (`.E01`, `.E02`, etc.)
2. **Metadata Extraction**: Uses `ewfinfo` to extract:
   - Total media size
   - Stored MD5/SHA1 hashes
   - Acquisition date
   - Case number
   - Examiner name
3. **Hash Verification** (if `--verify-hash`): Runs `ewfverify`
4. **Virtual Mount**: Uses `ewfmount` to create virtual block device
5. **Scan Execution**: Scans virtual device
6. **Cleanup**: Unmounts on completion or error

### 3.4 EWF Metadata Fields

| Field | Source | Description |
|-------|--------|-------------|
| `EWF_TOTAL_SIZE` | ewfinfo | Original media size |
| `EWF_HASH_MD5` | ewfinfo | Stored MD5 hash |
| `EWF_HASH_SHA1` | ewfinfo | Stored SHA1 hash |
| `EWF_ACQUISITION_DATE` | ewfinfo | When image was created |
| `EWF_CASE_NUMBER` | ewfinfo | Associated case ID |

---

## 4. Scanning Modules

### 4.1 Module Overview

| Module | Function | Deep Only | Parallel | Required Tool |
|--------|----------|-----------|----------|---------------|
| ClamAV | `scan_clamav()` | No | Yes | clamscan |
| YARA | `scan_yara()` | No | Yes | yara |
| Binwalk | `scan_binwalk()` | No | Yes | binwalk |
| Strings | `scan_strings()` | No | Yes | strings |
| Quick Scan | `scan_quick()` | No | No | - |
| VirusTotal | `scan_virustotal()` | No | No | curl |
| Rootkit | `scan_rootkit()` | No | No | chkrootkit/rkhunter |
| Entropy | `scan_entropy()` | Yes | No | - |
| File Carving | `scan_file_carving()` | Yes | No | foremost |
| Executables | `scan_executables()` | Yes | No | - |
| Boot Sector | `scan_boot_sector()` | Yes | No | xxd |
| Bulk Extractor | `scan_bulk_extractor()` | Yes | No | bulk_extractor |
| Hashes | `scan_hashes()` | Yes | No | md5deep |
| Slack Space | `extract_slack_space()` | Slack Mode | No | blkls |

### 4.2 ClamAV Integration

**Purpose**: Signature-based malware detection using 1M+ signatures

| Parameter | Value |
|-----------|-------|
| Database Directory | `CLAMDB_DIR` (default: `/tmp/clamdb`) |
| Update Command | `freshclam` (with `--update` flag) |
| Scan Method | Chunked data via stdin |

**Output Tracked**:
- `STATS[clamav_scanned]`: Bytes scanned
- `STATS[clamav_infected]`: Infected count
- `STATS[clamav_signatures]`: Matched signature names

### 4.3 YARA Rule Engine

**Purpose**: Pattern-based threat detection with custom rules

| Category | Location | Target Threats |
|----------|----------|----------------|
| Windows | `$YARA_RULES_BASE/Windows/` | PE malware, ransomware, trojans, RATs |
| Linux | `$YARA_RULES_BASE/Linux/` | ELF threats, rootkits, backdoors, miners |
| Android | `$YARA_RULES_BASE/Android/` | APK malware, adware, spyware |
| Documents | `$OLEDUMP_RULES/` | Office macros, PDF exploits |

**Output Tracked**:
- `STATS[yara_rules_checked]`: Rules evaluated
- `STATS[yara_matches]`: Total matches
- `STATS[yara_match_details]`: Rule name, offset, match string

### 4.4 Entropy Analysis

**Purpose**: Detect encrypted, compressed, or packed data

| Parameter | Value |
|-----------|-------|
| Block Size | 1 MB |
| High Threshold | > 7.5 (out of 8.0 maximum) |
| Calculation | Shannon entropy per block |

**Entropy Interpretation**:
| Range | Meaning | Examples |
|-------|---------|----------|
| 0-2 | Very low | Sparse files, null blocks |
| 2-5 | Low-medium | Text files, source code |
| 5-7 | Medium-high | Executables, some data |
| 7-7.5 | High | Compressed archives |
| 7.5-8 | Very high | Encrypted data, packed malware |

### 4.5 File Carving

**Purpose**: Recover deleted files from raw disk data

| Parameter | Default |
|-----------|---------|
| Primary Tool | foremost |
| Alternative Tools | scalpel, photorec |
| Max Files | `MAX_CARVED_FILES` (1000) |

**Supported Carved Types**:
| Category | Extensions |
|----------|------------|
| Executables | exe, dll, elf |
| Documents | pdf, doc, docx, xls, xlsx, ppt |
| Images | jpg, png, gif, bmp, tiff |
| Archives | zip, rar, 7z, gz, tar |
| Media | mp3, mp4, avi, mov |

### 4.6 Slack Space Extraction

**Purpose**: Analyze unallocated disk space for hidden/deleted data

| Parameter | Default |
|-----------|---------|
| Extraction Tool | `blkls` (sleuthkit) |
| Timeout | `SLACK_EXTRACT_TIMEOUT` (600 seconds) |
| Minimum Size | `SLACK_MIN_SIZE_MB` (10 MB) |

**Process**:
1. Extract unallocated space with `blkls`
2. Save to temporary file
3. Run carving tools on extracted data
4. Scan recovered files with all engines
5. Report findings with recovery location

### 4.7 Boot Sector Analysis

**Purpose**: Detect bootkits and MBR infections

**Checks Performed**:
- MBR signature validation (55 AA)
- PE header detection in boot sector
- Known bootkit patterns
- Partition table integrity

---

## 5. Interactive Mode

### 5.1 Overview

Interactive mode provides a full-screen TUI (Text User Interface) for configuring and running scans without command-line expertise.

**Launch**: `sudo ./malware_scan.sh --interactive` or `-i`

### 5.2 TUI Layout

```
╔══════════════════════════════════════════════════════════════════════╗
║               DMS - DRIVE MALWARE SCAN                               ║
║        Use ↑↓ to navigate, Space/Enter to toggle, S to start         ║
╠══════════════════════════════════════════════════════════════════════╣
║  INPUT SOURCE                                                        ║
╟──────────────────────────────────────────────────────────────────────╢
║▶ Path: (press Enter/I to set path)                                   ║
╟──────────────────────────────────────────────────────────────────────╢
║  SCAN TYPE                                                           ║
╟──────────────────────────────────────────────────────────────────────╢
║  ( ) Quick Scan       Fast sample-based analysis                     ║
║  (●) Standard Scan    ClamAV + YARA + Strings + Binwalk              ║
║  ( ) Deep Scan        All scanners + entropy + carving               ║
╟──────────────────────────────────────────────────────────────────────╢
║  SCAN SCOPE                                                          ║
╟──────────────────────────────────────────────────────────────────────╢
║  (●) Full Drive       Scan entire device including all data          ║
║  ( ) Slack Space      Scan only unallocated/deleted areas            ║
╟──────────────────────────────────────────────────────────────────────╢
║  OPTIONS                                                             ║
╟──────────────────────────────────────────────────────────────────────╢
║  [ ] Mount device before scanning                                    ║
║  [ ] Update ClamAV databases                                         ║
║  [ ] Parallel scanning mode                                          ║
║  [ ] Auto-calculate chunk size                                       ║
║  [ ] Verify EWF hash before scan (forensic integrity)                ║
╟──────────────────────────────────────────────────────────────────────╢
║  ADDITIONAL FEATURES                                                 ║
╟──────────────────────────────────────────────────────────────────────╢
║  [ ] VirusTotal hash lookup (requires API key)                       ║
║  [ ] Rootkit detection (requires mount)                              ║
║  [ ] Generate file timeline                                          ║
╟──────────────────────────────────────────────────────────────────────╢
║  OUTPUT                                                              ║
╟──────────────────────────────────────────────────────────────────────╢
║  [ ] Generate HTML report                                            ║
║  [ ] Generate JSON report                                            ║
║  [ ] Keep output directory after scan                                ║
╠══════════════════════════════════════════════════════════════════════╣
║      [S] Start Scan    [I] Set Input Path    [Q] Quit                ║
╚══════════════════════════════════════════════════════════════════════╝
```

### 5.3 Keyboard Controls

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate between menu items |
| `Space` | Toggle checkbox / Select radio option |
| `Enter` | Toggle option or open input dialog |
| `S` | Start scan with current configuration |
| `I` | Open input path dialog |
| `Q` / `Esc` | Quit interactive mode |
| `1` | Select Quick Scan |
| `2` | Select Standard Scan |
| `3` | Select Deep Scan |

### 5.4 Menu Sections

| Section | Items | Type |
|---------|-------|------|
| Input Source | Path | Text input |
| Scan Type | Quick, Standard, Deep | Radio (single select) |
| Scan Scope | Full Drive, Slack Space | Radio (single select) |
| Options | Mount, Update, Parallel, Auto-chunk, Verify hash | Checkboxes |
| Additional Features | VirusTotal, Rootkit, Timeline | Checkboxes |
| Output | HTML, JSON, Keep output | Checkboxes |

### 5.5 Input Path Dialog

When setting input path, the TUI shows:
- Available block devices via `lsblk`
- Examples of valid paths
- Auto-detection of input type after entry
- EWF-specific suggestions (verify hash)

---

## 6. Configuration Reference

### 6.1 Configuration File Locations

Search order (first found is used):
1. `~/.malscan.conf` (user config)
2. `/etc/malscan.conf` (system config)
3. `./malscan.conf` (local config)

### 6.2 Override Precedence

```
Command-line arguments  ← Highest priority
        ↓
Environment variables
        ↓
Configuration file
        ↓
Built-in defaults       ← Lowest priority
```

### 6.3 Complete Parameter Reference

#### Performance Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `CHUNK_SIZE` | integer | `500` | MB per chunk for scanning |
| `MAX_PARALLEL_JOBS` | integer | `4` | Parallel scan threads |

#### Path Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `CLAMDB_DIR` | path | `/tmp/clamdb` | ClamAV database directory |
| `YARA_RULES_BASE` | path | `/opt/Qu1cksc0pe/Systems` | YARA rules base |
| `OLEDUMP_RULES` | path | `/opt/oledump` | Document analysis rules |
| `YARA_CACHE_DIR` | path | `/tmp/yara_cache` | Compiled rules cache |
| `PORTABLE_TOOLS_DIR` | path | `/tmp/malscan_portable_tools` | Portable tools location |
| `TEMP_MOUNT_BASE` | path | `/tmp` | Temp mount base directory |

#### VirusTotal Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `VT_API_KEY` | string | (empty) | VirusTotal API key |
| `VT_RATE_LIMIT` | integer | `4` | Requests per minute |

#### EWF Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `EWF_SUPPORT` | boolean | `true` | Enable EWF support |
| `EWF_VERIFY_HASH` | boolean | `false` | Always verify hash |
| `EWF_MOUNT_OPTIONS` | string | (empty) | Additional ewfmount options |

#### Slack Space Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `DEFAULT_SCAN_MODE` | enum | `full` | Default mode: full or slack |
| `SLACK_EXTRACT_TIMEOUT` | integer | `600` | Extraction timeout (seconds) |
| `SLACK_MIN_SIZE_MB` | integer | `10` | Minimum slack size to analyze |
| `MAX_CARVED_FILES` | integer | `1000` | Maximum files to carve |
| `CARVING_TOOLS` | string | `foremost` | Comma-separated carving tools |

#### Logging Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `LOG_LEVEL` | enum | `INFO` | DEBUG, INFO, WARNING, ERROR |

#### Display Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `NO_COLOR` | boolean | `false` | Disable colored output |
| `HIGH_CONTRAST` | boolean | `false` | Bold text only mode |

#### Portable Mode Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `YARA_VERSION` | string | `4.5.0` | YARA version for download |
| `CLAMAV_VERSION` | string | `1.3.1` | ClamAV version for download |

### 6.4 Example Configuration File

```bash
# ~/.malscan.conf - DMS Configuration

# ============================================
# Performance
# ============================================
CHUNK_SIZE=500
MAX_PARALLEL_JOBS=4

# ============================================
# Tool Paths
# ============================================
CLAMDB_DIR=/tmp/clamdb
YARA_RULES_BASE=/opt/Qu1cksc0pe/Systems
OLEDUMP_RULES=/opt/oledump

# ============================================
# VirusTotal (get key at virustotal.com)
# ============================================
# VT_API_KEY=your_api_key_here
VT_RATE_LIMIT=4

# ============================================
# Forensic Settings
# ============================================
EWF_SUPPORT=true
EWF_VERIFY_HASH=false

# ============================================
# Slack Space
# ============================================
SLACK_EXTRACT_TIMEOUT=600
SLACK_MIN_SIZE_MB=10
MAX_CARVED_FILES=1000

# ============================================
# Logging
# ============================================
LOG_LEVEL=INFO
```

---

## 7. CLI Reference

### 7.1 Synopsis

```
malware_scan.sh <input> [options]
malware_scan.sh --interactive [--portable]
malware_scan.sh -i
```

### 7.2 Complete Options

#### Primary Options

| Option | Short | Description |
|--------|-------|-------------|
| `--interactive` | `-i` | Launch interactive TUI mode |
| `--portable` | | Auto-download missing tools |
| `--portable-keep` | | Keep portable tools after scan |
| `--portable-dir DIR` | | Custom portable tools directory |

#### Basic Options

| Option | Short | Description |
|--------|-------|-------------|
| `--mount` | `-m` | Mount device before scanning |
| `--update` | `-u` | Update ClamAV databases |
| `--deep` | `-d` | Enable deep scan mode |
| `--output FILE` | `-o` | Output report file path |
| `--help` | `-h` | Show help message |

#### Image Support

| Option | Description |
|--------|-------------|
| `--verify-hash` | Verify EWF hash before scanning |
| `--input-format TYPE` | Force input type: auto, block, ewf, raw |

#### Scan Scope

| Option | Description |
|--------|-------------|
| `--scan-mode MODE` | Scan mode: full or slack |
| `--slack` | Shortcut for `--scan-mode slack` |

#### Performance

| Option | Short | Description |
|--------|-------|-------------|
| `--parallel` | `-p` | Enable parallel scanning |
| `--auto-chunk` | | Auto-calculate optimal chunk size |
| `--quick` | | Quick scan mode (sample-based) |

#### Features

| Option | Description |
|--------|-------------|
| `--virustotal` | Enable VirusTotal hash lookup |
| `--rootkit` | Run rootkit detection |
| `--timeline` | Generate file timeline |
| `--resume FILE` | Resume from checkpoint file |

#### Output

| Option | Short | Description |
|--------|-------|-------------|
| `--html` | | Generate HTML report |
| `--json` | | Generate JSON report |
| `--quiet` | `-q` | Quiet mode (minimal output) |
| `--verbose` | `-v` | Verbose mode (debug output) |

#### Display

| Option | Description |
|--------|-------------|
| `--no-color` | Disable colored output |
| `--high-contrast` | High visibility mode |

#### Advanced

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview actions without executing |
| `--config FILE` | Use custom configuration file |
| `--log-file FILE` | Write logs to file |
| `--keep-output` | Keep temporary output directory |

### 7.3 Exit Codes

| Code | Name | Description |
|------|------|-------------|
| `0` | SUCCESS | Scan completed successfully |
| `1` | ERROR | Scan failed or invalid arguments |
| `130` | INTERRUPTED | Received SIGINT (Ctrl+C) |
| `143` | TERMINATED | Received SIGTERM |

### 7.4 Usage Examples

```bash
# Interactive mode (recommended)
sudo ./malware_scan.sh --interactive

# Interactive with portable tools
sudo ./malware_scan.sh --interactive --portable

# Basic scan
sudo ./malware_scan.sh /dev/sdb1

# Deep scan with parallel processing
sudo ./malware_scan.sh /dev/sdb1 --deep --parallel

# Forensic image with hash verification
sudo ./malware_scan.sh evidence.E01 --verify-hash --deep

# Slack space analysis
sudo ./malware_scan.sh /dev/sdb1 --slack

# Generate all report formats
sudo ./malware_scan.sh /dev/sdb1 --html --json

# Field operation (portable + keep tools)
sudo ./malware_scan.sh /dev/sdb1 --portable --portable-keep
```

---

## 8. Output Formats

### 8.1 Text Report

Human-readable ASCII report generated by default.

**Structure**:
```
═══════════════════════════════════════════════════════════════
              TSURUGI LINUX MALWARE SCAN REPORT
              Generated: <timestamp>
═══════════════════════════════════════════════════════════════

DEVICE INFORMATION
──────────────────
Device:     <path>
Size:       <size> GB
Filesystem: <type>
Scan Type:  STANDARD | DEEP SCAN
Parallel:   YES | NO

SCAN RESULTS
────────────
Basic Scans:
  ClamAV:              <count> infected
  YARA Windows:        <count> matches
  YARA Linux:          <count> matches
  YARA Android:        <count> matches
  YARA Documents:      <count> matches
  Binwalk:             <count> findings
  String Analysis:     <count> patterns

[Deep Scan Results if enabled]

RECOMMENDED ACTIONS
───────────────────
1. <CATEGORY> (<priority> priority)
   Reason: <description>
   Action: <recommendation>
   Files:  <location>

OVERALL STATUS
──────────────
STATUS: CLEAN | SUSPICIOUS
Total findings: <count>
```

### 8.2 HTML Report

Professional styled web page for sharing.

**Generated**: `scan_report_YYYYMMDD_HHMMSS.html`

**Features**:
- Responsive design
- Color-coded findings
- Expandable sections
- Summary banner
- Statistics tables

### 8.3 JSON Report

Machine-readable format for automation.

**Schema**:
```json
{
    "report": {
        "version": "2.1",
        "generated": "<ISO8601>",
        "tool": "DMS - Drive Malware Scanner"
    },
    "device": {
        "path": "<string>",
        "size_gb": <number>,
        "filesystem": "<string>"
    },
    "scan_config": {
        "mode": "full | slack",
        "type": "standard | deep",
        "parallel": <boolean>,
        "quick": <boolean>,
        "chunk_size_mb": <number>
    },
    "results": {
        "clamav": <number>,
        "yara_windows": <number>,
        "yara_linux": <number>,
        "yara_android": <number>,
        "yara_documents": <number>,
        "binwalk": <number>,
        "strings": <number>,
        "entropy": <number>,
        "carved_files": <number>,
        "carved_malware": <number>,
        "pe_executables": <number>,
        "elf_executables": <number>,
        "boot_sector": <number>,
        "virustotal": <number>,
        "rootkit": <number>
    },
    "statistics": {
        "clamav_scanned": <number>,
        "clamav_infected": <number>,
        "yara_rules_checked": <number>,
        "yara_matches": <number>,
        "strings_total": <number>,
        "strings_urls": <number>,
        "entropy_regions_scanned": <number>,
        "entropy_high_count": <number>,
        "carved_total": <number>,
        "carved_executables": <number>,
        "slack_size_mb": <number>,
        "slack_files_recovered": <number>,
        "pe_headers": <number>,
        "elf_headers": <number>,
        "bulk_emails": <number>,
        "bulk_urls": <number>
    },
    "summary": {
        "total_findings": <number>,
        "items_to_review": <number>
    },
    "output_directory": "<path>"
}
```

---

## 9. Error Handling

### 9.1 Error Categories

| Category | Examples | Default Action |
|----------|----------|----------------|
| INPUT | Invalid path, missing file | Exit with code 1 |
| PERMISSION | Access denied | Exit with code 1 |
| TOOL | Missing required tool | Exit (or use --portable) |
| SCAN | Module failure | Mark failed, continue others |
| EWF | Mount failure, hash mismatch | Exit with code 1 |
| TIMEOUT | Scan exceeded time limit | Record partial results |

### 9.2 Graceful Degradation

| Condition | Behavior |
|-----------|----------|
| Missing deep scan tools | Skip deep scan, complete basic |
| Missing YARA rules | Skip YARA with warning |
| Missing optional scanner | Mark as skipped in report |
| Portable download fails | Suggest manual installation |

### 9.3 Checkpoint/Resume

DMS automatically saves progress on interrupt:

```bash
# If scan is interrupted (Ctrl+C), checkpoint is saved
# Resume with:
sudo ./malware_scan.sh /dev/sdb1 --resume /tmp/malware_scan_12345/.checkpoint
```

### 9.4 Cleanup Behavior

| Exit Type | Temp Files | EWF Mount |
|-----------|------------|-----------|
| Normal completion | Cleaned (unless --keep-output) | Unmounted |
| Error | Preserved for debugging | Unmounted |
| Interrupt (Ctrl+C) | Preserved with warning | Unmounted |
| --keep-output | Preserved | Unmounted |

---

## 10. Security & Forensic Integrity

### 10.1 Read-Only Operations

DMS never writes to the source device or image:
- Raw reads via `dd` with read-only mode
- EWF images mounted read-only via FUSE
- No file modifications on source

### 10.2 Privilege Requirements

| Operation | Minimum Privilege |
|-----------|-------------------|
| Block device access | Root or `disk` group |
| EWF mounting | Root |
| Rootkit detection | Root |
| Raw disk reading | Root |

### 10.3 Evidence Integrity Features

| Feature | Purpose |
|---------|---------|
| `--verify-hash` | Validates EWF hash before scanning |
| `--log-file` | Creates audit trail |
| Read-only ops | Preserves original evidence |
| EWF metadata | Preserves case information |

### 10.4 Temporary File Security

- All temp files in `SCAN_OUTPUT_DIR`
- PID-based naming prevents conflicts
- Mode 0600 for sensitive extractions
- Automatic cleanup on exit

---

## 11. Dependencies

### 11.1 Required Tools

| Tool | Package | Purpose |
|------|---------|---------|
| clamscan | clamav | Signature-based detection |
| yara | yara | Pattern-based detection |
| strings | binutils | String extraction |
| dd | coreutils | Raw data reading |
| binwalk | binwalk | Embedded file analysis |

### 11.2 Deep Scan Tools

| Tool | Package | Purpose |
|------|---------|---------|
| foremost | foremost | File carving |
| bulk_extractor | bulk-extractor | Artifact extraction |
| ssdeep | ssdeep | Fuzzy hashing |
| exiftool | libimage-exiftool-perl | Metadata extraction |
| md5deep | md5deep | Recursive hashing |

### 11.3 Slack Space Tools

| Tool | Package | Purpose |
|------|---------|---------|
| blkls | sleuthkit | Unallocated extraction |
| foremost | foremost | File recovery |

### 11.4 EWF Support

| Tool | Package | Purpose |
|------|---------|---------|
| ewfmount | libewf-tools | Mount EWF images |
| ewfverify | libewf-tools | Hash verification |
| ewfinfo | libewf-tools | Metadata extraction |

### 11.5 Optional Tools

| Tool | Package | Purpose |
|------|---------|---------|
| chkrootkit | chkrootkit | Rootkit detection |
| rkhunter | rkhunter | Rootkit hunting |
| fls | sleuthkit | File listing |
| mactime | sleuthkit | Timeline generation |
| scalpel | scalpel | Alternative carving |

### 11.6 Version Requirements

| Component | Minimum |
|-----------|---------|
| Bash | 4.0+ |
| YARA | 4.0+ |
| ClamAV | 0.103+ |
| libewf | 20140608+ |

---

## 12. Troubleshooting

### 12.1 Common Issues

<details>
<summary><strong>Tool not found errors</strong></summary>

**Solution**: Use portable mode to auto-download tools:
```bash
sudo ./malware_scan.sh --interactive --portable
```

Or install manually:
```bash
sudo apt install clamav yara binutils binwalk
```

</details>

<details>
<summary><strong>Permission denied</strong></summary>

**Solution**: Run with sudo:
```bash
sudo ./malware_scan.sh /dev/sdb1
```

Or add user to disk group:
```bash
sudo usermod -aG disk $USER
```

</details>

<details>
<summary><strong>EWF mount fails</strong></summary>

**Solution**: Install libewf-tools:
```bash
sudo apt install libewf-tools
```

Check FUSE is available:
```bash
sudo modprobe fuse
```

</details>

<details>
<summary><strong>YARA rules not found</strong></summary>

**Solution**: Set custom path in config:
```bash
YARA_RULES_BASE=/path/to/your/rules
```

Or use Qu1cksc0pe rules:
```bash
git clone https://github.com/CYB3RMX/Qu1cksc0pe /opt/Qu1cksc0pe
```

</details>

<details>
<summary><strong>Scan runs out of memory</strong></summary>

**Solution**: Reduce chunk size:
```bash
sudo ./malware_scan.sh /dev/sdb1 --config <(echo "CHUNK_SIZE=100")
```

Or use auto-chunk:
```bash
sudo ./malware_scan.sh /dev/sdb1 --auto-chunk
```

</details>

<details>
<summary><strong>Interactive mode display issues</strong></summary>

**Solution**: Ensure terminal supports Unicode:
```bash
export LANG=en_US.UTF-8
```

Or use high-contrast mode:
```bash
sudo ./malware_scan.sh --interactive --high-contrast
```

</details>

### 12.2 Debug Mode

Enable verbose logging:
```bash
sudo ./malware_scan.sh /dev/sdb1 --verbose --log-file /tmp/dms-debug.log
```

### 12.3 Getting Help

- Check `--help` for quick reference
- Review this Wiki for detailed documentation
- Open an issue on GitHub for bugs

---

## Appendix A: Guidance Priority Levels

| Level | Color | Description | Recommended Action |
|-------|-------|-------------|-------------------|
| Critical | Red | Known malware signatures | Immediate isolation and analysis |
| High | Orange | YARA matches, suspicious patterns | Urgent investigation |
| Medium | Yellow | Recovered executables, PII | Scheduled review |
| Low | Blue | URLs, high entropy regions | Document for reference |

## Appendix B: Statistics Keys

| Key | Description |
|-----|-------------|
| `clamav_scanned` | Bytes scanned by ClamAV |
| `clamav_infected` | Infected file count |
| `yara_rules_checked` | YARA rules evaluated |
| `yara_matches` | YARA rule matches |
| `strings_total` | Total strings extracted |
| `strings_urls` | URL strings found |
| `entropy_regions_scanned` | Entropy blocks analyzed |
| `entropy_high_count` | High entropy regions |
| `carved_total` | Files carved |
| `carved_executables` | Executables recovered |
| `slack_size_mb` | Slack space size |
| `slack_files_recovered` | Files from slack |
| `pe_headers` | PE executables found |
| `elf_headers` | ELF executables found |
| `bulk_emails` | Email addresses found |
| `bulk_urls` | URLs extracted |

---

*DMS Wiki v2.1 - Complete Technical Reference*
