<p align="center">
  <pre>
██████╗ ███╗   ███╗███████╗
██╔══██╗████╗ ████║██╔════╝
██║  ██║██╔████╔██║███████╗
██║  ██║██║╚██╔╝██║╚════██║
██████╔╝██║ ╚═╝ ██║███████║
╚═════╝ ╚═╝     ╚═╝╚══════╝
  </pre>
  <strong>Drive Malware Scan</strong><br>
  <em>Advanced Malware Detection & Forensic Analysis for Tsurugi Linux</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-2.1-blue.svg" alt="Version 2.1">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT License">
  <img src="https://img.shields.io/badge/platform-Linux-lightgrey.svg" alt="Linux">
  <img src="https://img.shields.io/badge/made%20for-Tsurugi%20Linux-orange.svg" alt="Made for Tsurugi Linux">
  <img src="https://img.shields.io/badge/bash-4.0%2B-89e051.svg" alt="Bash 4.0+">
</p>

---

## Features

| | Feature | Description |
|---|---------|-------------|
| :microscope: | **Deep Analysis** | Entropy analysis, file carving, boot sector inspection |
| :mag: | **Multi-Scanner** | ClamAV + YARA + Binwalk + Strings + Bulk Extractor |
| :bar_chart: | **Smart Reporting** | Text, HTML, and JSON reports with actionable guidance |
| :lock: | **Forensic Grade** | EWF/E01 image support with hash verification |
| :zap: | **Parallel Scanning** | Multi-threaded scanning for faster results |
| :floppy_disk: | **Slack Space Recovery** | Analyze unallocated space for hidden threats |
| :globe_with_meridians: | **VirusTotal Integration** | Hash lookup via VT API |
| :package: | **Portable Mode** | Auto-download missing tools on the fly |

---

## Quick Start

```bash
# Clone or download
git clone https://github.com/Samuele95/dms.git
cd dms

# Make executable
chmod +x malware_scan.sh

# Run your first scan
sudo ./malware_scan.sh /dev/sdb1
```

**Expected Output:**
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
...
```

---

## Installation

### Prerequisites

**Required tools:**
```bash
sudo apt install clamav yara binutils binwalk
```

**For deep scanning:**
```bash
sudo apt install foremost bulk-extractor ssdeep libimage-exiftool-perl md5deep
```

**For slack space analysis:**
```bash
sudo apt install sleuthkit
```

**For EWF/E01 forensic images:**
```bash
sudo apt install libewf-tools
```

### Install DMS

```bash
# Option 1: Clone repository
git clone https://github.com/Samuele95/dms.git
cd dms
chmod +x malware_scan.sh

# Option 2: Download script directly
curl -O https://raw.githubusercontent.com/Samuele95/dms/main/malware_scan.sh
chmod +x malware_scan.sh

# Verify installation
./malware_scan.sh --help
```

### Portable Mode (No Pre-installed Tools)

DMS can auto-download missing tools:

```bash
sudo ./malware_scan.sh /dev/sdb1 --portable
```

---

## Usage

### Basic Examples

```bash
# Scan a partition
sudo ./malware_scan.sh /dev/sdb1

# Scan with ClamAV database update
sudo ./malware_scan.sh /dev/sdb1 --update

# Mount before scanning (for filesystem-level analysis)
sudo ./malware_scan.sh /dev/sdb1 --mount --update
```

### Deep Forensic Scan

```bash
# Full deep scan with all analysis modules
sudo ./malware_scan.sh /dev/sdb1 --deep

# Deep scan with parallel processing
sudo ./malware_scan.sh /dev/sdb1 --deep --parallel --auto-chunk
```

### Forensic Image Scanning

```bash
# Scan EWF/E01 image (auto-detected)
sudo ./malware_scan.sh evidence.E01

# Verify hash integrity before scanning
sudo ./malware_scan.sh evidence.E01 --verify-hash

# Scan raw disk image
sudo ./malware_scan.sh disk.raw --input-format raw
```

### Slack Space Analysis

```bash
# Scan only unallocated space (hidden/deleted data)
sudo ./malware_scan.sh /dev/sdb1 --slack

# Slack space scan on forensic image
sudo ./malware_scan.sh evidence.E01 --scan-mode slack
```

### Report Generation

```bash
# Generate all report formats
sudo ./malware_scan.sh /dev/sdb1 --html --json

# Custom output file
sudo ./malware_scan.sh /dev/sdb1 --output /cases/case001/report.txt
```

### Interactive Mode

```bash
# Launch interactive TUI
sudo ./malware_scan.sh --interactive
```

The interactive mode provides a menu-driven interface for configuring scan options.

---

## Scan Modes Explained

### Full Scan (Default)
Scans the entire drive or image, including:
- All allocated data
- File system structures
- Boot sectors
- Partition tables

```bash
sudo ./malware_scan.sh /dev/sdb1  # Full scan is default
```

### Slack Space Scan
Focuses on unallocated disk space where deleted files and hidden data may reside:
- Extracts unallocated space using `blkls`
- Carves recoverable files
- Analyzes recovered data for threats

```bash
sudo ./malware_scan.sh /dev/sdb1 --slack
```

### Quick Scan
Sample-based analysis for rapid triage:
- Strategic sampling of disk regions
- Entropy analysis on samples
- Identifies areas needing deeper investigation

```bash
sudo ./malware_scan.sh /dev/sdb1 --quick
```

### Deep Scan
Comprehensive forensic analysis:
- All basic scans plus:
- Entropy analysis (detect encrypted/packed data)
- File carving (recover deleted files)
- Executable header detection
- Boot sector analysis
- Bulk extraction (emails, URLs, credit cards)

```bash
sudo ./malware_scan.sh /dev/sdb1 --deep
```

---

## Configuration

### Config File

Create `~/.malscan.conf` or `/etc/malscan.conf`:

```bash
# Performance
CHUNK_SIZE=500
MAX_PARALLEL_JOBS=4

# Paths
CLAMDB_DIR=/tmp/clamdb
YARA_RULES_BASE=/opt/Qu1cksc0pe/Systems

# VirusTotal (optional)
VT_API_KEY=your_api_key_here
VT_RATE_LIMIT=4

# Logging
LOG_LEVEL=INFO
```

### Quick Reference

| Option | Description |
|--------|-------------|
| `-m, --mount` | Mount device before scanning |
| `-u, --update` | Update ClamAV databases |
| `-d, --deep` | Enable deep scan |
| `-p, --parallel` | Enable parallel scanning |
| `-q, --quiet` | Minimal output |
| `-v, --verbose` | Debug output |
| `-i, --interactive` | Interactive TUI mode |
| `--slack` | Scan unallocated space only |
| `--quick` | Fast sample-based scan |
| `--html` | Generate HTML report |
| `--json` | Generate JSON report |
| `--verify-hash` | Verify EWF image integrity |
| `--portable` | Auto-download missing tools |
| `--keep-output` | Preserve temp files |

See [SPEC.md](SPEC.md) for complete configuration reference.

---

## Supported Formats

### Input Types

| Format | Extensions | Description |
|--------|------------|-------------|
| Block Device | `/dev/sdX` | Physical drives/partitions |
| EWF Image | `.E01`, `.Ex01`, `.L01` | Expert Witness Format |
| Raw Image | `.raw`, `.dd`, `.img`, `.bin` | Raw disk images |

### Report Formats

| Format | Description |
|--------|-------------|
| **Text** | Plain text with ASCII formatting |
| **HTML** | Styled web page with tables |
| **JSON** | Machine-readable structured data |

---

## Detection Capabilities

DMS uses multiple detection engines:

| Engine | Capability |
|--------|------------|
| **ClamAV** | Signature-based malware detection |
| **YARA** | Pattern-based threat detection (Windows, Linux, Android, Documents) |
| **Binwalk** | Embedded file and firmware analysis |
| **Strings** | Suspicious URL, credential, and executable detection |
| **Entropy** | Encrypted/packed data identification |
| **Bulk Extractor** | Email, URL, credit card extraction |
| **chkrootkit/rkhunter** | Rootkit detection (optional) |

---

## Example Reports

### Text Report Preview
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

SCAN RESULTS
────────────
  ClamAV:              2 infected
  YARA Windows:        5 matches
  YARA Linux:          0 matches
  Entropy Analysis:    SUSPICIOUS
  Carved Files:        47 recovered

OVERALL STATUS
──────────────
STATUS: SUSPICIOUS
Total findings: 54
Manual review recommended.
```

### JSON Output Structure
```json
{
  "report": { "version": "2.1", "tool": "DMS" },
  "device": { "path": "/dev/sdb1", "size_gb": 128 },
  "results": {
    "clamav": 2,
    "yara_windows": 5,
    "carved_files": 47
  },
  "summary": { "total_findings": 54 }
}
```

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Use consistent 4-space indentation
- Add comments for complex logic
- Follow existing naming conventions
- Test on Tsurugi Linux when possible

---

## License

This project is licensed under the MIT License - see below for details:

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

## Credits

- **Tsurugi Linux** - The forensic distribution this tool is designed for
- **ClamAV** - Open source antivirus engine
- **YARA** - Pattern matching swiss knife for malware researchers
- **Qu1cksc0pe** - YARA rules collection
- **The Sleuth Kit** - Digital forensics tools
- **Binwalk** - Firmware analysis tool
- **Bulk Extractor** - Digital forensics tool

---

<p align="center">
  <strong>DMS v2.1</strong> | Made for <a href="https://tsurugi-linux.org/">Tsurugi Linux</a>
</p>
