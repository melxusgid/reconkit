//
//  ContentView.swift
//  ReconKit
//
//  Hermes-styled shell: a dark, editor-grade layout — a near-black sidebar of
//  past scans beside a chrome-toned detail pane hosting the scan input, live
//  progress, and the tabbed report. Custom layout (not NavigationSplitView)
//  for full control over the chrome.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var coordinator: ScanCoordinator
    @State private var domainInput = ""
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @State private var showOnboarding = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(coordinator: coordinator)
                .frame(width: 248)
                .background(Theme.bgSidebar)
            Rectangle().fill(Theme.stroke).frame(width: 1)
            DetailView(coordinator: coordinator, domainInput: $domainInput)
                .frame(maxWidth: .infinity)
                .background(AppBackground())
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .frame(minWidth: 960, minHeight: 660)
        // Free & open source — every feature available to everyone.
        .sheet(isPresented: $coordinator.showDiff) {
            DiffSheet(diff: coordinator.lastDiff)
        }
        .sheet(isPresented: $coordinator.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(
                onLoadDemo: { coordinator.loadSample(); finishOnboarding() },
                onDismiss: { finishOnboarding() }
            )
        }
        .onAppear { if !hasOnboarded { showOnboarding = true } }
    }

    private func finishOnboarding() {
        hasOnboarded = true
        showOnboarding = false
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject var coordinator: ScanCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandHeader(onSettings: { coordinator.showSettings = true })
                .padding(.top, 34)        // clears the traffic-light controls
                .padding(.horizontal, 16)
                .padding(.bottom, 18)

            if !coordinator.watchlist.isEmpty {
                WatchSection(coordinator: coordinator)
                    .padding(.bottom, 14)
            }

            Text("RECENT SCANS")
                .font(Theme.mono(10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 4) {
                    if coordinator.history.isEmpty {
                        Text("No scans yet")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.top, 6)
                    }
                    ForEach(coordinator.history) { report in
                        SidebarRow(report: report,
                                   selected: report.id == coordinator.selectedID,
                                   watched: coordinator.isWatched(report.target))
                            .onTapGesture { coordinator.selectedID = report.id }
                            .contextMenu {
                                Button("Delete", role: .destructive) { coordinator.delete(report) }
                            }
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 0)

            Button {
                coordinator.loadSample()
            } label: {
                Label("Load Demo Scan", systemImage: "sparkles")
                    .font(Theme.sans(12, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccentButtonStyle(prominent: false))
            .padding(12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct BrandHeader: View {
    var onSettings: () -> Void = {}
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.accentGradient)
                    .frame(width: 28, height: 28)
                    .glow(Theme.accent, radius: 7, opacity: 0.5)
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("ReconKit")
                    .font(Theme.sans(16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("domain recon")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.accentSoft)
            }
            Spacer()
            Button(action: { openWindow(id: "docs") }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Help & Docs")
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings & API keys")
            .tooltip("Settings & API keys")
        }
    }
}

struct SidebarRow: View {
    let report: ScanReport
    let selected: Bool
    var watched: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(report.rating.color)
                .frame(width: 7, height: 7)
                .glow(report.rating.color, radius: 4, opacity: 0.9)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(report.target)
                        .font(Theme.sans(13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if watched {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.gold)
                    }
                }
                Text(report.date, format: .dateTime.month().day().hour().minute())
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Text("\(report.score)")
                .font(Theme.mono(12, weight: .bold))
                .foregroundStyle(report.rating.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(selected ? Theme.accent.opacity(0.16) : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(selected ? Theme.accent.opacity(0.55) : .clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Detail

struct DetailView: View {
    @ObservedObject var coordinator: ScanCoordinator
    @Binding var domainInput: String

    var body: some View {
        VStack(spacing: 0) {
            ScanBar(coordinator: coordinator, domainInput: $domainInput)
                .padding(.top, 28)
                .padding(.horizontal, 22)
                .padding(.bottom, 14)

            Group {
                if coordinator.isScanning {
                    ScanProgressView(coordinator: coordinator)
                } else if let report = coordinator.selectedReport {
                    ReportView(report: report, coordinator: coordinator)
                } else {
                    EmptyStateView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ScanBar: View {
    @ObservedObject var coordinator: ScanCoordinator
    @Binding var domainInput: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(">")
                    .font(Theme.mono(15, weight: .bold))
                    .foregroundStyle(Theme.accentSoft)
                TextField("scan a domain or url — e.g. example.com", text: $domainInput)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(14))
                    .foregroundStyle(Theme.textPrimary)
                    .focused($focused)
                    .onSubmit(start)
                    .disabled(coordinator.isScanning)
                if coordinator.isScanning {
                    ProgressView().controlSize(.small).tint(Theme.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(focused ? Theme.accent.opacity(0.6) : Theme.stroke,
                                  lineWidth: focused ? 1.5 : 1)
            )
            .glow(focused ? Theme.accent : .clear, radius: 8, opacity: focused ? 0.25 : 0)

            Button(action: start) {
                Text(coordinator.isScanning ? "Scanning" : "Scan")
                    .frame(minWidth: 58)
            }
            .buttonStyle(AccentButtonStyle())
            .disabled(domainInput.trimmingCharacters(in: .whitespaces).isEmpty || coordinator.isScanning)
        }
        .animation(.easeOut(duration: 0.15), value: focused)
        .onAppear { focused = true }
        .onChange(of: coordinator.requestScanFocus) { _, requested in
            if requested {
                focused = true
                coordinator.requestScanFocus = false
            }
        }
    }

    private func start() { coordinator.runScan(target: domainInput) }
}

// MARK: - Empty state

struct EmptyStateView: View {
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Theme.accent.opacity(0.45 - Double(i) * 0.13), lineWidth: 1.5)
                        .frame(width: 84 + CGFloat(i) * 46, height: 84 + CGFloat(i) * 46)
                        .scaleEffect(pulse ? 1.08 : 0.96)
                        .opacity(pulse ? 0.3 : 0.9)
                        .animation(.easeInOut(duration: 2).repeatForever().delay(Double(i) * 0.3), value: pulse)
                }
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Theme.accentSoft)
                    .glow(Theme.accent, radius: 16, opacity: 0.55)
            }
            .frame(height: 190)

            Text("See what the internet knows\nabout your domain.")
                .font(Theme.sans(22, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("DNS · TLS · HTTP security headers · open ports · WHOIS")
                .font(Theme.mono(12))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding()
        .onAppear { pulse = true }
    }
}

#Preview {
    ContentView(coordinator: ScanCoordinator())
}
