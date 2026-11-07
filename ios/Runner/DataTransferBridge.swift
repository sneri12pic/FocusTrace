import Flutter
import Foundation
import UIKit
import UniformTypeIdentifiers

/// `focustrace/data_transfer` on iOS, Android's `DataTransferDocumentBridge.kt`
/// with the Files pickers:
/// - `saveBackup({suggestedFileName, contents})`: writes the JSON to a
///   temporary file and lets the user export a copy anywhere in Files
///   (`UIDocumentPickerViewController(forExporting:)`); true when saved,
///   false when cancelled.
/// - `openBackup`: picks a JSON or text file
///   (`forOpeningContentTypes:`), reads it inside security-scoped access and
///   answers its contents, or nil when cancelled. Files over 10 MB fail.
final class DataTransferBridge: NSObject, UIDocumentPickerDelegate {
  static let shared = DataTransferBridge()

  static let maxBackupBytes = 10 * 1024 * 1024

  private enum Mode {
    case save(URL)
    case open
  }

  private var pending: FlutterResult?
  private var mode: Mode?
  private var topViewController: () -> UIViewController? = { nil }

  func register(
    with messenger: FlutterBinaryMessenger,
    topViewController: @escaping () -> UIViewController?
  ) {
    self.topViewController = topViewController
    FlutterMethodChannel(name: "focustrace/data_transfer", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard pending == nil else {
      result(
        FlutterError(
          code: "TRANSFER_IN_PROGRESS", message: "Another data transfer is already open.",
          details: nil))
      return
    }
    switch call.method {
    case "saveBackup":
      let args = call.arguments as? [String: Any] ?? [:]
      guard let name = (args["suggestedFileName"] as? String).map(Self.safeFileName),
        !name.isEmpty, let contents = args["contents"] as? String
      else {
        result(
          FlutterError(
            code: "INVALID_EXPORT", message: "Backup name and contents are required.",
            details: nil))
        return
      }
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("focustrace-export-\(UUID().uuidString)", isDirectory: true)
      let file = directory.appendingPathComponent(name)
      do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: file, options: .atomic)
      } catch {
        result(FlutterError(code: "DATA_TRANSFER_FAILED", message: "\(error)", details: nil))
        return
      }
      present(UIDocumentPickerViewController(forExporting: [file], asCopy: true),
        mode: .save(file), result: result)
    case "openBackup":
      present(
        UIDocumentPickerViewController(forOpeningContentTypes: [.json, .plainText]),
        mode: .open, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func present(
    _ picker: UIDocumentPickerViewController, mode: Mode, result: @escaping FlutterResult
  ) {
    guard let presenter = topViewController() else {
      if case .save(let file) = mode { Self.removeTemporary(file) }
      result(
        FlutterError(code: "DATA_TRANSFER_FAILED", message: "No screen to show the picker on.",
          details: nil))
      return
    }
    picker.delegate = self
    picker.allowsMultipleSelection = false
    picker.shouldShowFileExtensions = true
    pending = result
    self.mode = mode
    presenter.present(picker, animated: true)
  }

  // MARK: UIDocumentPickerDelegate

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
  {
    guard let result = pending, let mode = mode else { return }
    finish()
    switch mode {
    case .save(let file):
      Self.removeTemporary(file)
      result(!urls.isEmpty)
    case .open:
      guard let url = urls.first else {
        result(nil)
        return
      }
      do {
        result(try Self.readBackup(at: url))
      } catch {
        result(
          FlutterError(code: "DATA_TRANSFER_FAILED", message: "\(error.localizedDescription)",
            details: nil))
      }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let result = pending, let mode = mode else { return }
    finish()
    switch mode {
    case .save(let file):
      Self.removeTemporary(file)
      result(false)
    case .open:
      result(nil)
    }
  }

  private func finish() {
    pending = nil
    mode = nil
  }

  // MARK: Files

  private static func readBackup(at url: URL) throws -> String {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    var coordinated: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
    var coordinationError: NSError?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) {
      readable in
      coordinated = Result {
        let size = try readable.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maxBackupBytes else {
          throw NSError(
            domain: "FocusTrace", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Backup file is larger than 10 MB."])
        }
        return try Data(contentsOf: readable)
      }
    }
    if let error = coordinationError { throw error }
    let data = try coordinated.get()
    guard data.count <= maxBackupBytes else {
      throw NSError(
        domain: "FocusTrace", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Backup file is larger than 10 MB."])
    }
    guard let text = String(data: data, encoding: .utf8) else {
      throw NSError(
        domain: "FocusTrace", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Backup file is not UTF-8 text."])
    }
    return text
  }

  private static func removeTemporary(_ file: URL) {
    try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
  }

  /// The suggested name without path separators.
  private static func safeFileName(_ name: String) -> String {
    name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
