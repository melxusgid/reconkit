//
//  ReportView.swift
//  ReconKit
//
//  The report surface: a summary card with the score ring, a custom segmented
//  tab bar, and finding cards. Plus the live-scan progress view.
//

import SwiftUI

struct ReportView: View {
    let report: ScanReport
    @ObservedObject var coordinator: ScanCoordinator
    @State private var selectedCategory: ScanCategory = .overview

    var body: some View {
        VStack(spacing: 0) {
            SummaryCard(report: report, coordinator: coordinator)
                .padding(.horizontal, 22)
                .padding(.bottom, 14)

            CategoryTabBar(categories: report.results.map(\.category),
                           selected: $selectedCategory,
                           worst: { report.result(for: $0)?.worst ?? .info })
                .padding(.horizontal, 22)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if selectedCategory == .overview {
                        ActionPlanView(items: report.actionPlan)
                    }
                    if let result = report.result(for: selectedCategory) {
                        CategoryDetail(result: result)
                    } else {
                        Text("No data for this category")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 22)
            }
        }
        .onChange(of: report.id) { _, _ in selectedCategory = .overview }
    }
}

// MARK: - Summary card

struct SummaryCard: View {
    let report: ScanReport
    @ObservedObject var coordinator: ScanCoordinator

    var body: some View {
        HStack(spacing: 20) {
            ScoreRing(score: report.score, grade: report.grade, color: report.rating.color)
                .frame(width: 74, height: 74)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(report.target)
                        .font(Theme.sans(20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    GradeBadge(grade: report.grade, color: report.rating.color)
                    if report.isSample {
                        Text("DEMO")
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundStyle(Theme.gold)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1))
                    }
                }
                Text("Security rating: \(report.rating.label)")
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(report.rating.color)
                Text(report.date, format: .dateTime.month().day().year().hour().minute())
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()
            severityTotals
            actions
        }
        .padding(18)
        .card(radius: 16)
    }

    private var severityTotals: some View {
        let all = report.results.flatMap(\.findings)
        return VStack(alignment: .leading, spacing: 7) {
            tally(all.filter { $0.severity == .critical }.count, "Issues", Theme.danger, "xmark.octagon.fill")
            tally(all.filter { $0.severity == .warning }.count, "Warnings", Theme.gold, "exclamationmark.triangle.fill")
            tally(all.filter { $0.severity == .pass }.count, "Passed", Theme.green, "checkmark.circle.fill")
        }
    }

    private func tally(_ count: Int, _ label: String, _ color: Color, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(color)
            Text("\(count)").font(Theme.mono(13, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Text(label).font(Theme.sans(11)).foregroundStyle(Theme.textTertiary)
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if !report.isSample {
                    iconButton(coordinator.isWatched(report.target) ? "star.fill" : "star",
                               coordinator.isWatched(report.target) ? "Stop watching" : "Watch for changes",
                               tint: coordinator.isWatched(report.target) ? Theme.gold : Theme.textSecondary) {
                        coordinator.toggleWatch(report.target)
                    }
                    iconButton("arrow.clockwise", "Rescan now",
                               disabled: coordinator.isScanning) {
                        coordinator.rescan(report)
                    }
                }
            }
            HStack(spacing: 8) {
                actionButton("doc.richtext", "Export PDF report") {
                    Task { await ReportPDF.export(report: report) }
                }
                actionButton("curlybraces.square", "Export for agents (Markdown + JSON)") {
                    ExportService.saveForAgents(report: report)
                }
                actionButton("doc.on.doc", "Copy as markdown") { ExportService.copyToPasteboard(report: report) }
                actionButton("square.and.arrow.up", "Export markdown") { ExportService.save(report: report) }
            }
        }
    }

    private func actionButton(_ symbol: String, _ help: String,
                           action: @escaping () -> Void) -> some View {
        iconButton(symbol, help, action: action)
    }

    private func iconButton(_ symbol: String, _ help: String,
                            tint: Color = Theme.textSecondary,
                            disabled: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.cardFill))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .tooltip(help)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

struct ScoreRing: View {
    let score: Int
    let grade: String
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 7)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    AngularGradient(colors: [color, color.opacity(0.7)], center: .center),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .glow(color, radius: 6, opacity: 0.5)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(Theme.mono(22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("/100")
                    .font(Theme.mono(8))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

struct GradeBadge: View {
    let grade: String
    let color: Color
    var body: some View {
        Text(grade)
            .font(Theme.sans(15, weight: .heavy))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(Circle().fill(color.opacity(0.14)))
            .overlay(Circle().strokeBorder(color.opacity(0.5), lineWidth: 1.5))
            .glow(color, radius: 5, opacity: 0.4)
    }
}

// MARK: - Tab bar

struct CategoryTabBar: View {
    let categories: [ScanCategory]
    @Binding var selected: ScanCategory
    let worst: (ScanCategory) -> Severity

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories) { cat in
                    let isSel = cat == selected
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selected = cat }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cat.symbol).font(.system(size: 11, weight: .semibold))
                            Text(cat.rawValue).font(Theme.sans(12, weight: .medium))
                            if worst(cat) >= .warning {
                                Circle().fill(worst(cat).color).frame(width: 5, height: 5)
                            }
                        }
                        .foregroundStyle(isSel ? .white : Theme.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSel ? Theme.accent.opacity(0.9) : Theme.cardFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(isSel ? Theme.accent : Theme.stroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Category detail

struct CategoryDetail: View {
    let result: CategoryResult
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.summary)
                .font(Theme.mono(12))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 2)
            ForEach(result.findings) { FindingRow(finding: $0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Action plan

struct ActionPlanView: View {
    let items: [ActionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentSoft)
                Text("Priority Action Plan")
                    .font(Theme.sans(14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundStyle(Theme.accentSoft)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Theme.accent.opacity(0.15)))
                }
            }

            if items.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.green)
                    Text("No warnings or critical issues. Nothing to fix.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    ActionRow(index: idx + 1, item: item)
                }
            }
        }
    }
}

struct ActionRow: View {
    let index: Int
    let item: ActionItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(Theme.mono(12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(item.finding.severity.color))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(item.finding.title)
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(item.category.rawValue.uppercased())
                        .font(Theme.mono(8, weight: .bold))
                        .foregroundStyle(item.finding.severity.color)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .overlay(Capsule().strokeBorder(item.finding.severity.color.opacity(0.5), lineWidth: 1))
                }
                Text(item.fix)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .card()
    }
}

struct FindingRow: View {
    let finding: Finding
    @State private var expanded = false
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: finding.severity.symbol)
                .font(.system(size: 14))
                .foregroundStyle(finding.severity.color)
                .glow(finding.severity.color, radius: 5, opacity: 0.5)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(finding.title)
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(finding.detail)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textSecondary)
                    .textSelection(.enabled)
                    .lineLimit(expanded ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .card(hover: hovering)
        .onHover { hovering = $0 }
        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }
    }
}

// MARK: - Live progress

struct ScanProgressView: View {
    @ObservedObject var coordinator: ScanCoordinator

    var body: some View {
        VStack(spacing: 22) {
            RadarPulse()
                .frame(width: 120, height: 120)

            VStack(spacing: 8) {
                Text("Scanning \(coordinator.liveTarget)")
                    .font(Theme.sans(19, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                ProgressView(value: Double(coordinator.completedCategories),
                             total: Double(coordinator.expectedCategoryCount))
                    .tint(Theme.accent)
                    .frame(maxWidth: 340)
                Text("\(coordinator.completedCategories) of \(coordinator.expectedCategoryCount) categories")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textTertiary)
            }

            VStack(spacing: 6) {
                ForEach(ScanCategory.allCases) { cat in
                    HStack(spacing: 10) {
                        if let done = coordinator.liveResults.first(where: { $0.category == cat }) {
                            Image(systemName: done.worst.symbol)
                                .font(.system(size: 12))
                                .foregroundStyle(done.worst.color)
                            Text(cat.rawValue).font(Theme.sans(13)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(done.summary).font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                        } else {
                            ProgressView().controlSize(.small).tint(Theme.accent)
                            Text(cat.rawValue).font(Theme.sans(13)).foregroundStyle(Theme.textTertiary)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .card()
                }
            }
            .frame(maxWidth: 480)
        }
        .padding(28)
    }
}

/// Animated sonar/radar pulse shown while scanning.
struct RadarPulse: View {
    @State private var sweep = false
    @State private var ping = false
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Theme.accent.opacity(0.4 - Double(i) * 0.1), lineWidth: 1)
                    .scaleEffect(ping ? 1.05 : 0.5)
                    .opacity(ping ? 0 : 1)
                    .animation(.easeOut(duration: 2.2).repeatForever(autoreverses: false).delay(Double(i) * 0.7), value: ping)
            }
            Circle().stroke(Theme.stroke, lineWidth: 1)
            Circle().fill(Theme.accent.opacity(0.08))
            // Sweeping arm.
            Rectangle()
                .fill(LinearGradient(colors: [Theme.accent.opacity(0.0), Theme.accent], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1.5)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .rotationEffect(.degrees(sweep ? 360 : 0))
                .animation(.linear(duration: 2.2).repeatForever(autoreverses: false), value: sweep)
            Image(systemName: "binoculars.fill")
                .font(.system(size: 26))
                .foregroundStyle(Theme.accentSoft)
                .glow(Theme.accent, radius: 12, opacity: 0.6)
        }
        .onAppear { sweep = true; ping = true }
    }
}
