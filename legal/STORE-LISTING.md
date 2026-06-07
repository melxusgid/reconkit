# ReconKit — App Store Listing Copy

Paste these into App Store Connect. Edit anything in [brackets].

## Name (30 char max)
ReconKit

## Subtitle (30 char max)
Domain security scanner

_Alternatives:_ "See what the web knows" · "Domain recon & audits"

## Category
Primary: **Developer Tools**  ·  Secondary: Utilities

## Promotional Text (170 char max — editable anytime without review)
Scan any domain for DNS, TLS, security headers, open ports, subdomains, WHOIS and threat-intel — then export a clean report. Private, native, no account.

## Description

ReconKit is a native macOS tool for domain reconnaissance and security audits.
Type a domain, hit Scan, and get a clear, prioritized picture of its public
security posture — then hand the report to a client, a colleague, or your AI
agent.

WHAT IT CHECKS
• Subdomains — maps the attack surface from Certificate Transparency logs
• DNS — records, SPF, DMARC, DNSSEC, CAA, nameserver redundancy
• TLS / SSL — certificate, expiry, SANs, chain, negotiated protocol version
• HTTP — security headers, cookie flags, HTTPS upgrade, tech fingerprint
• Open ports — common services with banner detection
• WHOIS — registrar, domain age, expiry
• Reputation — known breaches (Have I Been Pwned) and, with your own
  VirusTotal key, multi-vendor malware/blocklist verdicts

BUILT FOR REAL WORK
• A–F security grade with a prioritized, plain-English action plan
• Export to PDF (client-ready), Markdown, or JSON (for automation/AI agents)
• Watch domains and get notified when something changes
• Rescan and see an exact diff: new subdomains, opened ports, grade movement

PRIVATE BY DESIGN
No account. No tracking. No server we run. Scans go directly from your Mac to
public sources; results stay on your device. Your API keys live in your
Keychain and never leave your machine.

Free and open source. Every feature is available to everyone — no accounts,
no limits, no purchases.

Only scan domains you own or are authorized to assess.

## Keywords (100 char max, comma-separated, no spaces)
domain,dns,security,scanner,recon,whois,ssl,tls,subdomain,ports,osint,audit,headers,breach

## Support URL
https://reconkit.fromthescope.com  (a page with your contact email is enough)

## Marketing URL (optional)
https://reconkit.fromthescope.com

## Privacy Policy URL (required)
https://reconkit.fromthescope.com/privacy.html

## App Privacy (questionnaire answers)
Data collection: **No data collected.** ReconKit has no analytics, no accounts,
and no developer-operated backend. (The domain a user scans is sent directly to
third-party lookup services; we neither receive nor store it.)

## Encryption / Export Compliance
Uses only standard HTTPS/TLS. ITSAppUsesNonExemptEncryption = NO (already set in
the build).

---

## Screenshot shot list (you capture — 1280×800 or 1440×900, up to 10)
1. Full report on a real domain (Overview tab) — the score ring, grade, and
   action plan visible. Strongest hero shot.
2. Subdomains tab showing a long discovered list (e.g. github.com).
3. SSL tab — certificate details + negotiated TLS.
4. The exported PDF report (open it, screenshot the page) — sells the
   "client-ready" angle.
5. Reputation tab with a VirusTotal/breach result.
6. The diff sheet after a rescan ("Changes detected").

Tip: use a domain with rich results (github.com, a startup's domain). Capture
with ⌘⇧4 then Space to grab the window with its shadow.

## App Review notes (paste into the "Notes" field for the reviewer)
ReconKit performs read-only reconnaissance (DNS, WHOIS, TLS handshake, HTTP
header fetch, and lightweight TCP connect checks) against domains the user
chooses. It is intended for auditing domains the user owns or is authorized to
assess; this is stated in-app (Settings → Authorized Use) and in the Terms.
No exploitation, no credential testing, no traffic beyond standard public
lookups. The VirusTotal feature uses the user's own API key.
