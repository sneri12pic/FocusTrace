import Foundation
import WidgetKit

/// Asks WidgetKit to redraw FocusTraceWidget after the restriction state in
/// the App Group changed: from the app after a sync, a language change or
/// when it becomes active, and from the monitor extension when shields change.
enum WidgetRefresher {
  static let kind = "FocusTraceWidget"

  static func reload() {
    WidgetCenter.shared.reloadTimelines(ofKind: kind)
  }
}
