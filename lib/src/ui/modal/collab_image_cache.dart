import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 图片字节的独立文件缓存，不使用数据库或持有网络客户端。
/// 文件位于App私有缓存目录，以完整URL的哈希隔离来源；创建者仍负责关闭HTTP客户端。
///
/// ```dart
/// import 'package:http/http.dart' as http;
/// import 'package:cses_editor/src/ui/modal/collab_image_cache.dart';
/// final client = http.Client();
/// try {
///   final bytes = await CollabImageCache().load('https://example.com/image.png', client);
/// } finally {
///   client.close();
/// }
/// ```
class CollabImageCache {
  /// [directory]返回App私有缓存根目录，默认系统临时目录；不获取目录的释放所有权。
  /// [maxEntries]限制缓存文件数，默认200；[maxBytes]限制总字节数，默认128MiB，均须为正。
  /// [freshFor]默认30天，过期时尝试更新，网络失败仍可读取原文件；不能为负。
  CollabImageCache({
    Future<Directory> Function()? directory,
    this.maxEntries = 200,
    this.maxBytes = 128 * 1024 * 1024,
    this.freshFor = const Duration(days: 30),
  }) : _directory = directory ?? getTemporaryDirectory {
    if (maxEntries <= 0 || maxBytes <= 0 || freshFor.isNegative) {
      throw ArgumentError('图片缓存容量与有效期无效');
    }
  }

  final Future<Directory> Function() _directory;

  /// 保留文件数上限；超出后删除较早修改的缓存文件。
  final int maxEntries;

  /// 缓存总容量上限，单位字节；单张超限图片仍可展示但不缓存。
  final int maxBytes;

  /// 缓存的新鲜时长；过期数据仅在网络更新失败时回退使用。
  final Duration freshFor;

  /// 读取完整[url]的字节，借用[client]下载；网络及HTTP失败向调用方传播。
  /// 缓存不可用时仍允许下载；写缓存失败不妨碍展示，旧缓存不会被部分写入覆盖。
  Future<Uint8List> load(String url, http.Client client) async {
    File? file;
    Uint8List? cached;
    try {
      final directory = Directory(
        '${(await _directory()).path}/cses-editor-images-v1',
      );
      await directory.create(recursive: true);
      final key = sha256.convert(utf8.encode(url)).toString();
      file = File('${directory.path}/$key.image');
      if (await file.exists()) {
        cached = await file.readAsBytes();
        if (DateTime.now().difference(await file.lastModified()) <= freshFor) {
          return cached;
        }
      }
    } catch (error) {
      debugPrint('图片缓存不可用: $error');
    }
    Uint8List bytes;
    try {
      final response = await client.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('图片下载失败: ${response.statusCode}');
      }
      bytes = response.bodyBytes;
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
    if (file != null && bytes.length <= maxBytes) {
      File? pending;
      try {
        pending = File(
          '${file.path}.${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}.tmp',
        );
        await pending.writeAsBytes(bytes, flush: true);
        await pending.rename(file.path);
        await _trim(file.parent);
      } catch (error) {
        debugPrint('图片缓存写入失败: $error');
      } finally {
        if (pending != null) {
          try {
            if (await pending.exists()) await pending.delete();
          } on FileSystemException catch (error) {
            debugPrint('图片缓存临时文件清理失败: $error');
          }
        }
      }
    }
    return bytes;
  }

  /// 对借用的[directory]按修改时间裁剪，仅删除本缓存的正式图片文件。
  Future<void> _trim(Directory directory) async {
    final entries = <(File, FileStat)>[];
    await for (final entry in directory.list()) {
      if (entry is File && entry.path.endsWith('.image')) {
        final stat = await entry.stat();
        if (stat.type == FileSystemEntityType.file) entries.add((entry, stat));
      }
    }
    entries.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    var bytes = entries.fold(0, (sum, entry) => sum + entry.$2.size);
    var count = entries.length;
    for (final entry in entries) {
      if (count <= maxEntries && bytes <= maxBytes) break;
      try {
        await entry.$1.delete();
      } on FileSystemException {
        // 并发读取/写入者可能已清理该文件，不影响当前图片展示。
      }
      count--;
      bytes -= entry.$2.size;
    }
  }
}
