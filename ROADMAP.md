# ReconKit Roadmap

ReconKit is a native macOS domain-reconnaissance app. This is a living document of
where it's headed — dates are intentionally omitted; things ship when they're ready.

## Shipped — v1.0
- Native macOS app, signed **and notarized** (opens with a double-click)
- **8 scan modules** — Overview, Subdomains, DNS, SSL, HTTP, Ports, WHOIS, Reputation
- 0–100 **security score** with a letter grade and a prioritized action plan
- **PDF export**, scan **monitoring + diff** tracking
- VirusTotal integration (your own key, stored in the Keychain)
- In-app documentation + startup update check

## Next
- **Structured output** — JSON and Markdown report exports for pipelines and write-ups
- **More checks** — subdomain takeover / dangling CNAME, deeper email-auth (SPF/DKIM/DMARC), expanded HTTP & tech fingerprinting
- **Homebrew cask** — `brew install --cask reconkit`

## Exploring — a cross-platform CLI
The macOS app stays native (SwiftUI). The cross-platform path is a `reconkit`
**command-line tool** that shares the scan engine and runs on **Linux and Windows**.

Why a CLI rather than a cross-platform GUI: most of the engine is already portable
Swift + Foundation. The Apple-specific pieces are the socket/TLS layer
(Network.framework) and the Keychain — replaceable with SwiftNIO and a config/env
key. A CLI also fits automation and CI, which is where a tool like this earns its keep.

- Extract a UI-free `ReconKitCore` package
- Swap Network.framework → SwiftNIO for TCP/ports; resolve DNS via DoH over URLSession
- `swift-argument-parser` front-end with a table view plus `--json` / `--markdown`
- Build matrix: macOS (native) · Linux (container) · Windows (GitHub Actions runner)

## Not planned
- A cross-platform **GUI** (Electron/Qt rewrite). The Mac app stays Mac-native;
  cross-platform happens through the CLI instead.

---
Have an idea or a check you'd want added? Open an issue: <https://github.com/melxusgid/reconkit/issues>
