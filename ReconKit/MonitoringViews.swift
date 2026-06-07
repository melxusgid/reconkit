//
//  MonitoringViews.swift
//  ReconKit
//
//  UI for the monitoring features: the sidebar watchlist with auto-rescan,
//  and the diff sheet shown after a rescan finds changes.
//

import SwiftUI

struct WatchSection: View {
    @ObservedObject var coordinator: ScanCoordinator

    var body: some View {
        fullWatchSection
    }

    private var fullWatchSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("WATCHING")
                    .font(Theme.mono(10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.gold)
                Spacer()
                Button {
                    coordinator.rescanAllWatched()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Rescan all watched domains")
                .tooltip("Rescan all watched domains")
                .disabled(coordinator.isScanning)
            }
            .padding(.horizontal, 16)

            ForEach(coordinator.watchedReports) { report in
                SidebarRow(report: report,
                           selected: report.id == coordinator.selectedID,
                           watched: false)
                    .onTapGesture { coordinator.selectedID = report.id }
                    .padding(.horizontal, 6)
            }

            Toggle(isOn: $coordinator.autoRescan) {
                Text("Auto-rescan hourly")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(Theme.accent)
            .padding(.horizontal, 16)
            .padding(.top, 2)
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vtKey: String = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.accentSoft)
                Text("Settings")
                    .font(Theme.sans(16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            .padding(18)
            Divider().overlay(Theme.stroke)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REPUTATION & THREAT INTEL")
                            .font(Theme.mono(10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(Theme.textTertiary)

                        Text("ReconKit checks Have I Been Pwned and URLhaus for free. Add your own VirusTotal API key to also scan each domain against 90+ security vendors and blocklists. Your key is stored in the macOS Keychain and never leaves this Mac.")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("VirusTotal API key")
                            .font(Theme.sans(12, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.top, 4)

                        SecureField("paste your VirusTotal API key", text: $vtKey)
                            .textFieldStyle(.plain)
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgElevated))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.stroke, lineWidth: 1))

                        HStack(spacing: 10) {
                            Button("Save") { save() }
                                .buttonStyle(AccentButtonStyle())
                            Button("Clear") {
                                vtKey = ""
                                KeyStore.set(nil, for: KeyStore.virusTotal)
                                saved = false
                            }
                            .buttonStyle(AccentButtonStyle(prominent: false))
                            if saved {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .font(Theme.sans(11))
                                    .foregroundStyle(Theme.green)
                            }
                            Spacer()
                            Link("Get a free key ↗", destination: URL(string: "https://www.virustotal.com/gui/my-apikey")!)
                                .font(Theme.sans(11))
                                .tint(Theme.accentSoft)
                        }
                    }
                    .padding(14)
                    .card()

                    creditsCard
                }
                .padding(18)
            }

            Divider().overlay(Theme.stroke)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(AccentButtonStyle())
            }
            .padding(16)
        }
        .frame(width: 480, height: 540)
        .background(Theme.bgChrome)
        .onAppear { vtKey = KeyStore.get(KeyStore.virusTotal) ?? "" }
    }

    private func save() {
        KeyStore.set(vtKey, for: KeyStore.virusTotal)
        withAnimation { saved = true }
    }

    private var creditsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AUTHORIZED USE & CREDITS")
                .font(Theme.mono(10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.textTertiary)

            legalLine("exclamationmark.shield.fill", Theme.gold,
                      "Only scan domains you own or are authorized to assess. Unauthorized scanning may be illegal.")
            legalLine("checkmark.seal.fill", Theme.accentSoft,
                      "Breach data from Have I Been Pwned, used under CC BY 4.0. Not endorsed by HIBP.")
            legalLine("key.fill", Theme.accentSoft,
                      "VirusTotal's free API is licensed for non-commercial use only. For commercial use, supply a paid VirusTotal key — you are responsible for your key's compliance.")
            legalLine("globe", Theme.textTertiary,
                      "Also uses Cloudflare DNS, crt.sh, SSLMate Cert Spotter, and public WHOIS. See the Privacy Policy.")

            HStack(spacing: 14) {
                Link("Privacy Policy", destination: URL(string: "https://reconkit.fromthescope.com/privacy")!)
                Link("Terms of Use", destination: URL(string: "https://reconkit.fromthescope.com/terms")!)
            }
            .font(Theme.sans(11, weight: .medium))
            .tint(Theme.accentSoft)
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func legalLine(_ symbol: String, _ color: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(text)
                .font(Theme.sans(11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DiffSheet: View {
    let diff: ScanDiff?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.accentSoft)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Changes detected")
                        .font(Theme.sans(16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if let diff {
                        Text(diff.target)
                            .font(Theme.mono(11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer()
            }
            .padding(18)

            Divider().overlay(Theme.stroke)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(diff?.changes ?? []) { change in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: icon(change.direction))
                                .font(.system(size: 12))
                                .foregroundStyle(color(change.direction))
                                .frame(width: 16)
                            Text(change.text)
                                .font(Theme.sans(13))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }
                }
                .padding(18)
            }

            Divider().overlay(Theme.stroke)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(AccentButtonStyle())
            }
            .padding(16)
        }
        .frame(width: 460, height: 440)
        .background(Theme.bgChrome)
    }

    private func icon(_ d: DiffChange.Direction) -> String {
        switch d {
        case .better: return "arrow.down.circle.fill"
        case .worse: return "exclamationmark.triangle.fill"
        case .neutral: return "minus.circle.fill"
        }
    }
    private func color(_ d: DiffChange.Direction) -> Color {
        switch d {
        case .better: return Theme.green
        case .worse: return Theme.danger
        case .neutral: return Theme.textTertiary
        }
    }
}
