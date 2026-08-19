class DataImportResult {
  const DataImportResult({required this.importedRows});

  final int importedRows;
}

abstract class DataTransferRepository {
  /// Returns false when the user closes the system save picker.
  Future<bool> exportData();

  /// Returns null when the user closes the system open picker.
  Future<DataImportResult?> importData();
}
