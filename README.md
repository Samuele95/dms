<p align="center">
  <img src="https://img.shields.io/badge/DMS-Drive%20Malware%20Scan-blue?style=for-the-badge&logo=linux&logoColor=white" alt="DMS">
</p>

<p align="center">
  <pre align="center">
██████╗ ███╗   ███╗███████╗
██╔══██╗████╗ ████║██╔════╝
██║  ██║██╔████╔██║███████╗
██║  ██║██║╚██╔╝██║╚════██║
██████╔╝██║ ╚═╝ ██║███████║
╚═════╝ ╚═╝     ╚═╝╚══════╝
  </pre>
</p>

<h3 align="center">Drive Malware Scan</h3>
<p align="center">
  <strong>Advanced Malware Detection & Forensic Analysis Tool</strong><br>
  <em>Purpose-built for digital forensics professionals and incident responders</em>
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-interactive-mode">Interactive Mode</a> •
  <a href="#-features">Features</a> •
  <a href="#-use-cases">Use Cases</a> •
  <a href="#-technical-specifications">Specs</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-2.1-blue.svg?style=flat-square" alt="Version 2.1">
  <img src="https://img.shields.io/badge/license-MIT-green.svg?style=flat-square" alt="MIT License">
  <img src="https://img.shields.io/badge/platform-Linux-lightgrey.svg?style=flat-square" alt="Linux">
  <img src="https://img.shields.io/badge/made%20for-Tsurugi%20Linux-orange.svg?style=flat-square" alt="Tsurugi Linux">
  <img src="https://img.shields.io/badge/bash-4.0%2B-89e051.svg?style=flat-square" alt="Bash 4.0+">
  <img src="https://img.shields.io/badge/ClamAV-integrated-red.svg?style=flat-square" alt="ClamAV">
  <img src="https://img.shields.io/badge/YARA-powered-yellow.svg?style=flat-square" alt="YARA">
</p>

---

## What is DMS?

**DMS (Drive Malware Scan)** is a comprehensive, all-in-one malware detection and forensic analysis toolkit designed specifically for **digital forensics investigators**, **incident response teams**, and **security professionals**.

Unlike traditional antivirus tools that only scan mounted filesystems, DMS operates at the **raw disk level**, allowing it to detect threats hidden in:

- **Deleted files** that haven't been overwritten
- **Slack space** (unallocated disk areas)
- **Boot sectors** and MBR/GPT structures
- **Forensic disk images** (E01/EWF format)
- **Encrypted or packed malware** through entropy analysis

DMS combines **12+ scanning techniques** into a single, easy-to-use tool with an **interactive TUI**, producing actionable reports that guide your investigation.

---

## Quick Start

### 1. Download DMS

```bash
git clone https://github.com/Samuele95/dms.git && cd dms && chmod +x malware_scan.sh
```

### 2. Launch Interactive Mode (Recommended)

```bash
sudo ./malware_scan.sh --interactive
```

That's it! The interactive TUI will guide you through everything. DMS can **automatically download all required tools** - no manual installation needed.

---

## Interactive Mode

**Interactive mode is the recommended way to use DMS.** It provides a full-screen interface that makes scan configuration intuitive and error-free.

### Launch

```bash
sudo ./malware_scan.sh --interactive
# or
sudo ./malware_scan.sh -i
```

### TUI Interface

```
╔══════════════════════════════════════════════════════════════════════╗
║               DMS - DRIVE MALWARE SCAN                               ║
║        Use ↑↓ to navigate, Space/Enter to toggle, S to start         ║
╠══════════════════════════════════════════════════════════════════════╣
║  INPUT SOURCE                                                        ║
╟──────────────────────────────────────────────────────────────────────╢
║▶ Path: /dev/sdb1 [block_device]                                      ║
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
║  [✓] Update ClamAV databases                                         ║
║  [✓] Parallel scanning mode                                          ║
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
║  [✓] Generate HTML report                                            ║
║  [✓] Generate JSON report                                            ║
║  [ ] Keep output directory after scan                                ║
╠══════════════════════════════════════════════════════════════════════╣
║      [S] Start Scan    [I] Set Input Path    [Q] Quit                ║
╚══════════════════════════════════════════════════════════════════════╝

  ✓  Ready to scan: /dev/sdb1 (block_device)
```

### Keyboard Controls

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate menu items |
| `Space` / `Enter` | Toggle option or select |
| `S` | Start scan with current settings |
| `I` | Open input path dialog |
| `Q` / `Esc` | Quit |
| `1` / `2` / `3` | Quick select scan type |

### TUI Features

| Feature | Description |
|---------|-------------|
| **Auto-detection** | Automatically identifies input type (block device, EWF, raw) |
| **Input Validation** | Prevents starting scan without valid input path |
| **Device Discovery** | Lists available block devices when setting input path |
| **EWF Awareness** | Suggests enabling hash verification for forensic images |
| **Real-time Feedback** | Status line shows current state and readiness |

---

## Installation

### Portable Mode (Recommended - Zero Dependencies!)

**DMS can download all required tools automatically.** This is the easiest way to get started:

```bash
# Clone DMS
git clone https://github.com/Samuele95/dms.git && cd dms && chmod +x malware_scan.sh

# Run with portable mode - tools are downloaded automatically!
sudo ./malware_scan.sh --interactive --portable

# Or via command line
sudo ./malware_scan.sh /dev/sdb1 --portable
```

**What portable mode does:**
- Downloads ClamAV, YARA, and other required tools
- Stores them in `/tmp/malscan_portable_tools`
- Works on any Linux system with internet access
- Use `--portable-keep` to preserve tools for offline use later

```bash
# Keep tools after scan for reuse
sudo ./malware_scan.sh /dev/sdb1 --portable --portable-keep

# Subsequent scans reuse cached tools
sudo ./malware_scan.sh /dev/sdc1 --portable
```

---

### Manual Installation (Optional)

If you prefer to install tools system-wide, or if you're on Tsurugi Linux (which has most tools pre-installed):

<details>
<summary><strong>Debian/Ubuntu/Tsurugi Linux</strong></summary>

```bash
# Core tools (required for basic scans)
sudo apt update
sudo apt install clamav clamav-daemon yara binutils binwalk

# Deep scan tools (recommended for full forensic analysis)
sudo apt install foremost bulk-extractor ssdeep libimage-exiftool-perl md5deep

# Slack space analysis
sudo apt install sleuthkit

# EWF forensic image support
sudo apt install libewf-tools

# Rootkit detection (optional)
sudo apt install chkrootkit rkhunter
```

</details>

<details>
<summary><strong>Fedora/RHEL/CentOS</strong></summary>

```bash
# Enable EPEL repository
sudo dnf install epel-release

# Core tools
sudo dnf install clamav clamav-update yara binutils binwalk

# Additional tools
sudo dnf install foremost sleuthkit libewf-tools
```

</details>

<details>
<summary><strong>Arch Linux</strong></summary>

```bash
# Core tools
sudo pacman -S clamav yara binutils binwalk

# AUR packages
yay -S foremost bulk-extractor sleuthkit libewf
```

</details>

### System-wide Installation (Optional)

```bash
# Create symlink for global access
sudo ln -s $(pwd)/malware_scan.sh /usr/local/bin/dms

# Now you can run from anywhere
sudo dms --interactive
```

---

## Features

<table>
<tr>
<td width="50%">

### Detection Engines

| Engine | Capability |
|--------|------------|
| **ClamAV** | 1M+ malware signatures |
| **YARA** | Custom pattern rules (4 categories) |
| **Binwalk** | Firmware/embedded files |
| **Strings** | IOC extraction |
| **Entropy** | Packed/encrypted detection |
| **Bulk Extractor** | Artifact recovery |

</td>
<td width="50%">

### Forensic Features

| Feature | Benefit |
|---------|---------|
| **EWF/E01 Support** | Native forensic images |
| **Hash Verification** | Evidence integrity |
| **Slack Space Scan** | Hidden threat detection |
| **File Carving** | Deleted file recovery |
| **Boot Sector Analysis** | Bootkit detection |
| **Timeline Generation** | Activity reconstruction |

</td>
</tr>
</table>

### Key Capabilities

| | Feature | Description |
|:---:|---------|-------------|
| :desktop_computer: | **Interactive TUI** | User-friendly menu-driven interface - the recommended way to use DMS |
| :package: | **Portable Mode** | Zero-install option - auto-downloads all required tools |
| :microscope: | **Deep Analysis** | Entropy analysis, file carving, PE/ELF header detection, boot sector inspection |
| :mag: | **Multi-Engine Scanning** | ClamAV signatures + YARA rules + Binwalk + Strings + Bulk Extractor |
| :bar_chart: | **Smart Reporting** | Text, HTML, and JSON reports with prioritized actionable guidance |
| :lock: | **Forensic Integrity** | Read-only operations, EWF hash verification, evidence preservation |
| :zap: | **Parallel Processing** | Multi-threaded scanning with automatic chunk optimization |
| :floppy_disk: | **Slack Space Recovery** | Extract and analyze unallocated disk space for hidden threats |
| :globe_with_meridians: | **VirusTotal Integration** | Automatic hash lookup via VT API for threat intelligence |
| :arrows_counterclockwise: | **Checkpoint/Resume** | Resume interrupted scans without losing progress |

---

## Why DMS?

### The Problem

When investigating a potentially compromised system, forensic analysts face several challenges:

| Challenge | Traditional Tools | DMS Solution |
|-----------|-------------------|--------------|
| Scanning disk images | Require mounting, may alter evidence | Native E01/EWF support with hash verification |
| Finding deleted malware | Cannot access unallocated space | Slack space extraction and analysis |
| Multiple scan tools | Run ClamAV, YARA, strings separately | All-in-one integrated scanning |
| Correlating results | Manual cross-referencing | Unified reports with guidance |
| Hidden/packed malware | Signature-only detection | Entropy analysis + behavioral patterns |
| Time pressure | Sequential tool execution | Parallel scanning mode |
| Tool installation | Complex dependency management | Portable mode downloads everything |

### The Solution

DMS provides a **forensically-sound**, **comprehensive**, and **efficient** approach:

```
┌─────────────────────────────────────────────────────────────────┐
│                     INTERACTIVE MODE                            │
│                           or                                    │
│                     ONE COMMAND                                 │
│                          │                                      │
│          sudo ./malware_scan.sh evidence.E01 --deep             │
│                          │                                      │
│                          ▼                                      │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ ClamAV  │ │  YARA   │ │ Entropy │ │ Carving │ │ Strings │   │
│  │  Scan   │ │  Rules  │ │Analysis │ │ Files   │ │ Extract │   │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘   │
│       └───────────┴───────────┴───────────┴───────────┘         │
│                          │                                      │
│                          ▼                                      │
│            ┌───────────────────────────────┐                    │
│            │   UNIFIED FORENSIC REPORT     │                    │
│            │   with Actionable Guidance    │                    │
│            └───────────────────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Use Cases

### 1. Incident Response: Compromised Workstation

**Scenario:** A user reports suspicious activity. You need to quickly assess if malware is present.

```bash
# Launch interactive mode for guided scan
sudo ./malware_scan.sh --interactive --portable

# Or via command line for quick triage
sudo ./malware_scan.sh /dev/sda1 --quick --portable

# If threats found, perform deep analysis
sudo ./malware_scan.sh /dev/sda1 --deep --parallel --html --portable
```

**What DMS Does:**
- Quick scan samples strategic disk regions for rapid assessment
- Deep scan recovers deleted files, checks entropy, analyzes boot sector
- HTML report provides clickable findings for your incident report

---

### 2. Digital Forensics: Evidence Analysis

**Scenario:** Law enforcement provides an E01 forensic image from a seized computer.

```bash
# Launch interactive mode - it auto-detects EWF and suggests hash verification
sudo ./malware_scan.sh --interactive

# Or via command line
sudo ./malware_scan.sh evidence.E01 --verify-hash --deep --json

# Focus on deleted/hidden data
sudo ./malware_scan.sh evidence.E01 --slack --html
```

**What DMS Does:**
- Verifies MD5/SHA1 hash matches acquisition hash (chain of custody)
- Mounts E01 as virtual device without modifying original
- Slack space mode finds malware the suspect tried to delete
- JSON output integrates with your case management system

---

### 3. Threat Hunting: Proactive Detection

**Scenario:** Security team wants to sweep servers for unknown threats.

```bash
# Comprehensive threat hunt with VirusTotal enrichment
sudo ./malware_scan.sh /dev/nvme0n1p2 --deep --virustotal --parallel

# Check for rootkits on mounted system
sudo ./malware_scan.sh /dev/sda1 --mount --rootkit
```

**What DMS Does:**
- YARA rules detect patterns missed by signature-only AV
- Entropy analysis flags packed/encrypted suspicious regions
- VirusTotal lookup provides threat intelligence context
- Rootkit scanners (chkrootkit/rkhunter) check for kernel-level threats

---

### 4. Malware Research: Sample Analysis

**Scenario:** Analyze a disk image containing malware samples.

```bash
# Full analysis with all engines
sudo ./malware_scan.sh malware_disk.raw --input-format raw --deep

# Extract artifacts for further analysis
sudo ./malware_scan.sh malware_disk.raw --deep --keep-output
```

**What DMS Does:**
- File carving recovers complete malware samples
- Strings extraction reveals C2 URLs, file paths, credentials
- Bulk extractor finds email addresses, URLs, crypto artifacts
- `--keep-output` preserves all extracted files for sandbox analysis

---

### 5. Field Operations: Portable Forensics

**Scenario:** Responding to an incident with only a bootable USB - no tools pre-installed.

```bash
# Portable mode downloads and runs tools automatically
sudo ./malware_scan.sh --interactive --portable --portable-keep

# Subsequent scans use cached tools (even offline!)
sudo ./malware_scan.sh /dev/sdc1 --portable
```

**What DMS Does:**
- Automatically downloads ClamAV, YARA, and dependencies
- Stores tools in `/tmp/malscan_portable_tools` for reuse
- Works on any Linux system with internet access
- `--portable-keep` preserves tools for offline use later

---

## Command-Line Usage

While interactive mode is recommended, DMS also supports full command-line operation:

### Basic Operations

```bash
# Scan a partition
sudo ./malware_scan.sh /dev/sdb1

# Update ClamAV database and scan
sudo ./malware_scan.sh /dev/sdb1 --update

# Mount filesystem before scanning (enables rootkit checks)
sudo ./malware_scan.sh /dev/sdb1 --mount
```

### Forensic Image Analysis

```bash
# Scan EWF/E01 image (auto-detected)
sudo ./malware_scan.sh case001.E01

# Verify hash integrity before scanning (recommended for legal cases)
sudo ./malware_scan.sh case001.E01 --verify-hash

# Scan raw DD image
sudo ./malware_scan.sh disk.dd --input-format raw
```

### Deep Analysis

```bash
# Full deep scan with all analysis modules
sudo ./malware_scan.sh /dev/sdb1 --deep

# Deep scan with parallel processing (faster on multi-core systems)
sudo ./malware_scan.sh /dev/sdb1 --deep --parallel --auto-chunk

# Deep scan with VirusTotal enrichment
sudo ./malware_scan.sh /dev/sdb1 --deep --virustotal
```

### Slack Space / Deleted Files

```bash
# Scan only unallocated space (where deleted files hide)
sudo ./malware_scan.sh /dev/sdb1 --slack

# Slack space scan on forensic image
sudo ./malware_scan.sh evidence.E01 --scan-mode slack
```

### Output & Reporting

```bash
# Generate HTML and JSON reports
sudo ./malware_scan.sh /dev/sdb1 --html --json

# Custom output location
sudo ./malware_scan.sh /dev/sdb1 --output /cases/case001/report.txt --html

# Preserve all working files for further analysis
sudo ./malware_scan.sh /dev/sdb1 --deep --keep-output
```

---

## Scan Modes Explained

| Mode | Command | Speed | Coverage | Best For |
|------|---------|-------|----------|----------|
| **Quick** | `--quick` | Fast | Sampled regions | Rapid triage, "is this worth investigating?" |
| **Standard** | (default) | Medium | Allocated data | General malware detection |
| **Deep** | `--deep` | Slow | Everything | Full forensic analysis |
| **Slack** | `--slack` | Medium | Unallocated only | Deleted file recovery, hidden threats |
| **Parallel** | `--parallel` | Faster | Same as mode | Multi-core acceleration |

### What Each Mode Includes

<details>
<summary><strong>Quick Scan</strong></summary>

- Strategic sampling of disk regions
- Entropy checks on samples
- Identifies areas needing deeper investigation
- Ideal for rapid triage

</details>

<details>
<summary><strong>Standard Scan (Default)</strong></summary>

- ClamAV signature scan
- YARA rule matching (Windows, Linux, Android, Documents)
- Binwalk embedded file detection
- Strings analysis for IOCs

</details>

<details>
<summary><strong>Deep Scan</strong></summary>

All standard scans PLUS:
- Entropy analysis (detect encrypted/packed data)
- File carving (recover deleted files)
- Executable header detection (PE/ELF)
- Boot sector and MBR analysis
- Bulk extraction (emails, URLs, credit cards)
- Hash generation for all carved files

</details>

<details>
<summary><strong>Slack Space Scan</strong></summary>

- Extracts unallocated space using `blkls` (Sleuth Kit)
- Carves recoverable files from slack
- Scans all recovered data for threats
- Finds malware that was "deleted" but not overwritten

</details>

---

## Technical Specifications

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         DMS v2.1                                │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Input     │  │   Config    │  │   CLI / Interactive     │ │
│  │  Handler    │  │   Loader    │  │        Parser           │ │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘ │
│         └────────────────┴─────────────────────┘               │
│                          │                                      │
│  ┌───────────────────────▼───────────────────────────────────┐ │
│  │                   Scan Orchestrator                        │ │
│  │  (Sequential / Parallel Mode with Checkpoint Support)      │ │
│  └───────────────────────┬───────────────────────────────────┘ │
│                          │                                      │
│  ┌───────────────────────▼───────────────────────────────────┐ │
│  │                   Scanning Modules (12+)                   │ │
│  │ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │ │
│  │ │ ClamAV  │ │  YARA   │ │ Binwalk │ │ Strings │           │ │
│  │ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │ │
│  │ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │ │
│  │ │ Entropy │ │ Carving │ │  Bulk   │ │ Hashes  │           │ │
│  │ │Analysis │ │ Engine  │ │Extractor│ │ Gen     │           │ │
│  │ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │ │
│  └───────────────────────────────────────────────────────────┘ │
│                          │                                      │
│  ┌───────────────────────▼───────────────────────────────────┐ │
│  │                  Report Generator                          │ │
│  │       (Text / HTML / JSON with Actionable Guidance)        │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Key Metrics

| Metric | Value |
|--------|-------|
| Script Size | ~4,850 lines of Bash |
| Scanning Engines | 12+ integrated techniques |
| Configuration Parameters | 30+ tunable options |
| YARA Rule Categories | 4 (Windows, Linux, Android, Documents) |

### Supported Input Formats

| Type | Extensions | Auto-Detected |
|------|------------|---------------|
| Block Device | `/dev/sdX`, `/dev/nvmeXnY` | Yes |
| EWF Image | `.E01`, `.E02`, `.Ex01`, `.L01`, `.Lx01` | Yes |
| Raw Image | `.raw`, `.dd`, `.img`, `.bin` | Yes |

### Report Formats

| Format | Description | Use Case |
|--------|-------------|----------|
| **Text** | Plain ASCII with formatting | Terminal viewing, logs |
| **HTML** | Styled web page | Sharing with stakeholders |
| **JSON** | Machine-readable | SIEM integration, scripting |

### Detection Engine Details

| Engine | Signatures/Rules | Parallel Support |
|--------|------------------|------------------|
| ClamAV | 1M+ signatures | Yes |
| YARA (Windows) | Qu1cksc0pe rules | Yes |
| YARA (Linux) | Qu1cksc0pe rules | Yes |
| YARA (Android) | Qu1cksc0pe rules | Yes |
| YARA (Documents) | oledump rules | Yes |
| Entropy Analysis | Threshold: 7.5/8.0 | No |
| File Carving | foremost/scalpel | No |

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success - scan completed |
| `1` | Error - scan failed or invalid arguments |
| `130` | Interrupted - SIGINT (Ctrl+C) |
| `143` | Terminated - SIGTERM |

---

## CLI Options Reference

| Option | Short | Description |
|--------|-------|-------------|
| `--interactive` | `-i` | **Launch interactive TUI (recommended)** |
| `--portable` | | **Auto-download missing tools** |
| `--portable-keep` | | Keep portable tools after scan |
| `--mount` | `-m` | Mount device before scanning |
| `--update` | `-u` | Update ClamAV databases first |
| `--deep` | `-d` | Enable deep forensic scan |
| `--parallel` | `-p` | Enable parallel scanning |
| `--quick` | | Fast sample-based scan |
| `--slack` | | Scan unallocated space only |
| `--html` | | Generate HTML report |
| `--json` | | Generate JSON report |
| `--quiet` | `-q` | Minimal output |
| `--verbose` | `-v` | Debug output |
| `--verify-hash` | | Verify EWF image integrity |
| `--virustotal` | | Enable VT hash lookup |
| `--rootkit` | | Run rootkit detection |
| `--timeline` | | Generate file timeline |
| `--keep-output` | | Preserve temp files |
| `--resume FILE` | | Resume from checkpoint |
| `--config FILE` | | Custom config file |
| `--log-file FILE` | | Write logs to file |
| `--output FILE` | `-o` | Custom output path |
| `--dry-run` | | Preview without executing |

---

## Configuration

Create `~/.malscan.conf`, `/etc/malscan.conf`, or `./malscan.conf`:

```bash
# Performance Settings
CHUNK_SIZE=500              # MB per chunk (larger = more RAM, faster)
MAX_PARALLEL_JOBS=4         # Parallel scan threads (match CPU cores)

# Tool Paths
CLAMDB_DIR=/tmp/clamdb
YARA_RULES_BASE=/opt/Qu1cksc0pe/Systems
OLEDUMP_RULES=/opt/oledump

# VirusTotal Integration
VT_API_KEY=your_api_key_here
VT_RATE_LIMIT=4             # Requests per minute (free API limit)

# Forensic Image Settings
EWF_SUPPORT=true
EWF_VERIFY_HASH=false       # Set true to always verify

# Slack Space Settings
SLACK_EXTRACT_TIMEOUT=600   # Seconds
SLACK_MIN_SIZE_MB=10        # Skip if smaller
MAX_CARVED_FILES=1000       # Limit recovered files

# Logging
LOG_LEVEL=INFO              # DEBUG, INFO, WARNING, ERROR
```

---

## FAQ

<details>
<summary><strong>Does DMS modify the evidence/disk?</strong></summary>

**No.** DMS operates in read-only mode. It reads raw disk data without writing anything to the source device or image. EWF images are mounted read-only using FUSE.

</details>

<details>
<summary><strong>Can I scan a live/running system?</strong></summary>

Yes, but with caveats:
- Use `--mount` to enable filesystem-level analysis
- Rootkit detection (`--rootkit`) works best on mounted systems
- For best results, boot from a forensic live USB and scan the offline disk

</details>

<details>
<summary><strong>What if I don't have tools installed?</strong></summary>

Use `--portable` mode! DMS will automatically download and use portable versions of all required tools:

```bash
sudo ./malware_scan.sh --interactive --portable
```

</details>

<details>
<summary><strong>Can I use custom YARA rules?</strong></summary>

Yes! Set `YARA_RULES_BASE` in your config file:

```bash
YARA_RULES_BASE=/path/to/my/yara-rules
```

Rules should be in subdirectories: `Windows/`, `Linux/`, `Android/`

</details>

<details>
<summary><strong>How do I integrate with VirusTotal?</strong></summary>

1. Get a free API key from [VirusTotal](https://www.virustotal.com/gui/join-us)
2. Add to config: `VT_API_KEY=your_key_here`
3. Enable in interactive mode or use `--virustotal` flag

</details>

---

## Contributing

Contributions are welcome! Here's how to help:

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/dms.git
cd dms

# Create feature branch
git checkout -b feature/amazing-feature

# Make changes and test
./malware_scan.sh --help
sudo ./malware_scan.sh /dev/sdX --dry-run

# Commit and push
git commit -m "Add amazing feature"
git push origin feature/amazing-feature

# Open Pull Request
```

### Areas for Contribution

- [ ] Additional YARA rule sets
- [ ] New detection engines
- [ ] Performance optimizations
- [ ] Documentation improvements
- [ ] Bug fixes

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Acknowledgments

| Project | Role in DMS |
|---------|-------------|
| [Tsurugi Linux](https://tsurugi-linux.org/) | Target forensic distribution |
| [ClamAV](https://www.clamav.net/) | Signature-based detection |
| [YARA](https://virustotal.github.io/yara/) | Pattern matching engine |
| [Qu1cksc0pe](https://github.com/CYB3RMX/Qu1cksc0pe) | YARA rules collection |
| [The Sleuth Kit](https://sleuthkit.org/) | Forensic tools |
| [Binwalk](https://github.com/ReFirmLabs/binwalk) | Firmware analysis |
| [Bulk Extractor](https://github.com/simsong/bulk_extractor) | Artifact extraction |

---

<p align="center">
  <img src="https://img.shields.io/badge/Made%20with-Bash-1f425f.svg?style=for-the-badge" alt="Made with Bash">
  <img src="https://img.shields.io/badge/Made%20for-Forensics-critical?style=for-the-badge" alt="Made for Forensics">
</p>

<p align="center">
  <strong>DMS v2.1</strong><br>
  Built for <a href="https://tsurugi-linux.org/">Tsurugi Linux</a> | Works on any Linux
</p>

<p align="center">
  <a href="https://github.com/Samuele95/dms/issues">Report Bug</a> •
  <a href="https://github.com/Samuele95/dms/issues">Request Feature</a> •
  <a href="https://github.com/Samuele95/dms/stargazers">Star this Project</a>
</p>
