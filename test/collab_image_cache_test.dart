import 'dart:io';

import 'package:cses_editor/src/ui/modal/collab_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 验证无数据库图片缓存的跨实例离线读取、更新回退和容量边界。
void main() {
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('editor-images-'),
  );
  tearDown(() async => directory.delete(recursive: true));

  test(
    'raster and SVG bytes survive a new cache and client without network',
    () async {
      final client = MockClient(
        (request) async => http.Response(
          request.url.path.endsWith('.svg') ? '<svg />' : 'raster-bytes',
          200,
        ),
      );
      final cache = CollabImageCache(directory: () async => directory);
      final urls = ['https://example.com/a.png', 'https://example.com/中文.svg'];
      for (final url in urls) {
        await cache.load(url, client);
      }
      client.close();
      final offline = MockClient(
        (_) async => throw const SocketException('offline'),
      );
      addTearDown(offline.close);
      for (final url in urls) {
        final bytes = await CollabImageCache(
          directory: () async => directory,
        ).load(url, offline);
        expect(bytes, isNotEmpty);
      }
    },
  );

  test('full query strings isolate cached sources', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response(request.url.query, 200);
    });
    addTearDown(client.close);
    final cache = CollabImageCache(directory: () async => directory);
    expect(
      await cache.load('https://example.com/a?token=1', client),
      isNot(await cache.load('https://example.com/a?token=2', client)),
    );
    expect(requests, 2);
  });

  test('stale images remain readable during network failure', () async {
    final client = MockClient((_) async => http.Response('saved', 200));
    final cache = CollabImageCache(directory: () async => directory);
    await cache.load('https://example.com/a', client);
    client.close();
    final offline = MockClient(
      (_) async => throw const SocketException('offline'),
    );
    addTearDown(offline.close);
    final stale = CollabImageCache(
      directory: () async => directory,
      freshFor: Duration.zero,
    );
    expect(
      await stale.load('https://example.com/a', offline),
      'saved'.codeUnits,
    );
  });

  test('expired content refreshes atomically when network returns', () async {
    var response = 'old';
    final client = MockClient((_) async => http.Response(response, 200));
    addTearDown(client.close);
    final cache = CollabImageCache(
      directory: () async => directory,
      freshFor: Duration.zero,
    );
    await cache.load('https://example.com/a', client);
    response = 'new';
    expect(await cache.load('https://example.com/a', client), 'new'.codeUnits);
    final pending = await directory
        .list(recursive: true)
        .where((entry) => entry.path.endsWith('.tmp'))
        .toList();
    expect(pending, isEmpty);
  });

  test('entry and byte budgets prune old cached files', () async {
    final client = MockClient((_) async => http.Response('12345', 200));
    addTearDown(client.close);
    final cache = CollabImageCache(
      directory: () async => directory,
      maxEntries: 2,
      maxBytes: 7,
    );
    for (var i = 0; i < 4; i++) {
      await cache.load('https://example.com/$i', client);
    }
    final files = await directory
        .list(recursive: true)
        .where((entry) => entry is File && entry.path.endsWith('.image'))
        .cast<File>()
        .toList();
    expect(files.length, 1);
    expect(await files.single.length(), 5);
  });

  test('cache failure does not prevent image download', () async {
    final client = MockClient((_) async => http.Response('image', 200));
    addTearDown(client.close);
    final cache = CollabImageCache(
      directory: () async => throw const FileSystemException('no cache'),
    );
    expect(
      await cache.load('https://example.com/a', client),
      'image'.codeUnits,
    );
  });

  test('failed downloads never become cached images', () async {
    final client = MockClient((_) async => http.Response('error', 500));
    addTearDown(client.close);
    final cache = CollabImageCache(directory: () async => directory);
    await expectLater(
      cache.load('https://example.com/a', client),
      throwsA(isA<HttpException>()),
    );
    expect(
      await directory
          .list(recursive: true)
          .where((entry) => entry is File)
          .toList(),
      isEmpty,
    );
  });
}
