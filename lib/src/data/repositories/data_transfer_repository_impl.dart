import 'dart:convert';

import '../../domain/repositories/data_transfer_repository.dart';
import '../datasources/backup_document_data_source.dart';
import '../datasources/focus_trace_local_data_source.dart';
import '../datasources/screen_time_channel.dart';

class DataTransferRepositoryImpl implements DataTransferRepository {
  DataTransferRepositoryImpl({
    required PortableFocusTraceDataSource localDataSource,
    required BackupDocumentDataSource documentDataSource,
    ScreenTimeChannel? appGroupSelections,
    DateTime Function()? clock,
  }) : _localDataSource = localDataSource,
       _documentDataSource = documentDataSource,
       _appGroupSelections = appGroupSelections,
       _clock = clock ?? DateTime.now;

  static const formatName = 'focustrace-portable-backup';
  static const formatVersion = 1;
  static const databaseSchemaVersion = 4;

  /// Optional top-level key (iOS): the opaque, encoded
  /// `FamilyActivitySelection` of every `ios-sel:<id>` app group the backed
  /// up rules, routines and limits refer to, by id. Readers that do not know
  /// it (Android, older versions) ignore it, so the format version stays 1.
  static const iosSelectionsKey = 'iosSelections';

  static final _selectionKeyPattern = RegExp(
    '${RegExp.escape(iosSelectionKeyPrefix)}([A-Za-z0-9-]+)',
  );

  final PortableFocusTraceDataSource _localDataSource;
  final BackupDocumentDataSource _documentDataSource;

  /// iOS only: where picked app groups live (the App Group store).
  final ScreenTimeChannel? _appGroupSelections;
  final DateTime Function() _clock;

  @override
  Future<bool> exportData() async {
    final now = _clock().toUtc();
    final tables = await _localDataSource.exportPortableData();
    final selections = _appGroupSelections;
    final selectionIds = referencedSelectionIds(tables);
    final encodedSelections = selections == null || selectionIds.isEmpty
        ? const <String, String>{}
        : await selections.exportSelections(selectionIds.toList()..sort());
    final contents = const JsonEncoder.withIndent('  ').convert({
      'format': formatName,
      'formatVersion': formatVersion,
      'databaseSchemaVersion': databaseSchemaVersion,
      'exportedAt': now.toIso8601String(),
      'tables': tables,
      if (encodedSelections.isNotEmpty) iosSelectionsKey: encodedSelections,
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

    final encodedSelections = _parseSelections(decoded[iosSelectionsKey]);

    final importedRows = await _localDataSource.importPortableData(tables);
    final selections = _appGroupSelections;
    if (selections == null) {
      return DataImportResult(importedRows: importedRows);
    }
    if (encodedSelections.isNotEmpty) {
      await selections.importSelections(encodedSelections);
    }
    var missing = 0;
    for (final id in referencedSelectionIds(tables)) {
      if (await selections.selectionSummary(id) == null) missing++;
    }
    return DataImportResult(
      importedRows: importedRows,
      missingAppGroups: missing,
    );
  }

  /// Ids of the `ios-sel:` app groups the backed-up settings (rules,
  /// routines, limits) refer to.
  static Set<String> referencedSelectionIds(
    Map<String, List<Map<String, Object?>>> tables,
  ) {
    final ids = <String>{};
    for (final row in tables['settings'] ?? const <Map<String, Object?>>[]) {
      final value = row['value'];
      if (value is! String) continue;
      for (final match in _selectionKeyPattern.allMatches(value)) {
        ids.add(match.group(1)!);
      }
    }
    return ids;
  }

  static Map<String, String> _parseSelections(Object? value) {
    if (value == null) return const {};
    if (value is! Map) {
      throw const FormatException('Invalid FocusTrace backup app groups.');
    }
    final result = <String, String>{};
    for (final entry in value.entries) {
      final id = entry.key;
      final data = entry.value;
      if (id is! String ||
          data is! String ||
          !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(id)) {
        throw const FormatException('Invalid FocusTrace backup app groups.');
      }
      result[id] = data;
    }
    return result;
  }
}
