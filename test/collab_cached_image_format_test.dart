import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cses_editor/src/ui/modal/collab_cached_image.dart';
import 'package:cses_editor/src/ui/modal/editor_resource_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// 通过原缓存视图验证带 SVG 元数据的位图与真实 SVG 的分流及绘制门禁。
/// 临时文件由测试创建并删除，不访问网络或宿主业务数据。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('image-format-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  final cases = <String, List<int>>{
    for (final suffix in ['png', 'jpg'])
      'raster-$suffix': File(
        'test/fixtures/raster-with-svg-metadata.$suffix',
      ).readAsBytesSync(),
    'svg-root': utf8.encode(
      '<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8"/></svg>',
    ),
    'svg-bom-xml': utf8.encode(
      '\ufeff <?xml version="1.0"?>\n<!-- metadata -->\n<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8"/></svg>',
    ),
  };
  for (final entry in cases.entries) {
    testWidgets('${entry.key} renders and releases its resource ticket', (
      tester,
    ) async {
      final url = 'https://image-format.invalid/${entry.key}';
      await tester.runAsync(() async {
        final cache = Directory('${directory.path}/cses-editor-images-v1');
        await cache.create(recursive: true);
        await File(
          '${cache.path}/${sha256.convert(utf8.encode(url))}.image',
        ).writeAsBytes(entry.value);
      });
      final tracker = EditorResourceTracker();
      await tester.pumpWidget(
        MaterialApp(
          home: EditorResourceScope(
            tracker: tracker,
            child: CollabCachedImage(
              url: url,
              width: 80,
              height: 80,
              loading: const Text('loading'),
              failure: const Text('failed'),
            ),
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await tester.pump();
        if (tracker.failed ||
            (tracker.value && find.text('loading').evaluate().isEmpty)) {
          break;
        }
      }
      expect(find.text('failed'), findsNothing);
      expect(tracker.failed, isFalse);
      expect(tracker.value, isTrue);
      expect(
        find.byType(SvgPicture),
        entry.key.startsWith('raster') ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tracker.value, isTrue);
      tracker.dispose();
    });
  }
}
