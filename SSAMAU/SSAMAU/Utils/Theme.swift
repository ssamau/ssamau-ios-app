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

    /// Attaches one or more hardware-keyboard shortcuts to a view
    /// without rendering any visible UI. Each shortcut is backed by a
    /// zero-size, fully transparent `Button` placed in a background
    /// overlay so it joins the responder chain (required for the
    /// shortcut to fire) but contributes nothing to layout.
    ///
    /// No-op in practice on an iPhone with no hardware keyboard; active
    /// on iPad with a Magic Keyboard / Smart Keyboard / Bluetooth
    /// keyboard, and on Mac via Catalyst (where the shortcuts also
    /// surface in the menu bar's discoverability HUD on ⌘-hold).
    ///
    /// iOS 16+ — uses plain `.keyboardShortcut`, no `.commands` scene
    /// menu (which is Mac-menu oriented and wouldn't help on iPad).
    func ssKeyboardShortcuts(_ shortcuts: [SSKeyboardShortcut]) -> some View {
        background(
            ZStack {
                ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, sc in
                    Button(action: sc.action) { EmptyView() }
                        .keyboardShortcut(sc.key, modifiers: sc.modifiers)
                }
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        )
    }

    /// iPad-friendly sheet sizing. Apply to the sheet's outer-most view
    /// to make the iPad formSheet render at a size appropriate for the
    /// content instead of the system default (~540×620 regardless of
    /// content).
    ///
    /// How it works: on iPad regular width, sets `.frame(minWidth:,
    /// minHeight:)` which SwiftUI propagates to the UIHostingController's
    /// `preferredContentSize`, which UIKit's formSheet uses to size
    /// itself. iPhone (compact width) keeps the existing default
    /// pageSheet behaviour — the frame would otherwise force horizontal
    /// scroll on narrow iPhones.
    ///
    /// Sizes are categorical (small / medium / large / xlarge) rather
    /// than per-sheet so we can re-tune the four tiers globally without
    /// hunting down every call site.
    ///
    /// iOS 16+ compatible; doesn't depend on iOS 17's
    /// `.presentationContentSize` or iOS 18's `.presentationSizing`,
    /// both of which we'd love to use eventually.
    func iPadSheet(_ size: SSIPadSheetSize) -> some View {
        modifier(SSIPadSheetSizeModifier(size: size))
    }
}

/// Sheet-size buckets. Widths capped at 680 to stay under iPad mini
/// portrait's formSheet threshold (~684pt safe area). Above that
/// threshold UIKit silently escalates the presentation from formSheet
/// to fullscreen — losing the sidebar dim, the rounded corners, and
/// the "modal-ness" — which is what build 79 hit when xlarge was
/// 760pt wide.
///
/// Heights are advisory only; build 80 dropped the height enforcement
/// because forcing minHeight clipped sheet toolbars in landscape iPad
/// mini with the sidebar visible. The values are kept here for
/// reference and so sub-phase 3B can re-apply per-form inner sizing
/// if needed (e.g. ScrollView cap).
enum SSIPadSheetSize {
    /// Confirmations, pin-result, role pickers. Single decision, no
    /// scrolling expected.
    case small
    /// Single-purpose form: log hours, send thanks, issue cert, attendance row.
    case medium
    /// Multi-section form or rich detail viewer: project form, advisor
    /// form, application detail with CV preview, member viewer.
    case large
    /// Wide form or list-driven sheet: account form, record-attendance,
    /// CV PDF preview. Currently the same physical width as large
    /// (680) because going wider triggers iPad mini portrait
    /// fullscreen escalation; the enum case is kept so we can
    /// differentiate intent if a future change re-introduces
    /// height/style overrides.
    case xlarge

    fileprivate var dims: CGSize {
        switch self {
        case .small:  return CGSize(width: 380, height: 460)
        case .medium: return CGSize(width: 540, height: 640)
        case .large:  return CGSize(width: 680, height: 780)
        case .xlarge: return CGSize(width: 680, height: 860)
        }
    }
}

/// One hardware-keyboard shortcut: a key + modifiers + the action to
/// run. Used with `View.ssKeyboardShortcuts(_:)`. Default modifier is
/// Command, matching the platform convention for app-level shortcuts.
struct SSKeyboardShortcut {
    let key: KeyEquivalent
    let modifiers: EventModifiers
    let action: () -> Void

    init(_ key: KeyEquivalent,
         modifiers: EventModifiers = .command,
         action: @escaping () -> Void) {
        self.key = key
        self.modifiers = modifiers
        self.action = action
    }

    /// Builds ⌘1…⌘9 then ⌘0 (for a 10th) shortcuts from an ordered
    /// list of selection values, each setting `select(value)`. Used by
    /// the three portal sidebars to give every destination a number
    /// shortcut. Anything past the 10th item gets no shortcut (we run
    /// out of single digits) — acceptable, the long tail is reachable
    /// by click and the most-used destinations sit at the top.
    static func numbered<T>(_ values: [T],
                            select: @escaping (T) -> Void) -> [SSKeyboardShortcut] {
        let digits: [Character] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        return zip(values, digits).map { value, digit in
            SSKeyboardShortcut(KeyEquivalent(digit)) { select(value) }
        }
    }
}

private struct SSIPadSheetSizeModifier: ViewModifier {
    let size: SSIPadSheetSize
    @Environment(\.horizontalSizeClass) private var hSizeClass

    func body(content: Content) -> some View {
        if hSizeClass == .regular {
            // Width-only sizing. Setting minWidth propagates to the
            // hosting controller's preferredContentSize.width, which
            // UIKit's formSheet uses to widen itself. Width is safe
            // to force because Text wraps and controls shrink — narrow
            // windows clamp gracefully without clipping.
            //
            // Height is INTENTIONALLY natural-content-driven. The first
            // pass forced minHeight too, which clipped the sheet
            // toolbar (title + Cancel + segmented controls) above the
            // visible area in landscape iPad mini with sidebar
            // visible: window height 744pt < forced sheet height
            // 860pt, so the formSheet's safe-area clamping cut the
            // top while SwiftUI continued laying out for 860pt.
            // Vertical content has no built-in scroll fallback the
            // way horizontal content has Text-wrapping, so clipping
            // is silent and destructive there.
            //
            // The trade-off: small sheets (PinResultSheet etc.) render
            // at the system's default formSheet height (~620pt) rather
            // than a tighter 460pt. Acceptable — a slightly oversized
            // formSheet is far better than a clipped toolbar.
            content.frame(minWidth: size.dims.width)
        } else {
            content
        }
    }
}

/// Adaptive `LazyVGrid` column count that uses `compact` on iPhone
/// portrait / Split View narrow, `regular` everywhere else. Pass any
/// pair of layouts; the caller decides the columns + spacing.
struct SSAdaptiveColumns {
    let compact: [GridItem]
    let regular: [GridItem]

    /// Two-column compact, width-adaptive regular — the default for
    /// KPI dashboards.
    ///
    /// Regular uses `.adaptive(minimum: 160)` instead of a fixed 4-col
    /// flexible grid so the dashboard works at any detail-column width
    /// the iPad NavigationSplitView can produce:
    ///   - Stage Manager narrow window with sidebar visible (~480pt
    ///     detail) → 2 cols, cells stay ~220pt wide and content reads
    ///     cleanly.
    ///   - iPad mini portrait with sidebar (~520pt detail) → 3 cols.
    ///   - iPad landscape / iPad Pro (~700-900pt detail) → 4-5 cols,
    ///     same density as before.
    ///
    /// The previous fixed 4-col layout cramped cells to ~100pt in
    /// narrow detail widths. The "Total members" KPI showed the bug
    /// worst: `person.3` (outlined, intrinsically wider than the
    /// filled `person.2.fill` used on "Active members") + single-digit
    /// values pushed to the far edge by `Spacer()` made the
    /// asymmetric layout visually obvious.
    static let kpi = SSAdaptiveColumns(
        compact: [GridItem(.flexible(), spacing: 12),
                  GridItem(.flexible(), spacing: 12)],
        regular: [GridItem(.adaptive(minimum: 160), spacing: 12)]
    )

    /// List-row card grid. Single column on narrow widths (iPhone,
    /// iPad mini portrait with sidebar visible — ~520pt detail), two
    /// columns wherever there's room for two 340pt cards plus
    /// spacing (~700pt+ available, hit on iPad mini landscape with
    /// sidebar, iPad Air+ everywhere, iPad in fullscreen). Use for
    /// primary list views (members, opportunities, projects,
    /// applications, accounts, certs etc.) so the extra horizontal
    /// space on iPad shows MORE rows per screen instead of stretching
    /// each row to 700pt with whitespace.
    ///
    /// Single static (not a SSAdaptiveColumns instance) because the
    /// `.adaptive` GridItem already does the right thing at any
    /// available width — no need to branch on horizontalSizeClass at
    /// the call site.
    ///
    /// 340pt is the practical minimum for our cards: a member-row
    /// card with name + role/committee + last-login + state badge +
    /// chevron + action buttons fits comfortably, and it's wide
    /// enough that a localised Arabic name doesn't truncate.
    static let cards: [GridItem] = [
        GridItem(.adaptive(minimum: 340), spacing: 10)
    ]
}
