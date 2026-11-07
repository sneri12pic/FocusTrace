import Charts
import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

// The FocusTrace usage screens, drawn inside the report extension (usage
// numbers never leave it). Each mirrors a Flutter screen as closely as the
// sandbox allows; the Flutter host gives every report a fixed height
// (lib/src/presentation/widgets/ios_usage_report_view.dart), so content is
// top-aligned, lists are capped and nothing scrolls in here.

struct UsageReportRootView: View {
  let snapshot: UsageSnapshot
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let palette = ReportPalette.forScheme(colorScheme)
    VStack(spacing: 12) {
      content(palette)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .environment(\.locale, snapshot.strings.localeIdentifier.map(Locale.init(identifier:)) ?? .current)
    // Fixed heights on the Flutter side: keep text from outgrowing them.
    .dynamicTypeSize(...DynamicTypeSize.large)
  }

  @ViewBuilder
  private func content(_ palette: ReportPalette) -> some View {
    switch snapshot.kind {
    case .today:
      TodayReportView(snapshot: snapshot, palette: palette)
    case .hourly:
      HourlyReportView(snapshot: snapshot, palette: palette)
    case .week, .month:
      RangeReportView(snapshot: snapshot, palette: palette)
    case .appDetail:
      AppDetailReportView(snapshot: snapshot, palette: palette)
    }
  }
}

// MARK: - Screens

/// Dashboard (Android: the day dial of the usage details plus the bubble
/// screen's "Current list" with its category chips).
struct TodayReportView: View {
  let snapshot: UsageSnapshot
  let palette: ReportPalette
  @State private var category: Int?

  var body: some View {
    let strings = snapshot.strings
    ReportCard(palette: palette, fill: palette.sectionCard) {
      VStack(spacing: 12) {
        HourDial(buckets: snapshot.buckets, total: snapshot.total, strings: strings, palette: palette)
        HStack(spacing: 8) {
          StatTile(
            symbol: "iphone", value: "\(snapshot.pickups)", label: strings.text("pickups"),
            palette: palette)
          StatTile(
            symbol: "bell", value: "\(snapshot.notifications)",
            label: strings.text("notifications"), palette: palette)
          StatTile(
            symbol: "clock", value: peakText, label: strings.text("peakTime"), palette: palette)
        }
      }
    }
    if snapshot.hasData {
      ReportCard(palette: palette, fill: palette.sectionCard) {
        VStack(alignment: .leading, spacing: 10) {
          CardTitle(strings.text("currentList"), palette: palette)
          if !snapshot.categories.isEmpty {
            CategoryChips(
              categories: Array(snapshot.categories.prefix(5)), selected: $category,
              strings: strings, palette: palette)
          }
          AppList(
            apps: filteredApps, limit: 10, extraHidden: category == nil ? snapshot.hiddenApps : 0,
            strings: strings, palette: palette)
        }
      }
    }
  }

  private var filteredApps: [ReportApp] {
    guard let category = category else { return snapshot.apps }
    return snapshot.apps.filter { $0.categoryId == category }
  }

  private var peakText: String {
    guard let peak = snapshot.buckets.peakIndex else { return "–" }
    return HourRange.text(start: snapshot.buckets.starts[peak], end: nil)
  }
}

/// Dashboard: the day's use per hour (Android day card "Usage timeline").
struct HourlyReportView: View {
  let snapshot: UsageSnapshot
  let palette: ReportPalette

  var body: some View {
    let strings = snapshot.strings
    ReportCard(palette: palette, fill: palette.sectionCard) {
      VStack(alignment: .leading, spacing: 12) {
        CardTitle(strings.text("timeline"), palette: palette)
        HourlyBars(buckets: snapshot.buckets, palette: palette)
          .frame(height: 120)
        if let peak = snapshot.buckets.peakIndex {
          let start = snapshot.buckets.starts[peak]
          let end = peak + 1 < snapshot.buckets.starts.count ? snapshot.buckets.starts[peak + 1] : snapshot.buckets.end
          Text("\(strings.text("peakTime")) · \(HourRange.text(start: start, end: end))")
            .font(.footnote)
            .foregroundColor(palette.muted)
        }
      }
    }
  }
}

/// Reports, weekly and monthly (Android reports_screen.dart: the three
/// summary cards, the time chart, "Most used apps").
struct RangeReportView: View {
  let snapshot: UsageSnapshot
  let palette: ReportPalette

  var body: some View {
    let strings = snapshot.strings
    RangeSummary(snapshot: snapshot, palette: palette)
    DailyChartCard(snapshot: snapshot, palette: palette)
    if snapshot.hasData {
      ReportCard(palette: palette) {
        VStack(alignment: .leading, spacing: 8) {
          CardTitle(strings.text("topApps"), palette: palette)
          AppList(
            apps: snapshot.apps, limit: 8, extraHidden: snapshot.hiddenApps, strings: strings,
            palette: palette, ranked: true)
        }
      }
    }
  }
}

/// One picked selection (Android usage_details_screen.dart: totals, the day
/// dial or the range chart, and the apps it holds).
struct AppDetailReportView: View {
  let snapshot: UsageSnapshot
  let palette: ReportPalette

  var body: some View {
    let strings = snapshot.strings
    if snapshot.isHourly {
      HStack(spacing: 8) {
        MetricCard(value: strings.duration(snapshot.total), label: strings.text("totalTime"), palette: palette)
        MetricCard(value: "\(snapshot.pickups)", label: strings.text("pickups"), palette: palette)
        MetricCard(
          value: "\(snapshot.notifications)", label: strings.text("notifications"), palette: palette)
      }
      ReportCard(palette: palette) {
        HourDial(buckets: snapshot.buckets, total: snapshot.total, strings: strings, palette: palette)
      }
    } else {
      RangeSummary(snapshot: snapshot, palette: palette)
      DailyChartCard(snapshot: snapshot, palette: palette)
    }
    if snapshot.hasData {
      ReportCard(palette: palette) {
        VStack(alignment: .leading, spacing: 8) {
          CardTitle(strings.text("groupApps"), palette: palette)
          AppList(
            apps: snapshot.apps, limit: 6, extraHidden: snapshot.hiddenApps, strings: strings,
            palette: palette)
        }
      }
    }
  }
}

// MARK: - Building blocks

struct ReportCard<Content: View>: View {
  let palette: ReportPalette
  var fill: Color?
  @ViewBuilder let content: () -> Content

  var body: some View {
    content()
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 20, style: .continuous).fill(fill ?? palette.card))
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(palette.cardBorder, lineWidth: fill == nil ? 0 : 1))
  }
}

struct CardTitle: View {
  let text: String
  let palette: ReportPalette

  init(_ text: String, palette: ReportPalette) {
    self.text = text
    self.palette = palette
  }

  var body: some View {
    Text(text)
      .font(.system(size: 17, weight: .heavy))
      .foregroundColor(palette.onSurface)
  }
}

/// Reports' `_MetricCard`: a value over its label.
struct MetricCard: View {
  let value: String
  let label: String
  let palette: ReportPalette

  var body: some View {
    VStack(spacing: 4) {
      Text(value)
        .font(.system(size: 17, weight: .heavy))
        .foregroundColor(palette.onSurface)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(label)
        .font(.caption)
        .foregroundColor(palette.muted)
        .lineLimit(2)
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.card))
  }
}

/// The usage calendar's stat tiles: icon in a tinted circle, value, label.
struct StatTile: View {
  let symbol: String
  let value: String
  let label: String
  let palette: ReportPalette

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Image(systemName: symbol)
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(palette.primary)
        .frame(width: 28, height: 28)
        .background(Circle().fill(palette.primary.opacity(0.14)))
      Text(value)
        .font(.system(size: 16, weight: .heavy))
        .foregroundColor(palette.onSurface)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(label)
        .font(.caption2)
        .foregroundColor(palette.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.tile))
  }
}

struct RangeSummary: View {
  let snapshot: UsageSnapshot
  let palette: ReportPalette

  var body: some View {
    let strings = snapshot.strings
    HStack(spacing: 8) {
      MetricCard(value: strings.duration(snapshot.total), label: strings.text("totalUsage"), palette: palette)
      MetricCard(
        value: strings.duration(snapshot.buckets.average), label: strings.text("dailyAverage"),
        palette: palette)
      MetricCard(
        value: "\(snapshot.buckets.activeCount)", label: strings.text("activeDays"), palette: palette)
    }
  }
}

/// The details chart card: date range, total, one bar per day; the last day
/// leads, the rest recede (usage_details_charts.dart `_UsageBarChart`).
struct DailyChartCard: View {
  let snapshot: UsageSnapshot
  let palette: ReportPalette

  var body: some View {
    let buckets = snapshot.buckets
    ReportCard(palette: palette) {
      VStack(alignment: .leading, spacing: 8) {
        Text(rangeLabel)
          .font(.footnote.weight(.semibold))
          .foregroundColor(palette.muted)
        Text(snapshot.strings.duration(snapshot.total))
          .font(.system(size: 24, weight: .bold))
          .foregroundColor(palette.onSurface)
        if snapshot.hasData {
          DailyBars(buckets: buckets, strings: snapshot.strings, palette: palette)
            .frame(height: 170)
        } else {
          EmptyNote(text: snapshot.strings.text("noData"), palette: palette)
            .frame(height: 170)
        }
      }
    }
  }

  private var rangeLabel: String {
    let buckets = snapshot.buckets
    guard let first = buckets.starts.first, let last = buckets.starts.last else { return "" }
    let formatter = DateFormatter()
    formatter.locale = snapshot.strings.localeIdentifier.map(Locale.init(identifier:)) ?? .current
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
  }
}

struct DailyBars: View {
  let buckets: UsageBuckets
  let strings: ReportStrings
  let palette: ReportPalette

  private struct Point: Identifiable {
    let id: Int
    let day: Date
    let minutes: Double
    let seconds: TimeInterval
  }

  var body: some View {
    let points = buckets.starts.indices.map {
      Point(id: $0, day: buckets.starts[$0], minutes: buckets.seconds[$0] / 60, seconds: buckets.seconds[$0])
    }
    let isWeek = points.count <= 7
    let last = points.count - 1
    let labelFormat: Date.FormatStyle =
      isWeek ? Date.FormatStyle.dateTime.weekday(.abbreviated) : Date.FormatStyle.dateTime.day().month(.abbreviated)
    Chart(points) { point in
      BarMark(
        x: .value("Day", point.day, unit: .day),
        y: .value("Minutes", point.minutes)
      )
      .foregroundStyle(palette.primary.opacity(point.id == last ? 1 : 0.8))
      .cornerRadius(5)
      .annotation(position: .top, spacing: 4) {
        if isWeek && point.seconds >= 60 {
          Text(strings.duration(point.seconds))
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(palette.muted)
            .fixedSize()
        }
      }
    }
    .chartYAxis(.hidden)
    .chartXAxis {
      AxisMarks(values: .stride(by: .day, count: isWeek ? 1 : 7)) { _ in
        AxisValueLabel(format: labelFormat)
          .foregroundStyle(palette.muted)
      }
    }
  }
}

struct HourlyBars: View {
  let buckets: UsageBuckets
  let palette: ReportPalette

  private struct Point: Identifiable {
    let id: Int
    let hour: Date
    let minutes: Double
  }

  var body: some View {
    let points = buckets.starts.indices.map {
      Point(id: $0, hour: buckets.starts[$0], minutes: buckets.seconds[$0] / 60)
    }
    Chart(points) { point in
      BarMark(
        x: .value("Hour", point.hour, unit: .hour),
        y: .value("Minutes", point.minutes)
      )
      .foregroundStyle(palette.primary.opacity(point.minutes >= 30 ? 1 : 0.75))
      .cornerRadius(3)
    }
    .chartYAxis(.hidden)
    .chartYScale(domain: 0...60)
    .chartXScale(domain: (buckets.starts.first ?? buckets.end)...buckets.end)
    .chartXAxis {
      AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
        AxisGridLine().foregroundStyle(palette.tick.opacity(0.4))
        AxisValueLabel(format: Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)))
          .foregroundStyle(palette.muted)
      }
    }
  }
}

/// The 24-hour dial (usage_calendar.dart `UsageDayTimeline`): one slice per
/// hour from dim to bright blue, ticks, 00/06/12/18, the day's total in the
/// centre. Tapping a slice shows that hour; tapping the centre clears it.
struct HourDial: View {
  let buckets: UsageBuckets
  let total: TimeInterval
  let strings: ReportStrings
  let palette: ReportPalette
  @State private var selected: Int?

  var body: some View {
    VStack(spacing: 8) {
      GeometryReader { proxy in
        let side = min(proxy.size.width, proxy.size.height)
        let geometry = DialGeometry(side: side)
        ZStack {
          Canvas { context, size in
            draw(in: &context, geometry: DialGeometry(side: min(size.width, size.height)), size: size)
          }
          centre
            .frame(width: geometry.inner * 1.5)
          ForEach([0, 6, 12, 18], id: \.self) { hour in
            Text(String(format: "%02d", hour))
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(palette.muted)
              .position(geometry.labelPosition(hour: hour, in: proxy.size))
          }
        }
        .contentShape(Rectangle())
        .gesture(
          SpatialTapGesture().onEnded { value in
            selected = geometry.hour(at: value.location, in: proxy.size)
          })
      }
      .frame(height: 260)
      Text(strings.text("tapHour"))
        .font(.caption)
        .foregroundColor(palette.muted)
    }
  }

  @ViewBuilder
  private var centre: some View {
    if let hour = selected, hour < buckets.seconds.count {
      let end = hour + 1 < buckets.starts.count ? buckets.starts[hour + 1] : buckets.end
      VStack(spacing: 2) {
        Text(HourRange.text(start: buckets.starts[hour], end: end))
          .font(.system(size: 18, weight: .heavy))
          .foregroundColor(palette.onSurface)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(strings.duration(buckets.seconds[hour]))
          .font(.system(size: 22, weight: .heavy))
          .foregroundColor(palette.primary)
        Text("\(strings.text("totalTime")) \(strings.duration(total))")
          .font(.caption)
          .foregroundColor(palette.muted)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    } else if total < 1 {
      Text(strings.text("noData"))
        .font(.footnote)
        .foregroundColor(palette.muted)
        .multilineTextAlignment(.center)
    } else {
      VStack(spacing: 2) {
        Text(strings.duration(total))
          .font(.system(size: 28, weight: .heavy))
          .foregroundColor(palette.onSurface)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(strings.text("totalTime"))
          .font(.subheadline)
          .foregroundColor(palette.muted)
      }
    }
  }

  private func draw(in context: inout GraphicsContext, geometry: DialGeometry, size: CGSize) {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let count = buckets.seconds.count
    guard count > 0 else { return }
    let slice = 2 * Double.pi / Double(count)
    let gap = 1.6 / Double(geometry.outer)
    for index in 0..<count {
      let from = -Double.pi / 2 + Double(index) * slice + gap / 2
      let path = geometry.sector(center: center, from: from, to: from + slice - gap)
      let share = UsageReportMath.dialShade(buckets.seconds[index])
      context.fill(path, with: .color(palette.dialColor(share)))
      if selected == index {
        context.stroke(path, with: .color(.white), lineWidth: 2)
      }
    }
    for hour in 0..<24 {
      let angle = -Double.pi / 2 + Double(hour) / 24 * 2 * Double.pi
      let length: CGFloat = hour % 6 == 0 ? 9 : 4
      let direction = CGPoint(x: cos(angle), y: sin(angle))
      var tick = Path()
      tick.move(
        to: CGPoint(
          x: center.x + direction.x * (geometry.outer + 5),
          y: center.y + direction.y * (geometry.outer + 5)))
      tick.addLine(
        to: CGPoint(
          x: center.x + direction.x * (geometry.outer + 5 + length),
          y: center.y + direction.y * (geometry.outer + 5 + length)))
      context.stroke(tick, with: .color(palette.tick), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
    }
  }
}

/// Ring sizes of the dial, as `_ClockPainter`: the ring is a quarter of the
/// radius thick, with room outside for ticks and hour labels.
struct DialGeometry {
  let side: CGFloat
  var outer: CGFloat { max(10, side / 2 - 30) }
  var inner: CGFloat { outer * 0.76 }

  func sector(center: CGPoint, from: Double, to: Double) -> Path {
    var path = Path()
    path.addArc(center: center, radius: outer, startAngle: .radians(from), endAngle: .radians(to), clockwise: false)
    path.addArc(center: center, radius: inner, startAngle: .radians(to), endAngle: .radians(from), clockwise: true)
    path.closeSubpath()
    return path
  }

  func labelPosition(hour: Int, in size: CGSize) -> CGPoint {
    let angle = -Double.pi / 2 + Double(hour) / 24 * 2 * Double.pi
    let radius = Double(outer + 24)
    let x = Double(size.width) / 2 + cos(angle) * radius
    let y = Double(size.height) / 2 + sin(angle) * radius
    return CGPoint(x: x, y: y)
  }

  /// The hour slice under `point`, or nil inside the ring (clears).
  func hour(at point: CGPoint, in size: CGSize) -> Int? {
    let dx = point.x - size.width / 2
    let dy = point.y - size.height / 2
    let distance = (dx * dx + dy * dy).squareRoot()
    guard distance >= inner - 12 else { return nil }
    var angle = atan2(Double(dy), Double(dx)) + Double.pi / 2
    if angle < 0 { angle += 2 * Double.pi }
    return min(23, Int(angle / (2 * Double.pi) * 24))
  }
}

enum HourRange {
  /// "13:00 – 14:00" in the locale's time style; just the start without end.
  static func text(start: Date, end: Date?) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    guard let end = end else { return formatter.string(from: start) }
    return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
  }
}

/// The bubble screen's category filter chips ("All" first), wrapped onto at
/// most two rows because horizontal drags belong to Flutter's day paging.
struct CategoryChips: View {
  let categories: [ReportCategory]
  @Binding var selected: Int?
  let strings: ReportStrings
  let palette: ReportPalette

  var body: some View {
    FlowLayout(spacing: 8) {
      chip(id: nil, label: strings.text("all"), seconds: nil)
      ForEach(categories) { category in
        chip(id: category.id, label: category.name, seconds: category.seconds)
      }
    }
  }

  private func chip(id: Int?, label: String, seconds: TimeInterval?) -> some View {
    let isSelected = selected == id
    return Button {
      selected = id
    } label: {
      HStack(spacing: 6) {
        Text(label)
          .fontWeight(isSelected ? .bold : .medium)
          .foregroundColor(isSelected ? palette.primary : palette.onSurface.opacity(0.72))
        if let seconds = seconds {
          Text(strings.duration(seconds))
            .foregroundColor((isSelected ? palette.primary : palette.onSurface).opacity(0.6))
        }
      }
      .font(.system(size: 13))
      .lineLimit(1)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(
        Capsule().fill(isSelected ? palette.primary.opacity(0.18) : palette.onSurface.opacity(0.05)))
      .overlay(
        Capsule().stroke(
          isSelected ? palette.primary.opacity(0.55) : palette.onSurface.opacity(0.06), lineWidth: 1))
    }
    .buttonStyle(.plain)
  }
}

/// Lays children out in rows, at most `maxRows`; the rest are left out.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8
  var maxRows = 2

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(width: proposal.width ?? 320, subviews: subviews)
    let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
    return CGSize(width: proposal.width ?? 320, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let rows = arrange(width: bounds.width, subviews: subviews)
    var placed = Set<Int>()
    var y = bounds.minY
    for row in rows {
      var x = bounds.minX
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(
          at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
        x += size.width + spacing
        placed.insert(index)
      }
      y += row.height + spacing
    }
    // Rows past the limit: out of sight, zero size.
    for index in subviews.indices where !placed.contains(index) {
      subviews[index].place(at: CGPoint(x: bounds.minX, y: bounds.minY), proposal: .zero)
    }
  }

  private struct Row {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = []
    var current = Row()
    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.unspecified)
      let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
      if !current.indices.isEmpty && needed > width {
        rows.append(current)
        if rows.count == maxRows { return rows }
        current = Row()
      }
      current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
      current.height = max(current.height, size.height)
      current.indices.append(index)
    }
    if !current.indices.isEmpty && rows.count < maxRows { rows.append(current) }
    return rows
  }
}

/// Apps, longest first: icon, name, a time bar and the time (summary_tile.dart).
struct AppList: View {
  let apps: [ReportApp]
  let limit: Int
  let extraHidden: Int
  let strings: ReportStrings
  let palette: ReportPalette
  var ranked = false

  var body: some View {
    let shown = Array(apps.prefix(limit))
    let maximum = shown.first?.seconds ?? 0
    let hidden = apps.count - shown.count + extraHidden
    VStack(alignment: .leading, spacing: 0) {
      if shown.isEmpty {
        EmptyNote(text: strings.text("noData"), palette: palette)
          .frame(height: 56)
      }
      ForEach(Array(shown.enumerated()), id: \.element.id) { position, app in
        AppRow(
          app: app, rank: ranked ? position + 1 : nil,
          fraction: UsageReportMath.fraction(app.seconds, of: maximum), strings: strings,
          palette: palette)
      }
      if hidden > 0 {
        Text(strings.moreApps(hidden))
          .font(.footnote.weight(.semibold))
          .foregroundColor(palette.muted)
          .padding(.top, 6)
      }
    }
  }
}

struct AppRow: View {
  let app: ReportApp
  let rank: Int?
  let fraction: Double
  let strings: ReportStrings
  let palette: ReportPalette

  var body: some View {
    HStack(spacing: 12) {
      if let rank = rank {
        Text("#\(rank)")
          .font(.caption.weight(.bold))
          .foregroundColor(palette.muted)
          .frame(width: 26, alignment: .leading)
      }
      AppIcon(token: app.token, name: app.name, size: 36, palette: palette)
      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .firstTextBaseline) {
          appName
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(palette.onSurface)
            .lineLimit(1)
          Spacer(minLength: 8)
          Text(strings.duration(app.seconds))
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(palette.onSurface)
        }
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule().fill(palette.track)
            Capsule().fill(palette.primary)
              .frame(width: max(4, proxy.size.width * CGFloat(fraction)))
          }
        }
        .frame(height: 5)
        if app.pickups > 0 {
          Text("\(strings.text("pickups")): \(app.pickups)")
            .font(.caption2)
            .foregroundColor(palette.muted)
        }
      }
    }
    .frame(height: 56)
  }

  @ViewBuilder
  private var appName: some View {
    if !app.name.isEmpty {
      Text(app.name)
    } else if let token = app.token {
      Label(token).labelStyle(.titleOnly)
    } else {
      Text("–")
    }
  }
}

/// The app's own icon (`Label(token)`), or a letter avatar as in
/// app_icon_avatar.dart.
struct AppIcon: View {
  let token: ApplicationToken?
  let name: String
  let size: CGFloat
  let palette: ReportPalette

  var body: some View {
    if let token = token {
      Label(token)
        .labelStyle(.iconOnly)
        .font(.system(size: size * 0.8))
        .frame(width: size, height: size)
    } else {
      Text(name.first.map { String($0).uppercased() } ?? "?")
        .font(.system(size: size * 0.42, weight: .semibold))
        .foregroundColor(palette.primary)
        .frame(width: size, height: size)
        .background(Circle().fill(palette.primary.opacity(0.18)))
    }
  }
}

struct EmptyNote: View {
  let text: String
  let palette: ReportPalette

  var body: some View {
    Text(text)
      .font(.footnote)
      .foregroundColor(palette.muted)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
