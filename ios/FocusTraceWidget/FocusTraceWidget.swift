import SwiftUI
import WidgetKit

/// Home screen widget (small and medium): FocusTrace's restriction status
/// from the App Group. WidgetKit cannot read Screen Time usage, so unlike
/// Android's usage widget it shows what blocks now, what blocks next and how
/// many daily limits were reached today. Tapping it opens FocusTrace (the
/// default for a widget without a link).
@main
struct FocusTraceWidgetBundle: WidgetBundle {
  var body: some Widget {
    FocusTraceStatusWidget()
  }
}

struct FocusTraceStatusWidget: Widget {
  var body: some WidgetConfiguration {
    let strings = RestrictionStore.shared.widgetStrings
    return StaticConfiguration(kind: WidgetRefresher.kind, provider: StatusProvider()) { entry in
      StatusView(entry: entry)
    }
    .configurationDisplayName(strings.text("galleryName"))
    .description(strings.text("galleryDescription"))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct StatusEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot
  let strings: WidgetStrings
  let localeIdentifier: String?
}

struct StatusProvider: TimelineProvider {
  func placeholder(in context: Context) -> StatusEntry {
    StatusEntry(
      date: Date(),
      snapshot: WidgetSnapshot(
        activeNames: ["Social"], activeUntil: Date().addingTimeInterval(3600),
        next: .init(name: "Evenings", start: Date().addingTimeInterval(7200)),
        limitsReached: 1, hasRestrictions: true),
      strings: WidgetStrings(sharedValues: [:]), localeIdentifier: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
    completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
    let store = RestrictionStore.shared
    let now = Date()
    let dates = WidgetStatus.timeline(configuration: store.configuration, from: now)
    let entries = dates.map { entry(at: $0, store: store) }
    // After the last boundary (at most a day ahead) WidgetKit asks again; the
    // app and the monitor also reload whenever the state changes.
    completion(Timeline(entries: entries, policy: .atEnd))
  }

  private func entry(at date: Date, store: RestrictionStore = .shared) -> StatusEntry {
    StatusEntry(
      date: date, snapshot: store.widgetSnapshot(at: date), strings: store.widgetStrings,
      localeIdentifier: store.reportStrings.localeIdentifier)
  }
}

// MARK: - Views

/// FocusTrace's dark brand colours (launcher icon and block screen).
private enum Brand {
  static let background = Color(red: 0x0E / 255, green: 0x15 / 255, blue: 0x20 / 255)
  static let accent = Color(red: 0x5B / 255, green: 0xC0 / 255, blue: 0xEB / 255)
  static let soft = Color(red: 0xA8 / 255, green: 0xDD / 255, blue: 0xF5 / 255)
  static let text = Color.white
  static let muted = Color.white.opacity(0.62)
}

struct StatusView: View {
  @Environment(\.widgetFamily) private var family
  let entry: StatusEntry

  var body: some View {
    content
      .modifier(WidgetBackground())
      .environment(\.colorScheme, .dark)
  }

  @ViewBuilder private var content: some View {
    switch family {
    case .systemMedium:
      HStack(alignment: .top, spacing: 16) {
        nowColumn
        Rectangle().fill(Brand.muted.opacity(0.25)).frame(width: 1)
        VStack(alignment: .leading, spacing: 10) {
          nextBlock
          Spacer(minLength: 0)
          limitsLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    default:
      VStack(alignment: .leading, spacing: 6) {
        nowColumn
        Spacer(minLength: 0)
        limitsLine
      }
    }
  }

  private var snapshot: WidgetSnapshot { entry.snapshot }
  private var strings: WidgetStrings { entry.strings }

  private var header: some View {
    HStack(spacing: 6) {
      Circle().fill(Brand.soft).frame(width: 8, height: 8)
      Text("FocusTrace").font(.caption.weight(.semibold)).foregroundColor(Brand.muted)
    }
  }

  private var nowColumn: some View {
    VStack(alignment: .leading, spacing: 4) {
      header
      if !snapshot.hasRestrictions {
        Spacer(minLength: 0)
        Text(strings.text("noRestrictions"))
          .font(.footnote).foregroundColor(Brand.text).lineLimit(3)
      } else if snapshot.activeNames.isEmpty {
        Spacer(minLength: 0)
        Text(strings.text("nothingBlocked"))
          .font(.subheadline.weight(.semibold)).foregroundColor(Brand.text).lineLimit(2)
      } else {
        Text("\(snapshot.activeNames.count)")
          .font(.system(size: 34, weight: .bold, design: .rounded))
          .foregroundColor(Brand.accent)
        Text(strings.text("blockingNow"))
          .font(.caption.weight(.semibold)).foregroundColor(Brand.text)
        Text(activeDetail)
          .font(.caption2).foregroundColor(Brand.muted).lineLimit(2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var activeDetail: String {
    let names = snapshot.activeNames.prefix(family == .systemMedium ? 3 : 2)
      .joined(separator: ", ")
    guard let until = snapshot.activeUntil else { return names }
    return names + " · " + strings.until(time(until))
  }

  private var nextBlock: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(strings.text("nextBlock"))
        .font(.caption.weight(.semibold)).foregroundColor(Brand.muted)
      if let next = snapshot.next {
        Text(next.name).font(.subheadline.weight(.semibold)).foregroundColor(Brand.text)
          .lineLimit(1)
        Text(dayAndTime(next.start)).font(.caption).foregroundColor(Brand.accent)
      } else {
        Text(strings.text("noUpcoming")).font(.footnote).foregroundColor(Brand.text)
      }
    }
  }

  @ViewBuilder private var limitsLine: some View {
    if snapshot.hasRestrictions {
      HStack(spacing: 6) {
        Text("\(snapshot.limitsReached)")
          .font(.caption.weight(.bold)).foregroundColor(Brand.accent)
        Text(strings.text("limitsReached"))
          .font(.caption2).foregroundColor(Brand.muted).lineLimit(1)
          .minimumScaleFactor(0.8)
      }
    }
  }

  private var locale: Locale {
    entry.localeIdentifier.map(Locale.init(identifier:)) ?? .current
  }

  private func time(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private func dayAndTime(_ date: Date) -> String {
    if Calendar.current.isDate(date, inSameDayAs: entry.date) { return time(date) }
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.setLocalizedDateFormatFromTemplate("EEE jmm")
    return formatter.string(from: date)
  }
}

/// iOS 17 wants the widget background declared as such.
private struct WidgetBackground: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 17.0, *) {
      content.containerBackground(for: .widget) { Brand.background }
    } else {
      content.padding().background(Brand.background)
    }
  }
}
