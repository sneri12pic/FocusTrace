import 'package:flutter/services.dart';

abstract class BackupDocumentDataSource {
  Future<bool> saveJson({
    required String suggestedFileName,
    required String contents,
  });

  Future<String?> openJson();
}

class AndroidBackupDocumentDataSource implements BackupDocumentDataSource {
  AndroidBackupDocumentDataSource({
    MethodChannel channel = const MethodChannel('focustrace/data_transfer'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<bool> saveJson({
    required String suggestedFileName,
    required String contents,
  }) async {
    return await _channel.invokeMethod<bool>('saveBackup', {
          'suggestedFileName': suggestedFileName,
          'contents': contents,
        }) ??
        false;
  }

  @override
  Future<String?> openJson() {
    return _channel.invokeMethod<String>('openBackup');
  }
}

class UnsupportedBackupDocumentDataSource implements BackupDocumentDataSource {
  const UnsupportedBackupDocumentDataSource();

  @override
  Future<String?> openJson() {
    throw UnsupportedError('Data transfer is not supported on this platform.');
  }

  @override
  Future<bool> saveJson({
    required String suggestedFileName,
    required String contents,
  }) {
    throw UnsupportedError('Data transfer is not supported on this platform.');
  }
}
