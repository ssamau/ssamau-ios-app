import SwiftUI

/// Typed accessors for brand fonts + colors. Centralises the typography
/// scale (per SSAM Brand Identity Guide §IV/§Hierarchy) and gives view
/// code a single place to change when the design system evolves.
///
/// Sizes are adapted for mobile — the brand guide's print scale
/// (Display 56pt, H1 32pt, etc.) is too large for an iPhone.

extension Font {
    // Bilingual app font. Almarai covers Arabic and renders Latin
    // glyphs in a similar weight, keeping mixed-script lines visually
    // consistent. iOS falls back to system Arabic if Almarai fails to
    // register at runtime.
    private static func almarai(_ weight: AlmaraiWeight, size: CGFloat) -> Font {
        .custom(weight.fontName, size: size)
    }

    private enum AlmaraiWeight: String {
        case light, regular, bold, extraBold
        var fontName: String {
            switch self {
            case .light:     return "Almarai-Light"
            case .regular:   return "Almarai-Regular"
            case .bold:      return "Almarai-Bold"
            case .extraBold: return "Almarai-ExtraBold"
            }
        }
    }

    static var ssDisplay: Font   { almarai(.extraBold, size: 32) }   // hero headings
    static var ssH1: Font        { almarai(.bold,      size: 22) }   // screen titles
    static var ssH2: Font        { almarai(.bold,      size: 18) }   // section titles
    static var ssBody: Font      { almarai(.regular,   size: 15) }   // body copy
    static var ssBodyBold: Font  { almarai(.bold,      size: 15) }
    static var ssCaption: Font   { almarai(.regular,   size: 12) }   // meta + footnotes
    static var ssTiny: Font      { almarai(.regular,   size: 10) }   // chip labels

    /// Italic Latin accent — Georgia-Italic, used for the brand's
    /// secondary Latin subtitle pattern under Arabic headings.
    static var ssLatinItalic: Font {
        .custom("Georgia-Italic", size: 13)
    }

    /// Tracked small-caps Latin label — matches the brand's
    /// "T H E   B O A R D" / "S P O N S O R S" pattern on section
    /// headers. SwiftUI handles the small-caps + letter spacing.
    static var ssLatinLabel: Font {
        .system(size: 11, weight: .medium).smallCaps()
    }
}

extension Color {
    // Brand identifiers
    static let ssGreen      = Color("BrandGreen")
    static let ssGreenDark  = Color("BrandGreenDark")
    static let ssGold       = Color("BrandGold")
    // Neutrals
    static let ssCream      = Color("Cream")
    static let ssPale       = Color("Pale")
    static let ssCharcoal   = Color("Charcoal")
    static let ssGrey       = Color("Grey")
    static let ssLight      = Color("Light")
}

// MARK: - Decorative helpers

/// Thin gold hairline divider — recurring brand element (page 14, 21, 24).
struct GoldRule: View {
    var width: CGFloat = 40
    var height: CGFloat = 1.5
    var body: some View {
        Rectangle()
            .fill(Color.ssGold)
            .frame(width: width, height: height)
    }
}

// MARK: - Adaptive layout helpers (iPad / Mac Catalyst)

extension View {
    /// Caps the content at `max` points wide and centers it horizontally
    /// inside the available space. On iPhone the device is always
    /// narrower than the cap so this is a no-op; on iPad the content
    /// gets readable margins instead of stretching across the full
    /// 1024pt+ canvas, and on Mac Catalyst windows it keeps layouts
    /// from feeling like a phone in a desktop window.
    ///
    /// Apply to the inside of a ScrollView so the scroll surface still
    /// fills the screen while the content sits in a centered column.
    func ipadContentWidth(_ max: CGFloat = 800) -> some View {
        self
            .frame(maxWidth: max)
            .frame(maxWidth: .infinity)
    }

    /// Brand-aligned pointer hover treatment. No-op on iPhone (no
    /// pointer); subtle highlight on iPad with trackpad/mouse and on
    /// Mac via Catalyst. Apply to any tappable row/card so the pointer
    /// gets feedback over the same surface that responds to tap.
    func ssHover() -> some View {
        self.hoverEffect(.highlight)
    }
}

/// Adaptive `LazyVGrid` column count that uses `compact` on iPhone
/// portrait / Split View narrow, `regular` everywhere else. Pass any
/// pair of layouts; the caller decides the columns + spacing.
struct SSAdaptiveColumns {
    let compact: [GridItem]
    let regular: [GridItem]

    /// Two-column compact, four-column regular — the default for KPI
    /// dashboards.
    static let kpi = SSAdaptiveColumns(
        compact: [GridItem(.flexible(), spacing: 12),
                  GridItem(.flexible(), spacing: 12)],
        regular: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    )
}
