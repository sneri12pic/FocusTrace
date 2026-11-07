import SwiftUI
import UIKit

/// FocusTrace's colours, hard-coded because the extension cannot read Flutter's
/// theme. Sources (keep in step):
/// - lib/src/presentation/focus_trace_app.dart: Material 3
///   `ColorScheme.fromSeed(seedColor: 0xFF5BC0EB)`, dark surface 0xFF070A10;
///   the values below are what Flutter 3.32 derives from it (light and dark).
/// - lib/src/presentation/screens/usage_bubble_screen.dart: section cards
///   0xFF0D111A on the dashboard.
/// - lib/src/presentation/widgets/usage_calendar.dart `_ClockPainter`: dial
///   blues 0xFF1C5FA6 -> 0xFF8FDBFF.
/// - lib/src/presentation/widgets/trend_color.dart and app_category_widgets.dart.
struct ReportPalette {
  let primary: Color
  let onSurface: Color
  let muted: Color
  /// Cards (`surfaceContainerLow`, the Card colour in Flutter).
  let card: Color
  /// Dashboard section cards (usage_bubble_screen.dart `_SectionCard`).
  let sectionCard: Color
  let cardBorder: Color
  /// Tiles inside a card, chips, empty bar tracks.
  let tile: Color
  let track: Color
  let dialDim: Color
  let dialBright: Color
  let tick: Color

  static func forScheme(_ scheme: ColorScheme) -> ReportPalette {
    scheme == .dark ? dark : light
  }

  static let dark = ReportPalette(
    primary: Color(hex: 0x8CCFF0),
    onSurface: Color(hex: 0xDFE3E7),
    muted: Color(hex: 0xC0C8CD),
    card: Color(hex: 0x171C1F),
    sectionCard: Color(hex: 0x0D111A),
    cardBorder: Color.white.opacity(0.08),
    tile: Color(hex: 0x1B2023),
    track: Color(hex: 0x303538).opacity(0.7),
    dialDim: Color(hex: 0x1C5FA6),
    dialBright: Color(hex: 0x8FDBFF),
    tick: Color(hex: 0xC0C8CD).opacity(0.6))

  static let light = ReportPalette(
    primary: Color(hex: 0x146683),
    onSurface: Color(hex: 0x171C1F),
    muted: Color(hex: 0x40484C),
    card: Color(hex: 0xF0F4F8),
    sectionCard: Color(hex: 0xEAEEF2),
    cardBorder: Color.black.opacity(0.06),
    tile: Color(hex: 0xE4E9EC),
    track: Color(hex: 0xDFE3E7),
    dialDim: Color(hex: 0x1C5FA6),
    dialBright: Color(hex: 0x8FDBFF),
    tick: Color(hex: 0x40484C).opacity(0.6))

  /// The dial's slice colour for `share` (0...1) of a full hour.
  func dialColor(_ share: Double) -> Color {
    share <= 0 ? track : Color.lerp(dialDim, dialBright, share)
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }

  /// Linear blend in sRGB, as Flutter's `Color.lerp`.
  static func lerp(_ a: Color, _ b: Color, _ t: Double) -> Color {
    let from = UIColor(a).rgba
    let to = UIColor(b).rgba
    let t = max(0, min(1, t))
    return Color(
      red: Double(from.0 + (to.0 - from.0) * t),
      green: Double(from.1 + (to.1 - from.1) * t),
      blue: Double(from.2 + (to.2 - from.2) * t),
      opacity: Double(from.3 + (to.3 - from.3) * t))
  }
}

private extension UIColor {
  var rgba: (Double, Double, Double, Double) {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    getRed(&r, green: &g, blue: &b, alpha: &a)
    return (Double(r), Double(g), Double(b), Double(a))
  }
}
