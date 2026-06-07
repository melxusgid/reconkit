//
//  UpdateChecker.swift
//  ReconKit
//
//  Lightweight startup update check. Asks the GitHub releases API for the
//  latest tag and, if it's newer than the running build, surfaces a dismissible
//  banner that links to the download page. No third-party dependency; user data
//  (Keychain + Application Support container) is untouched by updates.
//

import SwiftUI
import Combine

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var latestVersion: String?   // e.g. "1.1"
    @Published var releaseURL: URL?

    private let endpoint = URL(string: "https://api.github.com/repos/melxusgid/reconkit/releases/latest")!
    private let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

    func check() async {
        var req = URLRequest(url: endpoint)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else { return }   // offline / error → stay silent
        let remote = tag.trimmingCharacters(in: CharacterSet(charactersIn: "v "))
        guard Self.isNewer(remote, than: current) else { return }
        latestVersion = remote
        if let urlString = json["html_url"] as? String { releaseURL = URL(string: urlString) }
    }

    /// Numeric, dot-separated version comparison (e.g. "1.10" > "1.9").
    static func isNewer(_ remote: String, than local: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        }
        let r = parts(remote), l = parts(local)
        for i in 0..<max(r.count, l.count) {
            let a = i < r.count ? r[i] : 0
            let b = i < l.count ? l[i] : 0
            if a != b { return a > b }
        }
        return false
    }
}

/// Slim banner shown at the top of the window when an update is available.
struct UpdateBanner: View {
    let version: String
    var onDownload: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.accentSoft)
            Text("ReconKit \(version) is available")
                .font(Theme.sans(12, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button("Download", action: onDownload)
                .buttonStyle(AccentButtonStyle(prominent: false))
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.accent.opacity(0.12))
        .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .bottom)
    }
}
