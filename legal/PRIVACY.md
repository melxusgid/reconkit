# ReconKit — Privacy Policy

_Last updated: 2026-06-04_

ReconKit is a native macOS application for domain reconnaissance and security
auditing. This policy explains what data the app handles. **In plain terms: we
(the developer) do not collect, store, transmit, or sell any of your personal
data. ReconKit has no analytics, no accounts, and no backend server operated by
us.**

## What ReconKit stores

- **On your Mac only:** your scan history, watchlist, and settings are saved
  locally in the app's sandboxed Application Support container. They never leave
  your device unless you explicitly export a report.
- **In your macOS Keychain:** any API key you choose to enter (e.g. VirusTotal)
  is stored in the Keychain on your Mac. It is never transmitted to us and is
  only sent directly to the corresponding third-party service when you scan.

## What leaves your Mac, and to whom

When you run a scan, the **domain you enter** (and, for some checks, its
resolved IP) is sent **directly from your Mac** to the following third-party
services so they can return reconnaissance data. We do not proxy, see, or log
these requests:

| Service | Purpose | Their privacy policy |
|---|---|---|
| Cloudflare (1.1.1.1) | DNS resolution | cloudflare.com/privacypolicy |
| crt.sh (Sectigo) | Certificate Transparency / subdomains | sectigo.com/privacy-policy |
| SSLMate Cert Spotter | Subdomain discovery (fallback) | sslmate.com/privacy |
| Have I Been Pwned | Known-breach lookup | haveibeenpwned.com/Privacy |
| VirusTotal | Domain reputation (only if you add a key) | virustotal.com/gui/privacy-policy |
| IANA / domain registries | WHOIS lookups | iana.org |
| Target web server | HTTP headers, TLS certificate, open-port checks | n/a |

Only the domain/host you choose to scan is shared. No information about you
personally is included in these requests beyond what the network protocols
inherently expose (e.g. your IP address, visible to any server you connect to).

## Data we collect about you

**None.** ReconKit contains no analytics SDKs, no telemetry, no crash
reporting that identifies you, and no advertising.

## Children

ReconKit is a professional tool and is not directed at children.

## Changes

We may update this policy; the "last updated" date will change accordingly.

## Contact

Operated by Donovan L., trading as FromTheScope.
support@fromthescope.com
