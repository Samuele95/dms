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
13. [Forensic Analysis Modules](#13-forensic-analysis-modules)
14. [USB Kit Mode](#14-usb-kit-mode) **(NEW)**
15. [ISO Builder](#15-iso-builder) **(NEW)**
16. [Output Storage Management](#16-output-storage-management) **(NEW)**

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
| **Persistence** | `scan_persistence_artifacts()` | Forensic | No | RegRipper |
| **Execution** | `scan_execution_artifacts()` | Forensic | No | Python parsers |
| **File Anomalies** | `scan_file_anomalies()` | Forensic | No | file, Python |
| **RE Triage** | `scan_re_triage()` | Forensic | No | capa, pefile |
| **MFT Forensics** | `scan_filesystem_forensics()` | Forensic | No | analyzeMFT |

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

#### Forensic Analysis (NEW)

| Option | Description |
|--------|-------------|
| `--forensic-analysis` | Enable all forensic analysis modules |
| `--persistence-scan` | Scan for persistence mechanisms (registry, tasks, services) |
| `--execution-scan` | Analyze execution artifacts (prefetch, amcache, shimcache) |
| `--file-anomalies` | Detect file anomalies (timestomping, ADS, suspicious paths) |
| `--re-triage` | Run RE triage on suspicious files (capa, imports, entropy) |
| `--mft-analysis` | Parse MFT for deleted files and filesystem anomalies |

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

## 13. Forensic Analysis Modules

### 13.1 Overview

DMS includes comprehensive behavioral and forensic analysis capabilities for Windows artifacts, enabling detection of advanced threats through artifact correlation and MITRE ATT&CK technique mapping.

**Enable all forensic modules**:
```bash
sudo ./malware_scan.sh evidence.E01 --forensic-analysis
```

**Or enable specific modules**:
```bash
sudo ./malware_scan.sh /dev/sdb1 --persistence-scan --execution-scan
```

### 13.2 Module Summary

| Module | CLI Flag | Artifacts | MITRE ATT&CK |
|--------|----------|-----------|--------------|
| Persistence | `--persistence-scan` | Registry Run keys, Services, Tasks, Startup, WMI | T1547, T1543, T1053, T1546 |
| Execution | `--execution-scan` | Prefetch, Amcache, Shimcache, UserAssist, SRUM, BAM | T1059, T1204 |
| File Anomalies | `--file-anomalies` | Magic mismatch, ADS, timestomping, packed files | T1036, T1070, T1564 |
| RE Triage | `--re-triage` | capa analysis, suspicious imports, shellcode | T1055, T1055.012 |
| MFT Forensics | `--mft-analysis` | $MFT parsing, $UsnJrnl, deleted files | T1070, T1485 |

### 13.3 Persistence Artifact Analysis

**Function**: `scan_persistence_artifacts()`

Detects Windows persistence mechanisms used by malware to survive reboots.

| Artifact | Location | Tool | ATT&CK ID |
|----------|----------|------|-----------|
| Registry Run Keys | NTUSER.DAT, SOFTWARE hives | RegRipper | T1547.001 |
| Services | SYSTEM hive | RegRipper `services` plugin | T1543.003 |
| Scheduled Tasks | Windows/System32/Tasks/* | XML parsing | T1053.005 |
| Startup Folders | Start Menu/Programs/Startup | File enumeration | T1547.001 |
| WMI Subscriptions | OBJECTS.DATA | Python WMI parser | T1546.003 |
| DLL Hijacking | Known vulnerable paths | Path validation | T1574.001 |

**Statistics Tracked**:
- `persistence_run_keys`: Registry Run key entries
- `persistence_services`: Suspicious services
- `persistence_tasks`: Scheduled tasks
- `persistence_startup`: Startup folder items
- `persistence_wmi`: WMI subscriptions
- `persistence_dll_hijack`: DLL hijack paths

### 13.4 Execution Artifact Analysis

**Function**: `scan_execution_artifacts()`

Analyzes Windows forensic artifacts that prove program execution.

| Artifact | What It Proves | Tool | Key Value |
|----------|----------------|------|-----------|
| Prefetch | Program executed, timestamps | Python prefetch parser | Last 8 execution times |
| Amcache | Executables that ran | Python Amcache parser | SHA1 hashes |
| Shimcache | Programs that existed | AppCompatCache parser | Chronological order |
| UserAssist | GUI programs launched | RegRipper | Execution count/time |
| SRUM | Network/energy per app | Python SRUM parser (pyesedb) | Resource usage |
| BAM/DAM | Background activity | RegRipper | Last execution |

**Execution Anomaly Detection**:
- Execution from `%TEMP%`, `%PUBLIC%`, Downloads
- High entropy executable names (obfuscated)
- Mismatched PE internal name vs filename
- Execution outside business hours (configurable)

**Statistics Tracked**:
- `execution_prefetch`: Prefetch files analyzed
- `execution_amcache`: Amcache entries
- `execution_shimcache`: Shimcache entries
- `execution_userassist`: UserAssist records
- `execution_srum`: SRUM entries
- `execution_bam`: BAM/DAM entries
- `execution_anomalies`: Execution anomalies detected

### 13.5 File Anomaly Detection

**Function**: `scan_file_anomalies()`

Detects file-level indicators of compromise and anti-forensic techniques.

| Check | Description | ATT&CK ID |
|-------|-------------|-----------|
| Magic vs Extension | Magic bytes don't match file extension | T1036.005 |
| Alternate Data Streams | Hidden data in NTFS ADS | T1564.004 |
| Suspicious Paths | Executables in temp, recycle bin, etc. | T1036 |
| Packed Executables | UPX, Themida, VMProtect signatures | T1027.002 |
| Attribute Anomalies | Deep paths, Unicode tricks, RTL override | T1036.002 |
| Timestomping | $SI vs $FN timestamp discrepancy | T1070.006 |

**Packer Detection Signatures**:
```
UPX:      "UPX0", "UPX1", "UPX!"
Themida:  ".themida", ".winlicense"
VMProtect: ".vmp0", ".vmp1"
ASPack:   ".aspack"
PECompact: "PEC2"
```

**Statistics Tracked**:
- `file_magic_mismatch`: Magic/extension mismatches
- `file_ads`: Alternate Data Streams
- `file_suspicious_location`: Suspicious paths
- `file_packed`: Packed executables
- `file_attribute_anomalies`: Attribute anomalies
- `timestomping_detected`: Timestomping instances

### 13.6 Reverse Engineering Triage

**Function**: `scan_re_triage()`

Automated reverse engineering analysis for carved/suspicious executables.

#### 13.6.1 capa Integration

Uses Mandiant capa for ATT&CK capability mapping:
```bash
capa -j suspicious_file.exe
```

**Output Example**:
```json
{
  "capabilities": {
    "persistence": ["create scheduled task", "modify registry run key"],
    "defense_evasion": ["check for debugger", "disable security tools"],
    "collection": ["capture screenshot", "keylogging"]
  },
  "attack_techniques": ["T1547.001", "T1082", "T1055"]
}
```

#### 13.6.2 Suspicious Import Analysis

**Process Injection APIs** (T1055):
```
CreateRemoteThread, WriteProcessMemory, VirtualAllocEx,
NtMapViewOfSection, NtWriteVirtualMemory
```

**Process Hollowing APIs** (T1055.012):
```
NtUnmapViewOfSection, ZwUnmapViewOfSection, SetThreadContext,
NtResumeThread, ResumeThread, NtSuspendThread
```

**Anti-Debug/Evasion APIs**:
```
IsDebuggerPresent, CheckRemoteDebuggerPresent,
NtQueryInformationProcess (ProcessDebugPort)
```

**Credential Access APIs** (T1003):
```
CredEnumerate, LsaRetrievePrivateData, CryptUnprotectData
```

#### 13.6.3 Similarity Hashing

| Hash Type | Purpose | Tool |
|-----------|---------|------|
| imphash | Import table hash (malware family clustering) | pefile |
| ssdeep | Fuzzy hash (similarity detection) | ssdeep |
| TLSH | Locality-sensitive hash | tlsh |

#### 13.6.4 Shellcode Detection

**Patterns Detected**:
- GetPC techniques (call/pop sequences)
- API hashing (CRC32, ROR13)
- Metasploit/Cobalt Strike signatures
- Position-independent code indicators

**Statistics Tracked**:
- `re_triaged_files`: Files analyzed
- `re_suspicious_imports`: Suspicious API imports
- `re_suspicious_strings`: Suspicious strings (URLs, IPs, commands)
- `capa_capabilities`: capa capabilities found
- `attack_techniques_mapped`: ATT&CK techniques identified

### 13.7 MFT/Filesystem Forensics

**Function**: `scan_filesystem_forensics()`

NTFS filesystem forensic analysis for deleted files and anti-forensic detection.

#### 13.7.1 MFT Analysis

| Analysis | Description | Tool |
|----------|-------------|------|
| Deleted Records | Files with deleted flag set | analyzeMFT |
| $DATA Streams | All data streams including ADS | analyzeMFT |
| Resident Data | Small files stored in MFT record | analyzeMFT |
| Parent Reconstruction | Full path from parent references | analyzeMFT |

#### 13.7.2 USN Journal Analysis

| Event Type | Forensic Value |
|------------|----------------|
| File Create | Program installation, malware drop |
| File Delete | Evidence destruction attempts |
| File Rename | Evasion technique |
| Data Overwrite | Anti-forensic wiping |

**Anti-Forensic Detection**:
- Mass deletion patterns (wiping tools)
- Timestamp manipulation sequences
- USN journal clearing attempts

#### 13.7.3 Timestomping Detection

Compares `$STANDARD_INFORMATION` vs `$FILE_NAME` timestamps:

| Indicator | Description |
|-----------|-------------|
| $SI < $FN | $SI modified to appear older |
| $SI nanoseconds = 0 | Some tools zero nanoseconds |
| Future timestamps | Impossible dates |
| Pre-OS timestamps | Dates before Windows installation |

**Statistics Tracked**:
- `mft_records_parsed`: MFT records analyzed
- `mft_deleted_recovered`: Deleted files found
- `usn_entries_parsed`: USN journal entries
- `timestomping_detected`: Timestomping instances

### 13.8 MITRE ATT&CK Mapping

All forensic findings are mapped to ATT&CK techniques:

| Technique ID | Name | Detection Module |
|--------------|------|------------------|
| T1547.001 | Registry Run Keys | Persistence |
| T1543.003 | Windows Service | Persistence |
| T1053.005 | Scheduled Task | Persistence |
| T1546.003 | WMI Event Subscription | Persistence |
| T1574.001 | DLL Search Order Hijacking | Persistence |
| T1059 | Command and Scripting Interpreter | Execution |
| T1204.002 | Malicious File | Execution |
| T1036.005 | Match Legitimate Name | File Anomalies |
| T1036.007 | Double File Extension | File Anomalies |
| T1070.006 | Timestomping | File Anomalies |
| T1564.004 | NTFS File Attributes (ADS) | File Anomalies |
| T1027.002 | Software Packing | File Anomalies |
| T1055 | Process Injection | RE Triage |
| T1055.012 | Process Hollowing | RE Triage |
| T1003 | Credential Dumping | RE Triage |
| T1070 | Indicator Removal | MFT Forensics |

### 13.9 Configuration Options

Add to `~/.malscan.conf`:

```bash
# ============================================
# Forensic Analysis Settings
# ============================================

# Enable full forensic artifact analysis (all modules below)
FORENSIC_ANALYSIS=false

# Individual module control
PERSISTENCE_SCAN=false
EXECUTION_SCAN=false
FILE_ANOMALIES=false
RE_TRIAGE=false
MFT_ANALYSIS=false

# Tool paths
REGRIPPER_PATH=/opt/regripper
CAPA_PATH=/opt/capa/capa
```

### 13.10 Report Output

Forensic findings appear in both HTML and JSON reports:

**HTML Report Section**:
```
╔══════════════════════════════════════════════════════════════════╗
║  BEHAVIORAL & FORENSIC ANALYSIS                                   ║
╠══════════════════════════════════════════════════════════════════╣
║  Persistence Artifacts                                            ║
║    Registry Run Keys:     3                     T1547.001         ║
║    Services:              1                     T1543.003         ║
║    Scheduled Tasks:       2                     T1053.005         ║
╟──────────────────────────────────────────────────────────────────╢
║  MITRE ATT&CK Techniques Detected                                 ║
║  [T1547.001] [T1543.003] [T1053.005] [T1055.012]                  ║
╚══════════════════════════════════════════════════════════════════╝
```

**JSON Report Extension**:
```json
{
  "behavioral_findings": {
    "enabled": true,
    "persistence": {
      "run_keys": 3,
      "services": 1,
      "scheduled_tasks": 2
    },
    "execution_evidence": {
      "prefetch_files": 45,
      "amcache_entries": 128
    },
    "file_anomalies": {
      "magic_mismatch": 2,
      "timestomping_detected": 1
    },
    "re_triage": {
      "files_analyzed": 15,
      "suspicious_imports": 3
    },
    "attack_techniques": {
      "total_mapped": 6,
      "techniques": ["T1547.001", "T1543.003", "T1053.005", "T1055.012"]
    }
  }
}
```

---

## Appendix C: Forensic Statistics Keys

| Key | Description |
|-----|-------------|
| `persistence_run_keys` | Registry Run key entries |
| `persistence_services` | Suspicious services found |
| `persistence_tasks` | Scheduled tasks found |
| `persistence_startup` | Startup folder items |
| `persistence_wmi` | WMI subscriptions |
| `persistence_dll_hijack` | DLL hijack paths |
| `execution_prefetch` | Prefetch files analyzed |
| `execution_amcache` | Amcache entries |
| `execution_shimcache` | Shimcache entries |
| `execution_userassist` | UserAssist records |
| `execution_srum` | SRUM database entries |
| `execution_bam` | BAM/DAM entries |
| `execution_anomalies` | Execution anomalies |
| `file_magic_mismatch` | Magic/extension mismatches |
| `file_ads` | Alternate Data Streams |
| `file_suspicious_location` | Files in suspicious paths |
| `file_packed` | Packed executables |
| `file_attribute_anomalies` | Attribute anomalies |
| `timestomping_detected` | Timestomping instances |
| `re_triaged_files` | Files RE analyzed |
| `re_suspicious_imports` | Suspicious API imports |
| `re_suspicious_strings` | Suspicious strings |
| `capa_capabilities` | capa capabilities found |
| `attack_techniques_mapped` | ATT&CK techniques mapped |
| `mft_records_parsed` | MFT records analyzed |
| `mft_deleted_recovered` | Deleted files found |
| `usn_entries_parsed` | USN journal entries |

---

## 14. USB Kit Mode

### 14.1 Overview

DMS supports portable USB deployment for field forensics with two operational modes:

| Mode | Size | Network Required | Use Case |
|------|------|------------------|----------|
| **Minimal** | ~10 MB | Yes (downloads tools on-demand) | Light deployment, good connectivity |
| **Full Offline** | ~1.2 GB | No (all tools bundled) | Air-gapped environments, field work |

### 14.2 USB Kit Structure

```
USB_ROOT/
├── dms/
│   ├── malware_scan.sh           # Main script
│   ├── malscan.conf              # Configuration
│   ├── lib/                      # Library modules
│   │   ├── usb_mode.sh           # USB detection & switching
│   │   ├── update_manager.sh     # Database/tools updates
│   │   ├── kit_builder.sh        # Build full offline kit
│   │   ├── iso_builder.sh        # ISO creation functions
│   │   └── output_storage.sh     # Output management
│   ├── tools/                    # Bundled portable tools (full mode)
│   │   ├── bin/                  # Executables
│   │   └── lib/                  # Libraries
│   ├── databases/                # Malware signatures (full mode)
│   │   ├── clamav/               # ClamAV databases
│   │   └── yara/                 # YARA rule sets
│   ├── cache/                    # Compiled YARA rules
│   ├── output/                   # Scan results
│   └── logs/                     # Operation logs
├── .dms_kit_manifest.json        # Kit metadata & versions
└── run-dms.sh                    # Portable launcher script
```

### 14.3 Kit Manifest

The `.dms_kit_manifest.json` file tracks kit metadata:

```json
{
  "kit_version": "1.0.0",
  "created_date": "2026-01-21T00:00:00Z",
  "last_updated": "2026-01-21T00:00:00Z",
  "mode": "full",
  "dms_version": "2.1",
  "databases": {
    "clamav": {
      "version": "27500",
      "date": "2026-01-21",
      "files": ["main.cvd", "daily.cvd", "bytecode.cvd"]
    },
    "yara": {
      "qu1cksc0pe_date": "2026-01-21",
      "signature_base_date": "2026-01-21"
    }
  },
  "tools": {
    "clamav": "1.3.1",
    "yara": "4.5.0"
  },
  "checksums": {
    "clamav_main": "abc123...",
    "yara_rules": "def456..."
  }
}
```

### 14.4 Building a USB Kit

#### Full Offline Kit (Recommended for Field Work)

```bash
# Build complete offline kit on a USB drive
sudo ./malware_scan.sh --build-full-kit --kit-target /media/usb

# Build with specific output location
sudo ./malware_scan.sh --build-full-kit --kit-target /media/FORENSIC_USB
```

**Requirements**:
- ~2 GB free space on target
- Network connectivity (to download tools/databases)
- Root privileges

**Build Process**:
1. Creates directory structure
2. Downloads ClamAV binaries and databases
3. Downloads YARA binary and rule sets
4. Compiles YARA rules cache
5. Copies DMS scripts and libraries
6. Creates launcher script
7. Generates manifest file

#### Minimal Kit (Network Required)

```bash
# Build minimal kit (just scripts, downloads tools on-demand)
sudo ./malware_scan.sh --build-minimal-kit --kit-target /media/usb
```

**Minimal Kit Contents**:
- DMS scripts (~5 MB)
- Configuration files
- Library modules
- Launcher script

### 14.5 Running from USB Kit

#### Using the Launcher Script

```bash
# Run from USB kit with auto-detection
sudo /media/usb/run-dms.sh /dev/sda1

# Run with options
sudo /media/usb/run-dms.sh /dev/sda1 --deep --forensic-analysis

# Interactive mode from USB
sudo /media/usb/run-dms.sh --interactive
```

#### Direct Execution

```bash
# Navigate to DMS directory
cd /media/usb/dms

# Run with USB mode auto-detection
sudo ./malware_scan.sh /dev/sda1

# Force USB mode
sudo ./malware_scan.sh /dev/sda1 --usb-mode
```

### 14.6 Updating a USB Kit

```bash
# Update databases on USB kit (requires network)
sudo /media/usb/dms/malware_scan.sh --update-kit

# Or from the USB root
sudo /media/usb/run-dms.sh --update-kit
```

**Update Process**:
1. Verifies USB is writable
2. Checks network connectivity
3. Downloads latest ClamAV databases (freshclam)
4. Downloads latest YARA rules
5. Recompiles YARA cache
6. Updates manifest with new versions/timestamps

### 14.7 USB Mode Detection

DMS automatically detects USB kit mode by checking for `.dms_kit_manifest.json` in parent directories:

```bash
# Detection hierarchy (searches upward)
1. ./..dms_kit_manifest.json
2. ../..dms_kit_manifest.json
3. ../../.dms_kit_manifest.json
(continues up to root)
```

**Environment Variables Set in USB Mode**:

| Variable | Description |
|----------|-------------|
| `USB_MODE` | `true` when running from USB kit |
| `USB_ROOT` | Root directory of USB kit |
| `KIT_MODE` | `minimal` or `full` |
| `KIT_MANIFEST` | Path to manifest file |
| `DMS_TOOLS_DIR` | Bundled tools directory |
| `DMS_DATABASES_DIR` | Bundled databases directory |

### 14.8 Configuration Options

Add to `malscan.conf`:

```bash
# ============================================
# USB Kit Settings
# ============================================

# Auto-detect USB kit mode
USB_MODE=auto

# Kit mode: "auto", "minimal", or "full"
KIT_MODE=auto

# USB kit directories (relative to USB_ROOT)
USB_TOOLS_DIR=tools
USB_DATABASES_DIR=databases
USB_CACHE_DIR=cache

# Update settings
USB_UPDATE_CLAMAV=true
USB_UPDATE_YARA=true
USB_UPDATE_TOOLS=false

# Minimum free space for full kit (MB)
KIT_MIN_FREE_SPACE_MB=2000
```

### 14.9 Estimated Kit Sizes

| Component | Size |
|-----------|------|
| DMS Scripts + Libraries | ~5 MB |
| ClamAV Binaries | ~150 MB |
| ClamAV Databases | ~350 MB |
| YARA Binary + Rules | ~105 MB |
| Other Tools (full mode) | ~500 MB |
| **Minimal Kit Total** | **~10 MB** |
| **Full Kit Total** | **~1.2 GB** |

---

## 15. ISO Builder

### 15.1 Overview

DMS can create bootable ISO images based on Debian Live for field forensics. The ISO approach offers advantages over direct USB deployment:

| Aspect | ISO Approach | Direct USB |
|--------|--------------|------------|
| **Reusability** | Flash to unlimited USBs | Single USB only |
| **Distribution** | Share ISO file with team | N/A |
| **Integrity** | SHA256 checksum verification | None |
| **Testing** | Test in VM first | Physical USB required |
| **Versioning** | dms-forensic-v1.0.iso | Harder to track |
| **Industry Standard** | Used by CAINE, Tsurugi, SIFT | Non-standard |

### 15.2 ISO Structure

```
dms-forensic-X.Y.Z.iso
├── boot/
│   ├── grub/
│   │   └── grub.cfg              # GRUB bootloader config (UEFI)
│   └── efi.img                   # EFI boot image
├── live/
│   ├── filesystem.squashfs       # Compressed root filesystem
│   ├── vmlinuz                   # Linux kernel
│   └── initrd.img                # Initial ramdisk
├── dms/                          # DMS kit embedded in ISO
│   ├── malware_scan.sh
│   ├── tools/                    # Bundled portable tools
│   └── databases/                # Malware signatures
├── isolinux/                     # Legacy BIOS boot
│   ├── isolinux.bin
│   └── isolinux.cfg
└── .disk/
    └── info                      # ISO metadata
```

### 15.3 Live System Features

| Feature | Description |
|---------|-------------|
| **Base System** | Debian 12 (Bookworm) minimal |
| **Forensic Tools** | sleuthkit, ewf-tools, dc3dd, exiftool |
| **DMS Integration** | Pre-configured with bundled tools |
| **Boot Modes** | UEFI + Legacy BIOS (hybrid ISO) |
| **Read-Only Root** | squashfs prevents evidence contamination |
| **Persistence** | Optional partition (user creates after flashing) |
| **Auto-Mount** | Disabled by default (forensic safety) |

### 15.4 Building an ISO

#### Basic ISO Build

```bash
# Build bootable ISO with all defaults
sudo ./malware_scan.sh --build-iso

# Output: ./dms-forensic-2.1.0.iso
# Output: ./dms-forensic-2.1.0.iso.sha256
```

#### Custom ISO Build

```bash
# Specify output location
sudo ./malware_scan.sh --build-iso --iso-output ~/forensic-kit/dms-custom.iso

# Include latest databases
sudo ./malware_scan.sh --build-iso --iso-include-databases
```

**Build Requirements**:
- Root privileges
- ~5 GB free disk space (for build working directory)
- Network connectivity (to download Debian Live base)
- Tools: xorriso, squashfs-tools, debootstrap

**Build Process**:
1. Download official Debian Live ISO (or use cached)
2. Verify ISO checksum
3. Extract squashfs filesystem
4. Install forensic tools (sleuthkit, ewf-tools, etc.)
5. Inject DMS with full kit
6. Create desktop integration
7. Re-squash filesystem
8. Build hybrid ISO (UEFI + BIOS bootable)
9. Generate SHA256 checksum

### 15.5 Flashing ISO to USB

#### Using DMS Flash Command

```bash
# Flash ISO to USB device
sudo ./malware_scan.sh --flash-iso /dev/sdb

# Force flash (skip removable device check)
sudo ./malware_scan.sh --flash-iso /dev/sdb --force
```

#### Using Standard Tools

```bash
# Using dd
sudo dd if=dms-forensic-2.1.0.iso of=/dev/sdb bs=4M status=progress

# Using Rufus (Windows)
# Using Etcher (Cross-platform)
```

### 15.6 Adding Persistence Partition

After flashing the ISO, you can create a persistence partition for saving case files and database updates:

```bash
# Create persistence partition on remaining USB space
sudo ./malware_scan.sh --create-persistence /dev/sdb
```

**Persistence Partition**:
- Label: `persistence`
- Filesystem: ext4
- Contains: `/home`, `/cases`, `/dms-updates`
- Data survives reboots

### 15.7 Boot Menu Options

```
╔════════════════════════════════════════════════════════════╗
║            DMS Forensic Live                                ║
╠════════════════════════════════════════════════════════════╣
║  > DMS Forensic Live                                        ║
║    DMS Forensic Live (Persistence)                          ║
║    DMS Forensic Live (RAM Mode - toram)                     ║
║    DMS Forensic Live (Safe - no automount)                  ║
╚════════════════════════════════════════════════════════════╝
```

| Boot Option | Description |
|-------------|-------------|
| **DMS Forensic Live** | Standard boot, evidence drives not auto-mounted |
| **Persistence** | Same + saves changes to persistence partition |
| **RAM Mode** | Loads entire system to RAM (remove USB after boot) |
| **Safe Mode** | No automount, no fstab - maximum forensic safety |

### 15.8 ISO Configuration

Add to `malscan.conf`:

```bash
# ============================================
# ISO Builder Settings
# ============================================

# Base Debian Live ISO URL
DEBIAN_LIVE_URL=https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/debian-live-12.5.0-amd64-standard.iso

# Expected SHA256 (for verification)
DEBIAN_LIVE_SHA256=

# ISO output filename pattern
ISO_OUTPUT_PATTERN=dms-forensic-VERSION.iso

# Additional packages to install
ISO_EXTRA_PACKAGES="sleuthkit ewf-tools dc3dd exiftool testdisk"

# Build working directory
ISO_WORK_DIR=/tmp/dms-iso-build

# Include databases in ISO
ISO_INCLUDE_CLAMAV_DB=true
ISO_INCLUDE_YARA_RULES=true
```

### 15.9 Estimated ISO Size

| Component | Size |
|-----------|------|
| Debian Live base | ~1.0 GB |
| Forensic tools | ~400 MB |
| DMS + Tools | ~800 MB |
| Databases | ~450 MB |
| **Total ISO** | **~2.5-3.0 GB** |

### 15.10 ISO Workflow Example

```bash
# 1. BUILD (one-time, on workstation with network)
sudo ./malware_scan.sh --build-iso
# Output: dms-forensic-2.1.0.iso (2.8 GB)
# Output: dms-forensic-2.1.0.iso.sha256

# 2. VERIFY (check integrity)
sha256sum -c dms-forensic-2.1.0.iso.sha256

# 3. DISTRIBUTE
# - Share ISO file with team via secure channel
# - Upload to internal forensic toolkit server

# 4. FLASH (per USB stick needed)
sudo dd if=dms-forensic-2.1.0.iso of=/dev/sdb bs=4M status=progress

# 5. ADD PERSISTENCE (optional)
sudo ./malware_scan.sh --create-persistence /dev/sdb

# 6. BOOT & USE (at crime scene)
# - Insert USB, boot from it
# - Select "DMS Forensic Live" from menu
# - Run: dms-scan /dev/sda1 --deep --forensic-analysis
# - Results saved to external storage or persistence

# 7. UPDATE (periodic maintenance)
# Option A: Rebuild ISO with latest databases
# Option B: On booted system with network:
#           dms-scan --update-kit
#           (saves to persistence partition)
```

---

## 16. Output Storage Management

### 16.1 Overview

When running from a live ISO or USB kit, DMS needs a safe location to save scan results. The output storage module manages:

- Detection of available writable storage
- Safe output device mounting (excluding evidence drives)
- Case directory structure creation
- Evidence information documentation

### 16.2 Storage Options

| Option | Pros | Cons | Use Case |
|--------|------|------|----------|
| **External USB** | Portable, removable | Must format/trust device | Field work |
| **Persistence Partition** | Always available | Limited space, on boot USB | Quick scans |
| **Network Share** | Centralized, large | Requires network | Lab environment |
| **PC Data Partition** | Large, fast | Risk of touching evidence | Careful use only |
| **RAM (tmpfs)** | Zero disk writes | Lost on reboot | Evidence preview |

### 16.3 Output Device Selection

#### Automatic Detection

DMS automatically detects available writable storage, excluding:
- Evidence device (and all its partitions)
- Boot device (live USB/ISO source)
- System mount points (/, /boot, /usr)

```bash
# Run scan - DMS prompts for output storage if multiple options
sudo ./malware_scan.sh /dev/sda1

# Available Output Storage:
# ==========================
#   1. 💾 /dev/sdc1 (32G) - FORENSIC_OUTPUT [removable]
#   2. 🔌 /dev/sdd1 (64G) - EXTERNAL_USB [removable]
#   3. 💿 /dev/nvme0n1p4 (200G) - Data [internal]
#   4. RAM only (tmpfs) - ⚠️ Data lost on reboot
```

#### CLI Options

```bash
# Specify output device
sudo ./malware_scan.sh /dev/sda1 --output-device /dev/sdc1

# Specify output path (directory)
sudo ./malware_scan.sh /dev/sda1 --output-path /mnt/forensic-output

# Use RAM only (tmpfs) - WARNING: lost on reboot
sudo ./malware_scan.sh /dev/sda1 --output-tmpfs

# Custom case name
sudo ./malware_scan.sh /dev/sda1 --case-name "Investigation-2026-001"
```

### 16.4 Case Directory Structure

When a scan starts, DMS creates a case directory:

```
/mnt/dms-output/
└── cases/
    └── case_20260121_143022/          # Auto-generated timestamp
        ├── evidence_info.txt          # Source device, hashes, timestamps
        ├── scan_config.json           # Scan settings used
        ├── report.txt                 # Main text report
        ├── report.html                # HTML report
        ├── report.json                # JSON report
        ├── findings/
        │   ├── malware_detections/    # Detected malware samples
        │   ├── suspicious_files/      # Flagged files
        │   └── carved_files/          # Recovered files
        ├── forensic_artifacts/
        │   ├── persistence/           # Persistence findings
        │   ├── execution/             # Execution artifacts
        │   └── timeline/              # Timeline data
        └── logs/
            ├── scan.log               # Detailed scan log
            └── tool_output/           # Raw tool outputs
```

### 16.5 Evidence Information File

DMS automatically creates `evidence_info.txt` documenting the evidence source:

```
═══════════════════════════════════════════════════════════════════
DMS FORENSIC SCAN - EVIDENCE INFORMATION
═══════════════════════════════════════════════════════════════════

Case Created:     2026-01-21 14:30:22 UTC
Examiner System:  DMS Forensic Live 2.1.0
DMS Version:      2.1.0

EVIDENCE SOURCE
───────────────
Device:           /dev/sda1
Type:             Block device (partition)
Filesystem:       NTFS
Size:             500 GB
Serial:           WD-WMC4N0123456

INTEGRITY HASHES (pre-scan)
───────────────────────────
MD5:              d41d8cd98f00b204e9800998ecf8427e
SHA1:             da39a3ee5e6b4b0d3255bfef95601890afd80709
SHA256:           e3b0c44298fc1c149afbf4c8996fb92427ae41e4...

MOUNT STATUS
────────────
Mounted:          Read-only at /mnt/evidence
Mount Options:    ro,noexec,noatime

OUTPUT STORAGE
──────────────
Device:           /dev/sdc1 (External USB)
Label:            FORENSIC_OUTPUT
Mounted:          Read-write at /mnt/dms-output
═══════════════════════════════════════════════════════════════════
```

### 16.6 Device Classification

DMS classifies detected storage devices:

| Type | Icon | Description | Priority |
|------|------|-------------|----------|
| **persistence** | 💾 | USB persistence partition | High |
| **removable** | 🔌 | External USB, SD card | High |
| **internal** | 💿 | Internal HDD/SSD partition | Low |

### 16.7 tmpfs (RAM) Output

When using `--output-tmpfs`, scan results are stored in RAM:

```bash
sudo ./malware_scan.sh /dev/sda1 --output-tmpfs
```

**Warnings**:
- Data is LOST when system shuts down or reboots
- Limited by available RAM
- Useful for quick evidence preview without persistent storage

**On Exit Warning**:
```
════════════════════════════════════════════════════════════
⚠️  WARNING: Output was stored in RAM (tmpfs)
⚠️  Data will be LOST when the system shuts down!
⚠️  Copy important files to persistent storage before shutdown.
════════════════════════════════════════════════════════════
Case directory: /mnt/dms-output/cases/case_20260121_143022
```

### 16.8 Configuration Options

Add to `malscan.conf`:

```bash
# ============================================
# Output Storage Settings
# ============================================

# Default output device (blank = auto-detect)
# OUTPUT_DEVICE=/dev/sdc1

# Default output path
# OUTPUT_PATH=/mnt/forensic-output

# Use tmpfs by default
OUTPUT_TMPFS=false

# Default mount point
OUTPUT_MOUNT_POINT=/mnt/dms-output

# Case naming pattern
CASE_NAME_PATTERN=case_%Y%m%d_%H%M%S

# Warn before using tmpfs
OUTPUT_TMPFS_WARN=true

# ============================================
# Persistence Partition Settings
# ============================================

# Default persistence label
PERSISTENCE_LABEL=persistence

# Minimum persistence size (MB)
PERSISTENCE_MIN_SIZE_MB=512

# Persistence filesystem
PERSISTENCE_FSTYPE=ext4
```

### 16.9 Field Workflow Example

```bash
# 1. Boot from DMS Live USB at crime scene

# 2. Plug in external evidence storage USB (NOT the evidence!)

# 3. Launch DMS with output device specified
sudo dms-scan /dev/sda1 --output-device /dev/sdc1 --deep

# DMS will:
# - Mount /dev/sda1 read-only (evidence)
# - Mount /dev/sdc1 read-write (output)
# - Create case directory on /dev/sdc1
# - Hash evidence before scanning
# - Run scan, save all results
# - Display case path on completion

# 4. Review results in case directory
ls /mnt/dms-output/cases/case_*/

# 5. Eject output USB, take to lab
sudo umount /mnt/dms-output

# 6. Evidence drive remains untouched
```

### 16.10 Storage Summary Display

During scan initialization, DMS displays storage summary:

```
Output Storage Summary
======================
Type:        device
Device:      /dev/sdc1
Mount Point: /mnt/dms-output
Mounted:     true
Case Dir:    /mnt/dms-output/cases/case_20260121_143022
```

---

## Appendix D: USB/ISO CLI Reference

### USB Kit Commands

| Option | Description |
|--------|-------------|
| `--build-full-kit` | Build complete offline USB kit |
| `--build-minimal-kit` | Build minimal USB kit (scripts only) |
| `--kit-target <path>` | Target directory for kit build |
| `--update-kit` | Update USB kit databases |
| `--usb-mode` | Force USB mode detection |

### ISO Commands

| Option | Description |
|--------|-------------|
| `--build-iso` | Build bootable ISO |
| `--iso-output <path>` | Specify ISO output path |
| `--flash-iso <device>` | Flash ISO to USB device |
| `--create-persistence <device>` | Add persistence partition |
| `--force` | Force flash without removable device check |

### Output Storage Commands

| Option | Description |
|--------|-------------|
| `--output-device <device>` | Use specific device for output |
| `--output-path <path>` | Use specific directory for output |
| `--output-tmpfs` | Use RAM only (tmpfs) |
| `--case-name <name>` | Custom case directory name |

---

*DMS Wiki v2.1 - Complete Technical Reference*
