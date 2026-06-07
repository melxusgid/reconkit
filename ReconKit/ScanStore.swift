//
//  ScanStore.swift
//  ReconKit
//
//  Persists scan history and the watchlist to the app's Application Support
//  container so monitoring survives restarts. Sandbox-safe (container path).
//

import Foundation

struct PersistedState: Codable {
    var history: [ScanReport] = []
    var watchlist: [String] = []
    var autoRescan: Bool = false

    init(history: [ScanReport] = [], watchlist: [String] = [],
         autoRescan: Bool = false) {
        self.history = history
        self.watchlist = watchlist
        self.autoRescan = autoRescan
    }

    // Tolerant decoding so adding new fields never wipes existing saved state.
    enum CodingKeys: String, CodingKey { case history, watchlist, autoRescan }
    init(from decoder: Decoder) throws {
        let c = try? decoder.container(keyedBy: CodingKeys.self)
        history = (try? c?.decode([ScanReport].self, forKey: .history)) ?? []
        watchlist = (try? c?.decode([String].self, forKey: .watchlist)) ?? []
        autoRescan = (try? c?.decode(Bool.self, forKey: .autoRescan)) ?? false
    }
}

enum ScanStore {
    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReconKit", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("state.json")
    }

    static func load() -> PersistedState {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else { return PersistedState() }
        return state
    }

    static func save(_ state: PersistedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
