import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focustrace/src/data/datasources/platform_usage_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Android icon memory cache follows the package metadata version',
    () async {
      const channel = MethodChannel('focustrace/usage');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final firstBytes = Uint8List.fromList(const [1, 2, 3]);
      final sameVersionBytes = Uint8List.fromList(const [4, 5, 6]);
      final updatedBytes = Uint8List.fromList(const [7, 8, 9]);
      var metadataCall = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getAppMetadata');
        final arguments = Map<Object?, Object?>.from(call.arguments as Map);
        expect(arguments['packageNames'], ['example.app']);
        final iconBytes = switch (metadataCall++) {
          0 => firstBytes,
          1 => sameVersionBytes,
          _ => updatedBytes,
        };
        final version = metadataCall < 3 ? 100 : 200;
        return <Object?>[
          <String, Object?>{
            'packageName': 'example.app',
            'appName': 'Example',
            'iconBytes': iconBytes,
            'metadataVersion': version,
          },
        ];
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final dataSource = AndroidUsageDataSource(channel: channel);

      final first = await dataSource.getAppMetadata(const ['example.app']);
      final sameVersion = await dataSource.getAppMetadata(const [
        'example.app',
      ]);
      final updated = await dataSource.getAppMetadata(const ['example.app']);

      expect(first.single.iconBytes, orderedEquals(firstBytes));
      expect(sameVersion.single.iconBytes, same(first.single.iconBytes));
      expect(updated.single.iconBytes, orderedEquals(updatedBytes));
      expect(updated.single.iconBytes, isNot(same(first.single.iconBytes)));
    },
  );
}
