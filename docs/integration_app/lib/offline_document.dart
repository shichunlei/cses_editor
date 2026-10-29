import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:crypto/crypto.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/foundation.dart';

/// 宿主私有文件存储；每个文件只允许一个活动会话写入，适用于Android/iOS。
///
/// ```dart
/// import 'dart:io';
/// import 'package:cses_editor_host_sample/offline_document.dart';
/// final store = OfflineDocumentStore(Directory('/app/private'), 'user-1', 'doc-1');
/// final document = await store.read(); // 不存在为null，损坏抛错并保留文件。
/// ```
final class OfflineDocumentStore {
  /// [directory]为宿主私有目录；[scope]是账号/企业分区，[documentId]是稳定业务文档ID。
  /// 两者联合哈希为文件名，不能在多个窗口或Isolate中同时写入同一文档。
  OfflineDocumentStore(Directory directory, String scope, String documentId)
    : path =
          '${directory.path}/${sha256.convert(utf8.encode(jsonEncode([scope, documentId])))}.json';

  /// 宿主格式文件路径；不存认证令牌，也不读取其他App目录。
  final String path;

  /// 后台读取和解析完整草稿；不存在返回null，未知版本/损坏/超4MiB抛错。
  Future<Map<String, dynamic>?> read() => compute(_readDocument, path);

  /// 后台编码独立的[document]并flush、同目录rename提交；完成后才表示保存成功。
  /// 调用者必须串行访问；失败保留原正式文件，不读取残留pending文件。
  Future<void> write(Map<String, dynamic> document) =>
      compute(_writeDocument, (path, document));
}

/// 在后台从[path]读取宿主v1封装，不将非法数据回退为空白。
Map<String, dynamic>? _readDocument(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  if (file.lengthSync() > 4 * 1024 * 1024) {
    throw const FormatException('草稿超过4MiB');
  }
  final envelope = jsonDecode(file.readAsStringSync());
  if (envelope is! Map<String, dynamic> ||
      envelope['schemaVersion'] != 1 ||
      envelope['document'] is! Map<String, dynamic>) {
    throw const FormatException('草稿版本或结构无效');
  }
  final document = envelope['document'] as Map<String, dynamic>;
  final root = document['document'];
  if (root is! Map ||
      root['type'] != 'page' ||
      root['children'] is! List ||
      (root['children'] as List).isEmpty) {
    throw const FormatException('草稿正文无效');
  }
  return document;
}

/// 后台保存[request]中的路径及独立正文；rename为Android/iOS同文件系统替换。
void _writeDocument((String, Map<String, dynamic>) request) {
  final bytes = utf8.encode(
    jsonEncode({'schemaVersion': 1, 'document': request.$2}),
  );
  if (bytes.length > 4 * 1024 * 1024) {
    throw const FormatException('草稿超过4MiB');
  }
  final file = File(request.$1);
  file.parent.createSync(recursive: true);
  final pending = File('${file.path}.pending');
  pending.writeAsBytesSync(bytes, flush: true);
  pending.renameSync(file.path);
}

/// 递归复制JSON[value]，防止保存期间正文可变属性继续变化；不复制编辑器或宿主服务。
Object? _copyJson(Object? value) {
  if (value is Map) {
    return value.map((key, child) => MapEntry(key as String, _copyJson(child)));
  }
  if (value is List) return value.map(_copyJson).toList();
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw const FormatException('正文包含非JSON值');
}

/// 宿主拥有的单文档会话，管理500ms自动保存、串行写入和编辑器释放。
///
/// ```dart
/// import 'dart:io';
/// import 'package:cses_editor/cses_editor.dart';
/// import 'package:cses_editor_host_sample/offline_document.dart';
/// final session = await OfflineDocumentSession.open(
///   OfflineDocumentStore(Directory('/app/private'), 'u1', 'd1'),
///   const CollabHostServices(), (error, stack) => print(error),
/// );
/// // DocumentEditorView借用session.editor.editorState。
/// // 先移除视图、等待路由完全退场，再释放：
/// await session.close();
/// ```
final class OfflineDocumentSession {
  /// 接管[editor]及[store]；[onSaveError]接收自动保存失败，资源仍由宿主拥有。
  OfflineDocumentSession._(this.editor, this.store, this.onSaveError) {
    editor.addListener(_changed);
  }

  /// 拥有的内存编辑会话；消费者只借用，不单独dispose其editorState。
  final DocumentEditorController editor;

  /// 本会话独占写入的存储，跨账号或文档切换时创建新实例。
  final OfflineDocumentStore store;

  /// 自动保存失败回调；脏状态保留，可用flush重试，回调不得抛错。
  final void Function(Object error, StackTrace stack) onSaveError;

  /// 本会话拥有的保存错误通知器；视图借用，关闭后不得继续监听。
  final saveError = ValueNotifier<String?>(null);
  Timer? _timer;
  Future<void>? _saving;
  Future<void>? _closing;
  bool _dirty = false;

  /// 从[store]恢复完整正文或新建空白；[services]只借用，释放责任属于宿主。
  /// [onSaveError]接收后台自动保存失败。加载或构造失败直接抛错，不覆盖原文件。
  static Future<OfflineDocumentSession> open(
    OfflineDocumentStore store,
    CollabHostServices services,
    void Function(Object error, StackTrace stack) onSaveError,
  ) async {
    final json = await store.read();
    final editor = DocumentEditorController(
      document: json == null ? null : Document.fromJson(json),
      commandContext: EditorCommandContext(
        configuration: EditorConfiguration.local,
        localOnly: true,
        services: services,
      ),
    );
    return OfflineDocumentSession._(editor, store, onSaveError);
  }

  /// 记录已完成的本地事务并重置本会话拥有的去抖定时器。
  void _changed() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () {
      unawaited(saveInBackground());
    });
  }

  /// 等待保存且明确报告失败；生命周期回调可以不等待本方法。
  Future<void> saveInBackground() async {
    try {
      await flush();
    } catch (error, stack) {
      if (!editor.closed) saveError.value = error.toString();
      onSaveError(error, stack);
    }
  }

  /// 等待所有当前编辑写入；写入期间的新修订继续串行保存，失败抛错并保留脏状态。
  Future<void> flush() async {
    _timer?.cancel();
    final active = _saving;
    if (active != null) {
      await active;
      return flush();
    }
    final task = _writeUntilClean();
    _saving = task;
    try {
      await task;
      if (!editor.closed) saveError.value = null;
    } finally {
      _saving = null;
    }
  }

  /// 逐份保存独立快照；仅在对应修订仍是最新时清除脏状态。
  Future<void> _writeUntilClean() async {
    while (_dirty) {
      final revision = editor.revision;
      final document =
          _copyJson(editor.editorState.document.toJson())
              as Map<String, dynamic>;
      await store.write(document);
      if (revision == editor.revision) _dirty = false;
    }
  }

  /// 视图和宿主选择路由完全卸载后调用；等待最终保存，再释放编辑器，重复调用共享结果。
  /// 最终保存失败仍释放资源并向调用者抛错；正常退出应先flush成功才允许关闭页面。
  Future<void> close() => _closing ??= _close();

  /// 停止本会话拥有的监听/定时器，串行完成保存及释放，不关闭宿主网络资源。
  Future<void> _close() async {
    editor.removeListener(_changed);
    _timer?.cancel();
    try {
      await flush();
    } finally {
      await editor.close();
      saveError.dispose();
    }
  }
}
