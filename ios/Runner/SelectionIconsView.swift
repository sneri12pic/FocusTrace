import FamilyControls
import Flutter
import SwiftUI
import UIKit

/// Platform view `focustrace/selection_icons`: the icons of a stored picker
/// selection, drawn by `Label(token)` (the only way to show them; Flutter
/// never gets names or images). creationParams: selectionId, maxIcons, iconSize.
final class SelectionIconsFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let params = args as? [String: Any] ?? [:]
    let selection = (params["selectionId"] as? String)
      .flatMap { RestrictionStore.shared.selection(id: $0) } ?? FamilyActivitySelection()
    return SelectionIconsPlatformView(
      frame: frame,
      selection: selection,
      maxIcons: max(1, (params["maxIcons"] as? NSNumber)?.intValue ?? 3),
      iconSize: CGFloat((params["iconSize"] as? NSNumber)?.doubleValue ?? 28)
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class SelectionIconsPlatformView: NSObject, FlutterPlatformView {
  private let host: UIHostingController<SelectionIconsView>

  init(frame: CGRect, selection: FamilyActivitySelection, maxIcons: Int, iconSize: CGFloat) {
    host = UIHostingController(
      rootView: SelectionIconsView(selection: selection, maxIcons: maxIcons, iconSize: iconSize))
    host.view.frame = frame
    host.view.backgroundColor = .clear
    super.init()
  }

  func view() -> UIView { host.view }
}

struct SelectionIconsView: View {
  enum Item: Hashable {
    case app(ApplicationToken)
    case category(ActivityCategoryToken)
    case web(WebDomainToken)
  }

  let items: [Item]
  let maxIcons: Int
  let iconSize: CGFloat

  init(selection: FamilyActivitySelection, maxIcons: Int, iconSize: CGFloat) {
    items =
      selection.applicationTokens.map(Item.app)
      + selection.categoryTokens.map(Item.category)
      + selection.webDomainTokens.map(Item.web)
    self.maxIcons = maxIcons
    self.iconSize = iconSize
  }

  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array(items.prefix(maxIcons)), id: \.self) { item in
        icon(for: item)
          .labelStyle(.iconOnly)
          .font(.system(size: iconSize * 0.8))
          .frame(width: iconSize, height: iconSize)
      }
      if items.count > maxIcons {
        Text("+\(items.count - maxIcons)")
          .font(.system(size: iconSize * 0.45, weight: .semibold))
          .foregroundColor(Color.white.opacity(0.75))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private func icon(for item: Item) -> some View {
    switch item {
    case .app(let token): Label(token)
    case .category(let token): Label(token)
    case .web(let token): Label(token)
    }
  }
}
