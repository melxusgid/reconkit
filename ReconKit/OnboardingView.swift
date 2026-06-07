//
//  OnboardingView.swift
//  ReconKit
//
//  First-run welcome shown once to new users. Explains what ReconKit does,
//  offers a demo scan, and points to Settings for an optional VirusTotal key.
//

import SwiftUI

struct OnboardingView: View {
    var onLoadDemo: () -> Void
    var onDismiss: () -> Void

    private let features: [(icon: String, title: String, detail: String)] = [
        ("globe", "DNS & subdomains", "Records, mail/security hygiene, and live hosts from CT logs"),
        ("lock.shield", "SSL & HTTP", "Certificate health, TLS versions, and security headers"),
        ("point.3.connected.trianglepath.dotted", "Ports & WHOIS", "Open services and domain registration data"),
        ("shield.lefthalf.filled", "Reputation", "Have I Been Pwned, URLhaus, and VirusTotal verdicts"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.accentGradient)
                        .frame(width: 60, height: 60)
                        .glow(Theme.accent, radius: 14, opacity: 0.5)
                    Image(systemName: "binoculars.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Welcome to ReconKit")
                    .font(Theme.sans(24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("One scan replaces a dozen recon tools — DNS, SSL, HTTP, ports, WHOIS, and reputation — compiled into a single ranked report you can export to PDF.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 400)
            }
            .padding(.top, 32)
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 13) {
                ForEach(features, id: \.title) { f in
                    HStack(spacing: 12) {
                        Image(systemName: f.icon)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.accentSoft)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(f.title)
                                .font(Theme.sans(13, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(f.detail)
                                .font(Theme.sans(11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .padding(.horizontal, 24)

            Text("Everything runs locally — no account, no tracking. Add a VirusTotal key in Settings for reputation checks. Open the docs anytime from the ? button.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 400)
                .padding(.top, 14)

            Spacer(minLength: 18)

            HStack(spacing: 10) {
                Button { onLoadDemo() } label: {
                    Label("Try a demo scan", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle(prominent: false))

                Button { onDismiss() } label: {
                    Text("Get started").frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 470, height: 600)
        .background(Theme.bgChrome)
    }
}
