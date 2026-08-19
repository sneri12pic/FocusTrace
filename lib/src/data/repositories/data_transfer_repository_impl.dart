import 'dart:convert';

import '../../domain/repositories/data_transfer_repository.dart';
import '../datasources/backup_document_data_source.dart';
import '../datasources/focus_trace_local_data_source.dart';

class DataTransferRepositoryImpl implements DataTransferRepository {
  DataTransferRepositoryImpl({
    required PortableFocusTraceDataSource localDataSource,
    required BackupDocumentDataSource documentDataSource,
    DateTime Function()? clock,
  }) : _localDataSource = localDataSource,
       _documentDataSource = documentDataSource,
       _clock = clock ?? DateTime.now;

  static const formatName = 'focustrace-portable-backup';
  static const formatVersion = 1;
  static const databaseSchemaVersion = 4;

  final PortableFocusTraceDataSource _localDataSource;
  final BackupDocumentDataSource _documentDataSource;
  final DateTime Function() _clock;

  @override
  Future<bool> exportData() async {
    final now = _clock().toUtc();
    final contents = const JsonEncoder.withIndent('  ').convert({
      'format': formatName,
      'formatVersion': formatVersion,
      'databaseSchemaVersion': databaseSchemaVersion,
      'exportedAt': now.toIso8601String(),
      'tables': await _localDataSource.exportPortableData(),
    });
    final timestamp = now
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return _documentDataSource.saveJson(
      suggestedFileName: 'focustrace-backup-$timestamp.json',
      contents: contents,
    );
  }

  @override
  Future<DataImportResult?> importData() async {
    final contents = await _documentDataSource.openJson();
    if (contents == null) {
      return null;
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, Object?> ||
        decoded['format'] != formatName ||
        decoded['formatVersion'] != formatVersion ||
        decoded['tables'] is! Map) {
      throw const FormatException('Not a supported FocusTrace backup.');
    }

    final rawTables = Map<Object?, Object?>.from(decoded['tables'] as Map);
    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in rawTables.entries) {
      if (entry.key is! String || entry.value is! List) {
        throw const FormatException('Invalid FocusTrace backup tables.');
      }
      tables[entry.key! as String] = [
        for (final row in entry.value! as List)
          if (row is Map)
            Map<String, Object?>.from(row)
          else
            throw const FormatException('Invalid FocusTrace backup row.'),
      ];
    }

    final importedRows = await _localDataSource.importPortableData(tables);
    return DataImportResult(importedRows: importedRows);
  }
}
