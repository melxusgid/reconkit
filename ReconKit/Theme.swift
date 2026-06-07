//
//  Theme.swift
//  ReconKit
//
//  Visual language modeled on the Hermes desktop app: a clean, dark,
//  editor-grade UI. Near-black warm backgrounds, an electric-blue primary
//  accent, a gold highlight, white text, subtle accent-tinted cards, 12px
//  radius, SF Pro + monospace.
//

import SwiftUI

enum Theme {
    // MARK: Surfaces (dark, layered: sidebar darkest → chrome → card)
    static let bgSidebar  = Color(red: 0.039, green: 0.039, blue: 0.043)  // #0A0A0B
    static let bgChrome   = Color(red: 0.051, green: 0.051, blue: 0.055)  // #0D0D0E
    static let bgElevated = Color(red: 0.086, green: 0.086, blue: 0.094)  // #161618

    // MARK: Accents
    static let accent     = Color(red: 0.0,   green: 0.325, blue: 0.992)  // #0053FD electric blue
    static let accentSoft = Color(red: 0.25,  green: 0.50,  blue: 1.0)    // lighter blue for text/icons
    static let gold       = Color(red: 1.0,   green: 0.824, blue: 0.212)  // #FFD236
    static let green      = Color(red: 0.0,   green: 0.733, blue: 0.498)  // #00BB7F
    static let danger     = Color(red: 0.812, green: 0.176, blue: 0.337)  // #CF2D56

    // MARK: Text
    static let textPrimary   = Color(red: 0.988, green: 0.988, blue: 0.988) // #FCFCFC
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary  = Color.white.opacity(0.40)

    // MARK: Lines & fills
    static var stroke: Color { Color.white.opacity(0.09) }
    static var strokeStrong: Color { Color.white.opacity(0.16) }
    static var cardFill: Color { Color.white.opacity(0.035) }
    static var cardFillHover: Color { Color.white.opacity(0.06) }

    static let radius: CGFloat = 12

    // MARK: Fonts — SF Pro sans + monospace, matching Hermes
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent.opacity(0.82)], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Card surface

struct CardSurface: ViewModifier {
    var radius: CGFloat = Theme.radius
    var hover: Bool = false
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(hover ? Theme.cardFillHover : Theme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func card(radius: CGFloat = Theme.radius, hover: Bool = false) -> some View {
        modifier(CardSurface(radius: radius, hover: hover))
    }

    /// Soft colored glow for accents and severity dots.
    func glow(_ color: Color, radius: CGFloat = 8, opacity: Double = 0.6) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
    }
}

// MARK: - Tooltip (AppKit-backed; SwiftUI .help() is unreliable here)

/// An invisible overlay that carries an AppKit tooltip and passes clicks
/// through to the control beneath it.
private struct ToolTipOverlay: NSViewRepresentable {
    let text: String
    func makeNSView(context: Context) -> NSView {
        let view = PassThroughView()
        view.toolTip = text
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { nsView.toolTip = text }

    final class PassThroughView: NSView {
        // Don't intercept clicks — let them reach the SwiftUI button below.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

extension View {
    func tooltip(_ text: String) -> some View {
        overlay(ToolTipOverlay(text: text))
    }
}

// MARK: - Background

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.bgChrome
            // Barely-there blue wash, top-left, to give the flat surface depth.
            RadialGradient(colors: [Theme.accent.opacity(0.10), .clear],
                           center: .topLeading, startRadius: 2, endRadius: 600)
            // Faint gold ember, bottom-right (the Hermes highlight color).
            RadialGradient(colors: [Theme.gold.opacity(0.05), .clear],
                           center: .bottomTrailing, startRadius: 2, endRadius: 500)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Accent button

struct AccentButtonStyle: ButtonStyle {
    var prominent: Bool = true
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.sans(13, weight: .semibold))
            .foregroundStyle(prominent ? .white : Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(prominent
                          ? AnyShapeStyle(Theme.accentGradient)
                          : AnyShapeStyle(Theme.cardFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(prominent ? Theme.accent.opacity(0.5) : Theme.stroke, lineWidth: 1)
            )
            .glow(prominent ? Theme.accent : .clear,
                  radius: configuration.isPressed ? 3 : 10,
                  opacity: prominent && isEnabled ? 0.45 : 0)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
