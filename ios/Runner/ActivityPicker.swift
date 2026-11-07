import FamilyControls
import SwiftUI
import UIKit

/// Apple's FamilyActivityPicker with Cancel / Done, shown full screen from the
/// Flutter view controller. The selection stays opaque: Flutter only learns
/// how many apps, categories and websites it holds.
struct ActivityPickerView: View {
  @State private var selection: FamilyActivitySelection
  let doneLabel: String
  let cancelLabel: String
  let onFinish: (FamilyActivitySelection?) -> Void

  init(
    initial: FamilyActivitySelection,
    doneLabel: String,
    cancelLabel: String,
    onFinish: @escaping (FamilyActivitySelection?) -> Void
  ) {
    _selection = State(initialValue: initial)
    self.doneLabel = doneLabel
    self.cancelLabel = cancelLabel
    self.onFinish = onFinish
  }

  var body: some View {
    NavigationView {
      FamilyActivityPicker(selection: $selection)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(cancelLabel) { onFinish(nil) }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(doneLabel) { onFinish(selection) }
              .disabled(selection.isEmptySelection)
          }
        }
    }
    .navigationViewStyle(.stack)
    .preferredColorScheme(.dark)
  }
}

enum ActivityPickerPresenter {
  /// Calls `completion` exactly once, after the picker is dismissed, with the
  /// chosen selection or nil when cancelled.
  static func present(
    from presenter: UIViewController,
    initial: FamilyActivitySelection,
    doneLabel: String,
    cancelLabel: String,
    completion: @escaping (FamilyActivitySelection?) -> Void
  ) {
    var host: UIHostingController<ActivityPickerView>?
    var finished = false
    let view = ActivityPickerView(
      initial: initial, doneLabel: doneLabel, cancelLabel: cancelLabel
    ) { selection in
      guard !finished, let controller = host else { return }
      finished = true
      host = nil
      controller.dismiss(animated: true) { completion(selection) }
    }
    let controller = UIHostingController(rootView: view)
    // Swiping the sheet away would end without an answer for Flutter.
    controller.isModalInPresentation = true
    host = controller
    presenter.present(controller, animated: true)
  }
}
