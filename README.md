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
  <a href="#-features">Features</a> •
  <a href="#-use-cases">Use Cases</a> •
  <a href="#-documentation">Docs</a> •
  <a href="#-contributing">Contributing</a>
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

DMS combines **12+ scanning techniques** into a single, easy-to-use command-line tool with an optional interactive TUI, producing actionable reports that guide your investigation.

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

### The Solution

DMS provides a **forensically-sound**, **comprehensive**, and **efficient** approach:

```
┌─────────────────────────────────────────────────────────────────┐
│                        ONE COMMAND                              │
│                              │                                  │
│            sudo ./malware_scan.sh evidence.E01 --deep           │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ ClamAV  │ │  YARA   │ │ Entropy │ │ Carving │ │ Strings │   │
│  │  Scan   │ │  Rules  │ │Analysis │ │ Files   │ │ Extract │   │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘   │
│       └───────────┴───────────┴───────────┴───────────┘         │
│                              │                                  │
│                              ▼                                  │
│              ┌───────────────────────────────┐                  │
│              │   UNIFIED FORENSIC REPORT     │                  │
│              │   with Actionable Guidance    │                  │
│              └───────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
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
| **YARA** | Custom pattern rules |
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
| :microscope: | **Deep Analysis** | Entropy analysis, file carving, PE/ELF header detection, boot sector inspection |
| :mag: | **Multi-Engine Scanning** | ClamAV signatures + YARA rules + Binwalk + Strings + Bulk Extractor |
| :bar_chart: | **Smart Reporting** | Text, HTML, and JSON reports with prioritized actionable guidance |
| :lock: | **Forensic Integrity** | Read-only operations, EWF hash verification, evidence preservation |
| :zap: | **Parallel Processing** | Multi-threaded scanning with automatic chunk optimization |
| :floppy_disk: | **Slack Space Recovery** | Extract and analyze unallocated disk space for hidden threats |
| :globe_with_meridians: | **VirusTotal Integration** | Automatic hash lookup via VT API for threat intelligence |
| :package: | **Portable Mode** | Zero-install option - auto-downloads required tools |
| :desktop_computer: | **Interactive TUI** | User-friendly menu-driven interface for scan configuration |
| :arrows_counterclockwise: | **Checkpoint/Resume** | Resume interrupted scans without losing progress |

---

## Use Cases

### 1. Incident Response: Compromised Workstation

**Scenario:** A user reports suspicious activity. You need to quickly assess if malware is present.

```bash
# Quick triage scan
sudo ./malware_scan.sh /dev/sda1 --quick

# If threats found, perform deep analysis
sudo ./malware_scan.sh /dev/sda1 --deep --parallel --html
```

**What DMS Does:**
- Quick scan samples strategic disk regions for rapid assessment
- Deep scan recovers deleted files, checks entropy, analyzes boot sector
- HTML report provides clickable findings for your incident report

---

### 2. Digital Forensics: Evidence Analysis

**Scenario:** Law enforcement provides an E01 forensic image from a seized computer.

```bash
# Verify evidence integrity and scan
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

### 5. Field Operations: No Pre-installed Tools

**Scenario:** Responding to an incident with only a bootable USB.

```bash
# Portable mode downloads and runs tools automatically
sudo ./malware_scan.sh /dev/sdb1 --portable --portable-keep

# Subsequent scans use cached tools
sudo ./malware_scan.sh /dev/sdc1 --portable
```

**What DMS Does:**
- Automatically downloads ClamAV, YARA, and dependencies
- Stores tools in `/tmp/malscan_portable_tools` for reuse
- Works on any Linux system with internet access
- `--portable-keep` preserves tools for offline use later

---

## Quick Start

### One-Line Install

```bash
git clone https://github.com/Samuele95/dms.git && cd dms && chmod +x malware_scan.sh
```

### First Scan

```bash
# Basic scan of a partition
sudo ./malware_scan.sh /dev/sdb1

# Or use interactive mode
sudo ./malware_scan.sh --interactive
```

### Expected Output

```
╔═══════════════════════════════════════════════════════════════╗
║           ██████╗ ███╗   ███╗███████╗                         ║
║           ██║  ██║██╔████╔██║███████╗                         ║
║           ██████╔╝██║ ╚═╝ ██║███████║                         ║
║                                                               ║
║             D R I V E   M A L W A R E   S C A N               ║
╠═══════════════════════════════════════════════════════════════╣
║                  DMS v2.1  |  EWF Support                     ║
╚═══════════════════════════════════════════════════════════════╝

[*] Checking Required Tools
[+] clamscan found
[+] yara found
[+] strings found
[+] binwalk found

═══════════════════════════════════════════════════════════════
 Device Information
═══════════════════════════════════════════════════════════════
[*] Validating input: /dev/sdb1
[+] Block device detected
[*] Device size: 128 GB
[*] Filesystem: ntfs

═══════════════════════════════════════════════════════════════
 ClamAV Scan
═══════════════════════════════════════════════════════════════
[*] Scanning with ClamAV...
[+] Scan complete: 2 infected files found

═══════════════════════════════════════════════════════════════
 YARA Scan
═══════════════════════════════════════════════════════════════
[*] Scanning with YARA rules...
[+] Windows rules: 5 matches
[+] Linux rules: 0 matches
...
```

---

## Installation

### Prerequisites

<details>
<summary><strong>Debian/Ubuntu (including Tsurugi Linux)</strong></summary>

```bash
# Core tools (required)
sudo apt update
sudo apt install clamav clamav-daemon yara binutils binwalk

# Deep scan tools (recommended)
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

### Install DMS

```bash
# Clone the repository
git clone https://github.com/Samuele95/dms.git
cd dms

# Make executable
chmod +x malware_scan.sh

# (Optional) Install system-wide
sudo ln -s $(pwd)/malware_scan.sh /usr/local/bin/dms

# Verify installation
./malware_scan.sh --help
```

### Portable Mode (Zero Dependencies)

Don't have tools installed? No problem:

```bash
# DMS will download what it needs
sudo ./malware_scan.sh /dev/sdb1 --portable
```

---

## Usage Examples

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

### Advanced Options

```bash
# Resume interrupted scan
sudo ./malware_scan.sh /dev/sdb1 --resume /tmp/malware_scan_12345/.checkpoint

# Dry run (preview what would be done)
sudo ./malware_scan.sh /dev/sdb1 --deep --dry-run

# Custom configuration file
sudo ./malware_scan.sh /dev/sdb1 --config /etc/dms/custom.conf

# Verbose logging to file
sudo ./malware_scan.sh /dev/sdb1 --verbose --log-file /var/log/dms-scan.log
```

---

## Scan Modes Explained

| Mode | Command | Speed | Coverage | Use Case |
|------|---------|-------|----------|----------|
| **Standard** | `./malware_scan.sh /dev/sdb1` | Medium | Allocated data | General malware detection |
| **Quick** | `--quick` | Fast | Sampled regions | Rapid triage, preliminary assessment |
| **Deep** | `--deep` | Slow | Everything | Full forensic analysis |
| **Slack** | `--slack` | Medium | Unallocated only | Deleted file recovery, hidden threats |
| **Parallel** | `--parallel` | Faster | Same as mode | Multi-core acceleration |

### Mode Details

<details>
<summary><strong>Standard Scan</strong></summary>

The default mode runs:
- ClamAV signature scan
- YARA rule matching (Windows, Linux, Android, Documents)
- Binwalk embedded file detection
- Strings analysis for IOCs

```bash
sudo ./malware_scan.sh /dev/sdb1
```

</details>

<details>
<summary><strong>Quick Scan</strong></summary>

Sample-based analysis for rapid triage:
- Strategic sampling of disk regions
- Entropy checks on samples
- Identifies areas needing deeper investigation
- Ideal for "is this worth investigating?" decisions

```bash
sudo ./malware_scan.sh /dev/sdb1 --quick
```

</details>

<details>
<summary><strong>Deep Scan</strong></summary>

Comprehensive forensic analysis includes:
- All standard scans PLUS:
- Entropy analysis (detect encrypted/packed data)
- File carving (recover deleted files)
- Executable header detection (PE/ELF)
- Boot sector and MBR analysis
- Bulk extraction (emails, URLs, credit cards)
- Hash generation for all carved files

```bash
sudo ./malware_scan.sh /dev/sdb1 --deep
```

</details>

<details>
<summary><strong>Slack Space Scan</strong></summary>

Focuses on unallocated disk space:
- Extracts unallocated space using `blkls` (Sleuth Kit)
- Carves recoverable files from slack
- Scans all recovered data for threats
- Finds malware that was "deleted" but not overwritten

```bash
sudo ./malware_scan.sh /dev/sdb1 --slack
```

</details>

---

## Detection Capabilities

### Multi-Engine Architecture

```
                    ┌─────────────────────────────────────┐
                    │           INPUT LAYER               │
                    │  Block Device / EWF / Raw Image     │
                    └──────────────────┬──────────────────┘
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        │                              │                              │
        ▼                              ▼                              ▼
┌───────────────┐            ┌───────────────┐            ┌───────────────┐
│   SIGNATURE   │            │    PATTERN    │            │   HEURISTIC   │
│   DETECTION   │            │   MATCHING    │            │   ANALYSIS    │
├───────────────┤            ├───────────────┤            ├───────────────┤
│ • ClamAV      │            │ • YARA Rules  │            │ • Entropy     │
│   (1M+ sigs)  │            │   - Windows   │            │ • PE Headers  │
│ • VirusTotal  │            │   - Linux     │            │ • ELF Headers │
│   (70+ AVs)   │            │   - Android   │            │ • Boot Sector │
│               │            │   - Documents │            │ • Binwalk     │
└───────────────┘            └───────────────┘            └───────────────┘
        │                              │                              │
        └──────────────────────────────┼──────────────────────────────┘
                                       │
                                       ▼
                    ┌─────────────────────────────────────┐
                    │         ARTIFACT EXTRACTION         │
                    ├─────────────────────────────────────┤
                    │ • Strings (URLs, IPs, paths)        │
                    │ • Bulk Extractor (emails, CCNs)     │
                    │ • File Carving (deleted files)      │
                    │ • Slack Space Recovery              │
                    └─────────────────────────────────────┘
                                       │
                                       ▼
                    ┌─────────────────────────────────────┐
                    │          UNIFIED REPORT             │
                    │   Text / HTML / JSON + Guidance     │
                    └─────────────────────────────────────┘
```

### YARA Rule Categories

| Category | Target | Examples |
|----------|--------|----------|
| **Windows** | PE malware | Ransomware, trojans, RATs, droppers |
| **Linux** | ELF threats | Rootkits, backdoors, miners, botnets |
| **Android** | APK malware | Adware, spyware, banking trojans |
| **Documents** | Office/PDF | Macro malware, exploits, phishing docs |

### What Each Engine Detects

| Engine | Detection Type | Strengths |
|--------|---------------|-----------|
| **ClamAV** | Known malware signatures | Fast, 1M+ signatures, daily updates |
| **YARA** | Behavioral patterns | Custom rules, family detection, packed samples |
| **Entropy** | Encrypted/packed data | Finds hidden payloads, crypto artifacts |
| **Binwalk** | Embedded files | Firmware analysis, nested archives |
| **Strings** | IOC extraction | C2 URLs, file paths, credentials |
| **Bulk Extractor** | Forensic artifacts | Email addresses, credit cards, URLs |

---

## Report Formats

### Text Report

Human-readable ASCII report with scan summary and findings.

```
═══════════════════════════════════════════════════════════════
              TSURUGI LINUX MALWARE SCAN REPORT
              Generated: Mon Jan 20 15:30:00 UTC 2026
═══════════════════════════════════════════════════════════════

DEVICE INFORMATION
──────────────────
Device:     /dev/sdb1
Size:       128 GB
Filesystem: ntfs
Scan Type:  DEEP SCAN
Parallel:   YES

SCAN RESULTS
────────────
Basic Scans:
  ClamAV:              2 infected
  YARA Windows:        5 matches
  YARA Linux:          0 matches
  YARA Android:        0 matches
  YARA Documents:      1 matches
  Binwalk:             12 findings
  String Analysis:     47 patterns

Deep Scan Results:
  Entropy Analysis:    SUSPICIOUS (3 high-entropy regions)
  Carved Files:        156 recovered
  Carved Malware:      3 infected
  PE Executables:      24 found
  Boot Sector:         Normal

RECOMMENDED ACTIONS
───────────────────
1. CLAMAV (Critical priority)
   Reason: 2 known malware signature(s) detected
   Action: Isolate and analyze infected files immediately
   Files:  $OUTPUT_DIR/clamav_results/

2. YARA (High priority)
   Reason: 6 rule(s) matched specific threat patterns
   Action: Extract and analyze data at matched offsets
   Files:  $OUTPUT_DIR/yara_matches/

OVERALL STATUS
──────────────
STATUS: SUSPICIOUS
Total findings: 68
Manual review recommended.

═══════════════════════════════════════════════════════════════
Scan output directory: /tmp/malware_scan_12345
```

### HTML Report

Professional web-based report with styling, perfect for sharing with stakeholders.

```bash
sudo ./malware_scan.sh /dev/sdb1 --html
# Opens: /tmp/malware_scan_12345/scan_report_20260120_153000.html
```

### JSON Report

Machine-readable format for integration with SIEMs, case management, or scripts.

```json
{
    "report": {
        "version": "2.1",
        "generated": "2026-01-20T15:30:00+00:00",
        "tool": "DMS - Drive Malware Scanner"
    },
    "device": {
        "path": "/dev/sdb1",
        "size_gb": 128,
        "filesystem": "ntfs"
    },
    "scan_config": {
        "mode": "full",
        "type": "deep",
        "parallel": true
    },
    "results": {
        "clamav": 2,
        "yara_windows": 5,
        "yara_linux": 0,
        "entropy": 1,
        "carved_files": 156,
        "carved_malware": 3
    },
    "summary": {
        "total_findings": 68,
        "status": "suspicious"
    }
}
```

---

## Configuration

### Configuration File

Create `~/.malscan.conf`, `/etc/malscan.conf`, or `./malscan.conf`:

```bash
# ============================================
# DMS Configuration File
# ============================================

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

# Display
NO_COLOR=false
HIGH_CONTRAST=false
```

### CLI Options Reference

| Option | Short | Description |
|--------|-------|-------------|
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
| `--interactive` | `-i` | Interactive TUI mode |
| `--verify-hash` | | Verify EWF image integrity |
| `--virustotal` | | Enable VT hash lookup |
| `--rootkit` | | Run rootkit detection |
| `--timeline` | | Generate file timeline |
| `--portable` | | Auto-download missing tools |
| `--portable-keep` | | Keep portable tools after scan |
| `--keep-output` | | Preserve temp files |
| `--resume FILE` | | Resume from checkpoint |
| `--config FILE` | | Custom config file |
| `--log-file FILE` | | Write logs to file |
| `--output FILE` | `-o` | Custom output path |
| `--dry-run` | | Preview without executing |

---

## Supported Formats

### Input Types

| Type | Extensions | Auto-Detected | Notes |
|------|------------|---------------|-------|
| Block Device | `/dev/sdX`, `/dev/nvmeXnY` | Yes | Physical drives and partitions |
| EWF Image | `.E01`, `.E02`, `.Ex01`, `.L01` | Yes | Expert Witness Format (forensic standard) |
| Raw Image | `.raw`, `.dd`, `.img`, `.bin` | Yes | Raw disk dumps |

### Force Input Format

```bash
# If auto-detection fails, force the format
sudo ./malware_scan.sh mystery_file --input-format ewf
sudo ./malware_scan.sh mystery_file --input-format raw
sudo ./malware_scan.sh mystery_file --input-format block
```

---

## FAQ

<details>
<summary><strong>Does DMS modify the evidence/disk?</strong></summary>

**No.** DMS operates in read-only mode. It reads raw disk data without writing anything to the source device or image. EWF images are mounted read-only using FUSE. This preserves forensic integrity.

</details>

<details>
<summary><strong>Can I scan a live/running system?</strong></summary>

Yes, but with caveats:
- Use `--mount` to enable filesystem-level analysis
- Rootkit detection (`--rootkit`) works best on mounted systems
- For best results, boot from a forensic live USB (like Tsurugi Linux) and scan the offline disk

</details>

<details>
<summary><strong>How long does a scan take?</strong></summary>

It depends on disk size and scan mode:
- **Quick scan**: Minutes (samples only)
- **Standard scan**: ~10-30 min per 100GB
- **Deep scan**: ~30-60 min per 100GB
- **Parallel mode**: 2-4x faster on multi-core systems

</details>

<details>
<summary><strong>What if I don't have all the tools installed?</strong></summary>

Use `--portable` mode! DMS will automatically download and use portable versions of ClamAV, YARA, and other tools.

```bash
sudo ./malware_scan.sh /dev/sdb1 --portable
```

</details>

<details>
<summary><strong>Can I use custom YARA rules?</strong></summary>

Yes! Set `YARA_RULES_BASE` in your config file to point to your rules directory:

```bash
YARA_RULES_BASE=/path/to/my/yara-rules
```

Rules should be organized in subdirectories: `Windows/`, `Linux/`, `Android/`, etc.

</details>

<details>
<summary><strong>How do I integrate with VirusTotal?</strong></summary>

1. Get a free API key from [VirusTotal](https://www.virustotal.com/gui/join-us)
2. Add to config: `VT_API_KEY=your_key_here`
3. Run with `--virustotal` flag

```bash
sudo ./malware_scan.sh /dev/sdb1 --virustotal
```

</details>

---

## Documentation

| Document | Description |
|----------|-------------|
| [SPEC.md](SPEC.md) | Complete technical specification |
| [malscan.conf](malscan.conf) | Example configuration file |
| `--help` | Built-in command reference |

---

## Contributing

Contributions are welcome! Here's how to help:

### Development Setup

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

### Code Style

- Use consistent 4-space indentation
- Add comments for complex logic
- Follow existing function naming conventions
- Test on Tsurugi Linux when possible
- Update documentation for new features

### Areas for Contribution

- [ ] Additional YARA rule sets
- [ ] New detection engines
- [ ] Performance optimizations
- [ ] Documentation improvements
- [ ] Bug fixes and error handling
- [ ] Unit tests

---

## License

This project is licensed under the **MIT License**.

```
MIT License

Copyright (c) 2026 DMS Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Acknowledgments

DMS is built on the shoulders of giants:

| Project | Role in DMS |
|---------|-------------|
| [Tsurugi Linux](https://tsurugi-linux.org/) | Target forensic distribution |
| [ClamAV](https://www.clamav.net/) | Signature-based detection engine |
| [YARA](https://virustotal.github.io/yara/) | Pattern matching engine |
| [Qu1cksc0pe](https://github.com/CYB3RMX/Qu1cksc0pe) | YARA rules collection |
| [The Sleuth Kit](https://sleuthkit.org/) | Forensic tools (blkls, fls, mactime) |
| [Binwalk](https://github.com/ReFirmLabs/binwalk) | Firmware analysis |
| [Bulk Extractor](https://github.com/simsong/bulk_extractor) | Artifact extraction |
| [Foremost](http://foremost.sourceforge.net/) | File carving |

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
