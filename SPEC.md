# DMS - Drive Malware Scan Specification

**Version:** 2.1
**Last Updated:** January 2026
**Platform:** Tsurugi Linux (compatible with Debian-based systems)

---

## 1. Overview

### 1.1 Purpose and Scope

DMS (Drive Malware Scan) is an advanced malware detection and forensic analysis tool designed for digital forensics investigators and incident response teams. It provides comprehensive drive scanning capabilities using multiple detection engines and analysis techniques.

### 1.2 Target Environment

- **Primary Platform:** Tsurugi Linux
- **Compatible Systems:** Debian/Ubuntu-based distributions
- **Required Privileges:** Root access required for block device operations and EWF mounting
- **Shell Requirements:** Bash 4.0+ with associative array support

### 1.3 Version History

| Version | Description |
|---------|-------------|
| 2.1 | EWF forensic image support, slack space scanning, interactive TUI |
| 2.0 | Enhanced robustness, parallel scanning, deep scan features |

---

## 2. Architecture

### 2.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         DMS v2.1                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Input     │  │   Config    │  │      CLI Parser         │ │
│  │  Handler    │  │   Loader    │  │                         │ │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘ │
│         │                │                     │               │
│         └────────────────┴─────────────────────┘               │
│                          │                                      │
│  ┌───────────────────────▼───────────────────────────────────┐ │
│  │                   Scan Orchestrator                        │ │
│  │  (Sequential / Parallel Mode)                              │ │
│  └───────────────────────┬───────────────────────────────────┘ │
│                          │                                      │
│  ┌───────────────────────▼───────────────────────────────────┐ │
│  │                   Scanning Modules                         │ │
│  │ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │ │
│  │ │ ClamAV  │ │  YARA   │ │ Binwalk │ │ Strings │           │ │
│  │ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │ │
│  │ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │ │
│  │ │ Entropy │ │ Carving │ │  Bulk   │ │ Hashes  │           │ │
│  │ └─────────┘ └─────────┘ │Extractor│ └─────────┘           │ │
│  │                         └─────────┘                        │ │
│  └───────────────────────────────────────────────────────────┘ │
│                          │                                      │
│  ┌───────────────────────▼───────────────────────────────────┐ │
│  │                  Report Generator                          │ │
│  │            (Text / HTML / JSON)                            │ │
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
│  Input Validation │──────► Auto-detect type (block/EWF/raw)
│  & Type Detection │        Mount EWF if needed
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│  Chunked Reading  │──────► Split into CHUNK_SIZE MB segments
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐       ┌─────────────────────┐
│  Scan Execution   │──────►│ Parallel Scanners   │
│                   │       │ - ClamAV            │
│  (Full or Slack)  │       │ - YARA              │
└─────────┬─────────┘       │ - Binwalk           │
          │                 │ - Strings           │
          │                 └─────────────────────┘
          ▼
┌───────────────────┐
│ Result Aggregation│──────► Collect findings from all modules
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│  Report Generation│──────► Text, HTML, JSON output
│  with Guidance    │
└───────────────────┘
```

### 2.3 Module Responsibilities

| Module | Responsibility |
|--------|----------------|
| Input Handler | Validates input, detects type, mounts EWF images |
| Config Loader | Loads settings from config files with override precedence |
| Scan Orchestrator | Coordinates scan execution (sequential or parallel) |
| ClamAV Scanner | Signature-based malware detection |
| YARA Scanner | Pattern-based threat detection with rule categories |
| Binwalk Scanner | Embedded file and firmware analysis |
| Strings Analyzer | Suspicious string pattern extraction |
| Entropy Analyzer | Identifies encrypted/packed regions |
| File Carver | Recovers deleted files from unallocated space |
| Bulk Extractor | Extracts artifacts (URLs, emails, credit cards) |
| Report Generator | Produces formatted output with actionable guidance |

---

## 3. Input Specifications

### 3.1 Supported Formats

| Format | Extensions | Description |
|--------|------------|-------------|
| Block Device | `/dev/sdX`, `/dev/nvmeXnY` | Physical drives and partitions |
| EWF Image | `.E01`, `.E02`, `.Ex01`, `.L01`, `.Lx01` | Expert Witness Format forensic images |
| Raw Image | `.raw`, `.dd`, `.img`, `.bin` | Raw disk images |

### 3.2 Auto-Detection Algorithm

```
1. Check if path is a block device (stat -c %F)
2. If regular file:
   a. Check extension for EWF patterns (.E01, .Ex01, .L01, .Lx01)
   b. Check extension for raw patterns (.raw, .dd, .img, .bin)
   c. Verify file accessibility
3. For EWF images:
   a. Locate all segment files
   b. Extract metadata using ewfinfo
   c. Mount using ewfmount to virtual device
4. Set INPUT_TYPE to: block_device | ewf | raw_image
```

### 3.3 Validation Requirements

- **Block devices:** Must exist and be readable
- **EWF images:** All segments must be present and accessible
- **Raw images:** File must be readable and non-empty
- **Forced format:** Use `--input-format` to override auto-detection

---

## 4. Scanning Modules

### 4.1 ClamAV Integration

**Function:** `scan_clamav()`

| Parameter | Description |
|-----------|-------------|
| Input | Chunked device data via `dd` |
| Database | `CLAMDB_DIR` (default: `/tmp/clamdb`) |
| Output | Infection count, signature names |

**Processing:**
1. Extract chunk data to temporary file
2. Run `clamscan --infected --no-summary`
3. Parse results for infection count
4. Store matched signatures in statistics

**Error Handling:**
- Missing clamscan binary: FATAL (unless --portable mode)
- Database update failure: WARNING (continues with existing DB)
- Scan timeout: Records partial results

### 4.2 YARA Rule Engine

**Function:** `scan_yara()` / `scan_yara_category()`

| Parameter | Description |
|-----------|-------------|
| Rules Base | `YARA_RULES_BASE` (default: `/opt/Qu1cksc0pe/Systems`) |
| Categories | Windows, Linux, Android, Documents |
| Cache | `YARA_CACHE_DIR` for compiled rules |

**Rule Categories:**
- **Windows:** PE malware, ransomware, trojans
- **Linux:** ELF threats, rootkits, backdoors
- **Android:** APK malware, adware, spyware
- **Documents:** Office macros (oledump rules), PDF exploits

**Processing:**
1. Load compiled rules from cache (or compile)
2. Scan each chunk with category-specific rules
3. Aggregate matches with offset information
4. Track rule name and match location

### 4.3 Entropy Analysis

**Function:** `scan_entropy()`

| Parameter | Description |
|-----------|-------------|
| Block Size | 1MB blocks |
| High Threshold | > 7.5 (out of 8.0) |
| Output | Region count, average, maximum |

**Interpretation:**
- High entropy (>7.5): Encrypted data, compressed archives, packed executables
- Normal entropy (4-7): Regular data, executables
- Low entropy (<4): Text files, sparse data

### 4.4 File Carving

**Function:** `scan_file_carving()`

| Parameter | Description |
|-----------|-------------|
| Tools | foremost, photorec, scalpel (configurable) |
| Max Files | `MAX_CARVED_FILES` (default: 1000) |
| Output | Recovered files by type |

**Supported Carving Types:**
- Executables: exe, dll, elf
- Documents: pdf, doc, xls, ppt
- Images: jpg, png, gif, bmp
- Archives: zip, rar, 7z, gz
- Media: mp3, mp4, avi

### 4.5 Slack Space Extraction

**Function:** `extract_slack_space()`

| Parameter | Description |
|-----------|-------------|
| Tool | blkls (from sleuthkit) |
| Timeout | `SLACK_EXTRACT_TIMEOUT` (default: 600s) |
| Min Size | `SLACK_MIN_SIZE_MB` (default: 10MB) |

**Process:**
1. Extract unallocated space using `blkls`
2. Store to temporary file
3. Run analysis tools on extracted data
4. Carve recoverable files

### 4.6 Quick Scan Mode

**Function:** `scan_quick()`

Sample-based scanning for rapid preliminary analysis:
- Samples strategic regions of the drive
- Performs entropy checks on samples
- Identifies areas requiring deeper analysis
- Suitable for triage scenarios

### 4.7 Additional Modules

| Module | Function | Description |
|--------|----------|-------------|
| Binwalk | `scan_binwalk()` | Firmware analysis, embedded file detection |
| Strings | `scan_strings()` | URL, credential, and executable string extraction |
| Bulk Extractor | `scan_bulk_extractor()` | Email, URL, credit card number extraction |
| Executables | `scan_executables()` | PE/ELF header detection with offset tracking |
| Boot Sector | `scan_boot_sector()` | MBR analysis, bootkit detection |
| Hashes | `scan_hashes()` | MD5/SHA1/SHA256 generation for files |
| VirusTotal | `scan_virustotal()` | Hash lookup via VT API |
| Rootkit | `scan_rootkit()` | chkrootkit/rkhunter integration |

---

## 5. Configuration Schema

### 5.1 Configuration File Locations

Configuration files are searched in order (first found is used):
1. `~/.malscan.conf`
2. `/etc/malscan.conf`
3. `./malscan.conf`

### 5.2 All Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `CLAMDB_DIR` | path | `/tmp/clamdb` | ClamAV database directory |
| `YARA_RULES_BASE` | path | `/opt/Qu1cksc0pe/Systems` | YARA rules base directory |
| `OLEDUMP_RULES` | path | `/opt/oledump` | Oledump YARA rules for documents |
| `YARA_CACHE_DIR` | path | `/tmp/yara_cache` | Compiled YARA rules cache |
| `CHUNK_SIZE` | integer | `500` | Chunk size in MB for scanning |
| `MAX_PARALLEL_JOBS` | integer | `4` | Maximum parallel scan jobs |
| `VT_API_KEY` | string | (empty) | VirusTotal API key |
| `VT_RATE_LIMIT` | integer | `4` | VT requests per minute |
| `LOG_LEVEL` | enum | `INFO` | DEBUG, INFO, WARNING, ERROR |
| `PORTABLE_TOOLS_DIR` | path | `/tmp/malscan_portable_tools` | Portable tools directory |
| `YARA_VERSION` | string | `4.5.0` | YARA version for portable download |
| `CLAMAV_VERSION` | string | `1.3.1` | ClamAV version for portable download |
| `EWF_SUPPORT` | boolean | `true` | Enable EWF image support |
| `EWF_VERIFY_HASH` | boolean | `false` | Verify EWF hash before scanning |
| `EWF_MOUNT_OPTIONS` | string | (empty) | Additional ewfmount options |
| `TEMP_MOUNT_BASE` | path | `/tmp` | Base directory for temp mounts |
| `DEFAULT_SCAN_MODE` | enum | `full` | Default: full or slack |
| `SLACK_EXTRACT_TIMEOUT` | integer | `600` | Slack extraction timeout (seconds) |
| `SLACK_MIN_SIZE_MB` | integer | `10` | Minimum slack size to analyze |
| `MAX_CARVED_FILES` | integer | `1000` | Maximum files to carve |
| `CARVING_TOOLS` | string | `foremost` | Comma-separated carving tools |
| `NO_COLOR` | boolean | `false` | Disable colored output |
| `HIGH_CONTRAST` | boolean | `false` | High contrast display mode |

### 5.3 Override Precedence

```
Command-line arguments (highest)
        ↓
Environment variables
        ↓
Config file settings
        ↓
Built-in defaults (lowest)
```

---

## 6. CLI Interface

### 6.1 Synopsis

```
malware_scan.sh <input> [options]
```

### 6.2 All Options

#### Basic Options

| Option | Short | Description |
|--------|-------|-------------|
| `--mount` | `-m` | Mount device before scanning |
| `--update` | `-u` | Update ClamAV databases before scan |
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

#### Performance Options

| Option | Short | Description |
|--------|-------|-------------|
| `--parallel` | `-p` | Enable parallel scanning |
| `--auto-chunk` | | Auto-calculate optimal chunk size |
| `--quick` | | Quick scan mode (sample-based) |

#### Feature Options

| Option | Description |
|--------|-------------|
| `--virustotal` | Enable VirusTotal hash lookup |
| `--rootkit` | Run rootkit detection |
| `--timeline` | Generate file timeline |
| `--resume FILE` | Resume from checkpoint file |

#### Output Options

| Option | Short | Description |
|--------|-------|-------------|
| `--html` | | Generate HTML report |
| `--json` | | Generate JSON report |
| `--quiet` | `-q` | Quiet mode (minimal output) |
| `--verbose` | `-v` | Verbose mode (debug output) |

#### Display Options

| Option | Description |
|--------|-------------|
| `--no-color` | Disable colored output |
| `--high-contrast` | High visibility mode |
| `--interactive` | `-i` | Interactive TUI mode |

#### Advanced Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview actions without executing |
| `--config FILE` | Use custom configuration file |
| `--log-file FILE` | Write logs to file |
| `--keep-output` | Keep temporary output directory |

#### Portable Mode

| Option | Description |
|--------|-------------|
| `--portable` | Auto-download missing tools |
| `--portable-keep` | Keep portable tools after scan |
| `--portable-dir DIR` | Custom portable tools directory |

### 6.3 Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success - scan completed |
| `1` | Error - scan failed or invalid arguments |
| `130` | Interrupted - received SIGINT (Ctrl+C) |
| `143` | Terminated - received SIGTERM |

### 6.4 Environment Variables

| Variable | Description |
|----------|-------------|
| `VT_API_KEY` | VirusTotal API key (alternative to config) |
| `HOME` | Used for config file path `~/.malscan.conf` |

---

## 7. Output Formats

### 7.1 Text Report Schema

```
═══════════════════════════════════════════════════════════════
              TSURUGI LINUX MALWARE SCAN REPORT
              Generated: <timestamp>
═══════════════════════════════════════════════════════════════

DEVICE INFORMATION
──────────────────
Device:     <device_path>
Size:       <size> GB
Filesystem: <fs_type>
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
[VirusTotal Results if enabled]
[Rootkit Results if enabled]

SCAN STATUS
───────────
<module>: completed | failed

OVERALL STATUS
──────────────
STATUS: CLEAN | SUSPICIOUS
Total findings: <count>

═══════════════════════════════════════════════════════════════
Scan output directory: <path>
```

### 7.2 HTML Report Structure

```html
<!DOCTYPE html>
<html>
<head>
    <title>DMS Scan Statistics - <date></title>
    <!-- Embedded CSS styling -->
</head>
<body>
    <div class="container">
        <h1>DMS - Drive Malware Scan Statistics</h1>
        <p class="timestamp">Generated: <timestamp></p>

        <div class="summary-banner">
            <h2>Scan Statistics Summary</h2>
            <p>Findings: <summary></p>
            <p>Items to review: <count></p>
        </div>

        <h2>Device Information</h2>
        <div class="info-box">...</div>

        <h2>Scan Statistics</h2>
        <table>...</table>

        <h2>Output Location</h2>
        <div class="info-box">...</div>
    </div>
</body>
</html>
```

### 7.3 JSON Report Schema

```json
{
    "report": {
        "version": "2.1",
        "generated": "<ISO8601_timestamp>",
        "tool": "DMS - Drive Malware Scanner"
    },
    "device": {
        "path": "<device_path>",
        "size_gb": <number>,
        "filesystem": "<fs_type>"
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
        "slack_data_recovered_mb": <number>,
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

## 8. Error Handling

### 8.1 Error Codes and Meanings

| Category | Condition | Action |
|----------|-----------|--------|
| INPUT | Invalid device path | Exit with error |
| INPUT | Missing EWF segments | Exit with error |
| INPUT | Permission denied | Exit with error |
| TOOL | Missing required tool | Exit unless --portable |
| TOOL | Missing optional tool | Continue with warning |
| SCAN | Timeout during scan | Record partial results |
| SCAN | Module failure | Mark as failed, continue others |
| EWF | Mount failure | Exit with error |
| EWF | Hash verification failed | Exit with error (if --verify-hash) |

### 8.2 Recovery Procedures

**Checkpoint/Resume:**
```bash
# If scan is interrupted, checkpoint is saved automatically
# Resume with:
./malware_scan.sh <device> --resume .checkpoint
```

**EWF Mount Cleanup:**
- Automatic cleanup on exit via trap handlers
- Manual cleanup if needed: `fusermount -u /tmp/ewf_mount_*`

### 8.3 Graceful Degradation

| Missing Component | Fallback Behavior |
|-------------------|-------------------|
| Deep scan tools | Skip deep scan, complete basic scans |
| YARA rules directory | Skip YARA scanning with warning |
| Optional scanners | Mark as skipped in report |
| Portable download fails | Suggest manual installation |

---

## 9. Security Considerations

### 9.1 Privilege Requirements

| Operation | Required Privilege |
|-----------|-------------------|
| Block device access | Root or disk group |
| EWF mounting | Root (for fuse/mount) |
| Rootkit detection | Root |
| Raw disk reading | Root or appropriate group |

### 9.2 Temporary File Handling

- All temp files created in `SCAN_OUTPUT_DIR` (default: `/tmp/malware_scan_$$`)
- PID-based naming prevents conflicts
- Automatic cleanup on normal exit
- Preserved on error for debugging (with warning message)
- `--keep-output` flag preserves all temporary files

### 9.3 Evidence Integrity

| Feature | Description |
|---------|-------------|
| Read-only scanning | Device is never written to |
| EWF hash verification | `--verify-hash` validates image integrity |
| Metadata preservation | EWF metadata (case number, acquisition date) preserved |
| Audit logging | `--log-file` creates detailed audit trail |

---

## 10. Dependencies

### 10.1 Required Tools

| Tool | Package | Purpose |
|------|---------|---------|
| clamscan | clamav | Signature-based malware detection |
| yara | yara | Pattern-based threat detection |
| strings | binutils | String extraction |
| dd | coreutils | Raw data reading |
| binwalk | binwalk | Embedded file analysis |

### 10.2 Deep Scan Tools

| Tool | Package | Purpose |
|------|---------|---------|
| foremost | foremost | File carving |
| bulk_extractor | bulk-extractor | Artifact extraction |
| ssdeep | ssdeep | Fuzzy hashing |
| exiftool | libimage-exiftool-perl | Metadata extraction |
| md5deep | md5deep | Recursive hashing |

### 10.3 Slack Space Tools

| Tool | Package | Purpose |
|------|---------|---------|
| blkls | sleuthkit | Unallocated space extraction |
| foremost | foremost | File recovery |

### 10.4 EWF Support

| Tool | Package | Purpose |
|------|---------|---------|
| ewfmount | libewf-tools | Mount EWF as virtual device |
| ewfverify | libewf-tools | Hash verification |
| ewfinfo | libewf-tools | Metadata extraction |

### 10.5 Optional Enhancements

| Tool | Package | Purpose |
|------|---------|---------|
| yarac | yara | Rule compilation |
| chkrootkit | chkrootkit | Rootkit detection |
| rkhunter | rkhunter | Rootkit hunting |
| fls | sleuthkit | File listing |
| mactime | sleuthkit | Timeline generation |
| scalpel | scalpel | Additional file carving |
| photorec | testdisk | Photo/file recovery |

### 10.6 Version Requirements

| Component | Minimum Version |
|-----------|-----------------|
| Bash | 4.0+ (associative arrays) |
| YARA | 4.0+ |
| ClamAV | 0.103+ |
| libewf | 20140608+ |

---

## 11. Testing Requirements

### 11.1 Unit Test Expectations

| Module | Test Cases |
|--------|------------|
| Input Handler | Valid block device, valid EWF, valid raw, invalid paths |
| Config Loader | Default values, config file loading, CLI overrides |
| ClamAV Scanner | Clean sample, infected sample, missing DB |
| YARA Scanner | Rule matching, no matches, missing rules |
| Entropy Analyzer | High entropy, low entropy, mixed content |

### 11.2 Integration Test Scenarios

| Scenario | Verification |
|----------|--------------|
| Full drive scan | All modules execute, report generated |
| Slack space scan | Slack extracted, artifacts recovered |
| EWF image scan | Image mounted, scanned, unmounted |
| Parallel scanning | All parallel jobs complete |
| Checkpoint/resume | State preserved and restored |
| Portable mode | Tools downloaded, scan completes |

### 11.3 Verification Checklist

- [ ] All CLI options documented and functional
- [ ] Config file parameters applied correctly
- [ ] Exit codes match documented values
- [ ] Error messages are informative
- [ ] Cleanup occurs on all exit paths
- [ ] Reports contain all documented fields
- [ ] JSON output is valid JSON
- [ ] HTML output renders correctly

---

## Appendix A: YARA Rule Categories

| Category | Location | Target |
|----------|----------|--------|
| Windows | `$YARA_RULES_BASE/Windows/` | PE malware, ransomware |
| Linux | `$YARA_RULES_BASE/Linux/` | ELF threats, rootkits |
| Android | `$YARA_RULES_BASE/Android/` | APK malware |
| Documents | `$OLEDUMP_RULES/` | Office macros, PDF exploits |

## Appendix B: Supported File Carving Types

| Category | Extensions |
|----------|------------|
| Executables | exe, dll, elf, mach-o |
| Documents | pdf, doc, docx, xls, xlsx, ppt, pptx |
| Images | jpg, jpeg, png, gif, bmp, tiff |
| Archives | zip, rar, 7z, gz, tar, bz2 |
| Media | mp3, mp4, avi, mov, wav |
| Databases | sqlite, db |

## Appendix C: EWF Metadata Fields

| Field | Source | Description |
|-------|--------|-------------|
| Total Size | ewfinfo | Original media size |
| MD5 Hash | ewfinfo | Stored acquisition hash |
| SHA1 Hash | ewfinfo | Stored acquisition hash |
| Acquisition Date | ewfinfo | When image was created |
| Case Number | ewfinfo | Associated case identifier |
| Examiner Name | ewfinfo | Acquiring examiner |
| Evidence Number | ewfinfo | Evidence item number |

## Appendix D: Guidance Priority Levels

| Level | Description | Action Required |
|-------|-------------|-----------------|
| Critical | Known malware signatures | Immediate isolation |
| High | YARA matches, suspicious boot sector | Urgent analysis |
| Medium | Recovered executables, PII found | Scheduled review |
| Low | URLs, high entropy regions | Documentation |

---

**Document End**

*This specification describes DMS v2.1 functionality as implemented.*
