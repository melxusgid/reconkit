# ReconKit

Domain reconnaissance for macOS. Free and open source.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## What it does

Enter a domain, click Scan, get a full report:

- **DNS Records** — A, AAAA, MX, NS, TXT, SOA
- **SSL Certificates** — expiry, issuer, transparency logs
- **HTTP Headers** — security headers, server tech, redirects
- **Port Scanning** — open ports and services
- **Reputation** — VirusTotal integration (optional API key)

Everything runs locally on your Mac. No data is sent to any server.

## Download

[**Download ReconKit.dmg**](https://github.com/melxusgid/reconkit/releases/latest)

Requires macOS 14 (Sonoma) or later.

**First launch:** macOS will show "unidentified developer." Right-click the app → Open to bypass. This is because ReconKit is not yet notarized with Apple.

## Build from source

```bash
git clone https://github.com/melxusgid/reconkit.git
cd reconkit
open ReconKit.xcodeproj
```

Build and run in Xcode. Requires macOS 14+ SDK.

## Architecture

```
ReconKit/
├── ReconKitApp.swift          # App entry point
├── ContentView.swift          # Main scan interface
├── ScanEngine.swift           # Core scanning logic
├── ScanCoordinator.swift      # Orchestrates scan phases
├── DNSClient.swift            # DNS record lookup
├── HTTPProbe.swift            # HTTP header analysis
├── NetworkProbes.swift        # Port scanning
├── CertTransparency.swift     # CT log queries
├── ReputationScanner.swift    # VirusTotal integration
├── ReportView.swift           # Scan results display
├── ReportPDF.swift            # PDF export
├── ExportService.swift        # Export formats
├── Models.swift               # Data models
├── Theme.swift                # UI styling
└── SampleData.swift           # Demo scan data
```

## Privacy

- No analytics
- No telemetry
- No user accounts
- No data leaves your machine (except the DNS/HTTP queries that are the scan itself)
- VirusTotal integration is opt-in and requires your own API key

## License

MIT

## Built by

[FromTheScope](https://fromthescope.com) — automated security scanning with human-reviewed findings.
