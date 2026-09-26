import SwiftUI

/// Every Time visual language — see docs/design/iphone-v1/uiux/visual.md.
enum Theme {
    static let padding: CGFloat = 20
    static let spacing: CGFloat = 12
    static let radius: CGFloat = 22
    static let cardFill = Color.primary.opacity(0.05)
    static let hairline = Color.primary.opacity(0.08)

    enum Tone {
        static let night = Color.indigo.opacity(0.28)
        static let edge = Color.orange.opacity(0.14)
        static let work = Color.accentColor.opacity(0.22)
        static let warn = Color.orange
        static let bad = Color.red
        static let good = Color.green
    }
}

extension Font {
    /// Large readouts: thin, rounded, tabular.
    static func clock(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
    static let screenTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let cardTitle = Font.system(.headline, design: .rounded)
    static let label = Font.system(.footnote, design: .rounded, weight: .medium)
}

/// Rounded surface on the plain background; replaces grouped-list chrome.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}

/// Small uppercase label above a group, with optional trailing accessory (ⓘ, count).
struct SectionLabel<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased()).font(.label).tracking(0.8).foregroundStyle(.secondary)
            trailing
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

extension SectionLabel where Trailing == EmptyView {
    init(_ title: String) { self.init(title: title) { EmptyView() } }
}

/// Full-width primary action pinned above the tab bar.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.accentColor, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Quiet round secondary action (Now, Edit, Lap, Reset).
struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Theme.cardFill, in: Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle { static var primary: PrimaryButtonStyle { .init() } }
extension ButtonStyle where Self == SoftButtonStyle { static var soft: SoftButtonStyle { .init() } }

extension View {
    /// Bottom action area above the tab bar, fading into content.
    func bottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        safeAreaInset(edge: .bottom) {
            bar()
                .padding(.horizontal, Theme.padding)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(.bar)
        }
    }

    /// Plain screen background with standard horizontal padding for card layouts.
    func screen() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.padding)
    }
}
