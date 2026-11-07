class DataImportResult {
  const DataImportResult({
    required this.importedRows,
    this.missingAppGroups = 0,
  });

  final int importedRows;

  /// iOS: app groups picked in Apple's picker that rules or routines in the
  /// backup refer to but that neither the backup nor this device holds (a
  /// backup from an older version or another platform). Those rules stay and
  /// need their apps chosen again.
  final int missingAppGroups;
}

abstract class DataTransferRepository {
  /// Returns false when the user closes the system save picker.
  Future<bool> exportData();

  /// Returns null when the user closes the system open picker.
  Future<DataImportResult?> importData();
}
