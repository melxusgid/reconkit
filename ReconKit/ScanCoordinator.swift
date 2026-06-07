//
//  ScanCoordinator.swift
//  ReconKit
//
//  Observable state for the UI: scan history, the live scan, the watchlist,
//  persistence, and monitoring (rescan + diff + notifications).
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ScanCoordinator: ObservableObject {
    @Published var history: [ScanReport] = []
    @Published var selectedID: ScanReport.ID?
    @Published var isScanning = false
    @Published var liveResults: [CategoryResult] = []
    @Published var liveTarget: String = ""
    @Published var completedCategories: Int = 0

    // Monitoring
    @Published var watchlist: [String] = []
    @Published var autoRescan: Bool = false { didSet { persist(); restartScheduler() } }
    @Published var lastDiff: ScanDiff?
    @Published var showDiff = false
    @Published var showSettings = false
    @Published var requestScanFocus = false

    let expectedCategoryCount = ScanCategory.allCases.count
    private let engine = ScanEngine()
    private let maxHistory = 100
    private var scheduler: Timer?

    init() {
        let state = ScanStore.load()
        history = state.history
        watchlist = state.watchlist
        autoRescan = state.autoRescan
        selectedID = history.first?.id
        Notifier.requestAuthorization()
        restartScheduler()
    }

    var selectedReport: ScanReport? { history.first { $0.id == selectedID } }

    // MARK: - Scanning

    func runScan(target raw: String, silent: Bool = false) {
        let target = ScanEngine.hostComponent(from: raw)
        guard !target.isEmpty, !isScanning else { return }

        // Previous scan of the same target, for diffing.
        let previous = history.first { $0.target == target }

        isScanning = true
        liveResults = []
        liveTarget = target
        completedCategories = 0

        Task { [weak self] in
            guard let self else { return }
            let report = await self.engine.scan(target: target) { result in
                Task { @MainActor [weak self] in self?.merge(result) }
            }
            self.finish(report: report, previous: previous, silent: silent)
        }
    }

    private func finish(report: ScanReport, previous: ScanReport?, silent: Bool) {
        let diff = previous.map { ScanDiff.between(old: $0, new: report) }
        history.insert(report, at: 0)
        if history.count > maxHistory { history.removeLast(history.count - maxHistory) }
        selectedID = report.id
        isScanning = false
        liveResults = []
        if let diff, diff.hasChanges {
            lastDiff = diff
            if !silent { showDiff = true }
        }
        Notifier.reportEvents(report: report, diff: diff)
        persist()
    }

    private func merge(_ result: CategoryResult) {
        if let idx = liveResults.firstIndex(where: { $0.category == result.category }) {
            liveResults[idx] = result
        } else {
            liveResults.append(result)
        }
        completedCategories = liveResults.count
    }

    func rescan(_ report: ScanReport) { runScan(target: report.target) }

    // MARK: - Watchlist

    func isWatched(_ target: String) -> Bool { watchlist.contains(target) }

    func toggleWatch(_ target: String) {
        if let idx = watchlist.firstIndex(of: target) {
            watchlist.remove(at: idx)
        } else {
            watchlist.append(target)
        }
        persist()
    }

    /// Most recent report for each watched domain.
    var watchedReports: [ScanReport] {
        watchlist.compactMap { t in history.first { $0.target == t } }
    }

    func rescanAllWatched() {
        guard !isScanning else { return }
        let targets = watchlist
        Task { @MainActor in
            for t in targets {
                while isScanning { try? await Task.sleep(nanoseconds: 200_000_000) }
                runScan(target: t, silent: true)
            }
        }
    }

    // MARK: - Sample / delete

    func loadSample() {
        let sample = SampleData.demoReport()
        history.insert(sample, at: 0)
        selectedID = sample.id
        persist()
    }

    func delete(_ report: ScanReport) {
        history.removeAll { $0.id == report.id }
        if selectedID == report.id { selectedID = history.first?.id }
        persist()
    }

    // MARK: - Persistence & scheduling

    private func persist() {
        ScanStore.save(PersistedState(history: history, watchlist: watchlist,
                                      autoRescan: autoRescan))
    }

    private func restartScheduler() {
        scheduler?.invalidate()
        scheduler = nil
        guard autoRescan else { return }
        // Rescan watched domains hourly while the app is running.
        scheduler = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.rescanAllWatched() }
        }
    }
}
