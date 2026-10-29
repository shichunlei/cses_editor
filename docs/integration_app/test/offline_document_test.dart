import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_editor_host_sample/main.dart';
import 'package:cses_editor_host_sample/offline_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// 收集宿主借用的[session]正文，验证完整JSON恢复而非只恢复纯文本。
String _text(OfflineDocumentSession session) => session
    .editor
    .editorState
    .document
    .root
    .children
    .map((node) => node.delta?.toPlainText())
    .join('\n');

/// 对[session]的首个段落追加[value]，等待真实编辑事务完成。
Future<void> _append(OfflineDocumentSession session, String value) async {
  final state = session.editor.editorState;
  final node = state.document.root.children.first;
  await state.apply(
    state.transaction..insertText(node, node.delta!.length, value),
    skipHistoryDebounce: true,
  );
}

/// 为[tester]交替推进真实文件Isolate和Flutter帧，直到[condition]成立；超时保留明确断言。
Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 60; i++) {
    await tester.pumpAndSettle();
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  expect(condition(), isTrue, reason: '等待宿主路由或文件操作完成');
}

/// 测试私有目录提供器，不访问设备或其他应用文件。
class _TestPaths extends PathProviderPlatform {
  /// [path]为单项测试拥有的临时目录。
  _TestPaths(this.path);
  final String path;

  /// 返回当前测试持有的目录，不创建平台资源。
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

/// 验证接入模板的加载、并发保存、失败保留和生命周期，不调用示例业务或原生协同。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cses-host-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('save restores rich formatting and isolates scope/document', () async {
    final store = OfflineDocumentStore(directory, 'tenant-a/user-1', 'doc-1');
    final session = await OfflineDocumentSession.open(
      store,
      const CollabHostServices(),
      (error, stack) => fail('$error'),
    );
    await _append(session, '宿主离线正文');
    final state = session.editor.editorState;
    final node = state.document.root.children.first;
    await state.apply(
      state.transaction..formatText(node, 0, 2, {'bold': true}),
    );
    await session.flush();
    await session.close();
    await session.close();
    expect(session.editor.closed, isTrue);

    final restored = await OfflineDocumentSession.open(
      store,
      const CollabHostServices(),
      (error, stack) => fail('$error'),
    );
    expect(_text(restored), '宿主离线正文');
    expect(
      restored
          .editor
          .editorState
          .document
          .root
          .children
          .first
          .delta!
          .first
          .attributes?['bold'],
      isTrue,
    );
    expect(restored.editor.commandContext.localOnly, isTrue);
    expect(
      await OfflineDocumentStore(directory, 'tenant-b/user-1', 'doc-1').read(),
      isNull,
    );
    expect(
      await OfflineDocumentStore(directory, 'tenant-a/user-1', 'doc-2').read(),
      isNull,
    );
    await restored.close();
  });

  test(
    'edits arriving during save and concurrent flush keep latest revision',
    () async {
      final store = OfflineDocumentStore(directory, 'u1', 'd1');
      final session = await OfflineDocumentSession.open(
        store,
        const CollabHostServices(),
        (error, stack) => fail('$error'),
      );
      await _append(session, '第一版');
      final first = session.flush();
      await _append(session, '追加第二版');
      await Future.wait([first, session.flush(), session.flush()]);
      await session.close();
      final restored = await OfflineDocumentSession.open(
        store,
        const CollabHostServices(),
        (error, stack) => fail('$error'),
      );
      expect(_text(restored), '第一版追加第二版');
      await restored.close();
    },
  );

  test(
    'corrupt or unknown data is preserved and blocks empty replacement',
    () async {
      final store = OfflineDocumentStore(directory, 'u1', 'd1');
      final file = File(store.path);
      for (final content in [
        'broken-json',
        jsonEncode({'schemaVersion': 99}),
      ]) {
        await file.writeAsString(content);
        await expectLater(
          OfflineDocumentSession.open(
            store,
            const CollabHostServices(),
            (error, stack) {},
          ),
          throwsFormatException,
        );
        expect(await file.readAsString(), content);
      }
    },
  );

  test(
    'save failure reports error and can retry without losing memory',
    () async {
      final blocker = File('${directory.path}/blocked');
      await blocker.writeAsString('not-a-directory');
      final store = OfflineDocumentStore(Directory(blocker.path), 'u1', 'd1');
      Object? reported;
      // 缺失的子文件按不存在处理；阻塞目录在初始化之后创建以触发写入失败。
      await blocker.delete();
      final session = await OfflineDocumentSession.open(
        store,
        const CollabHostServices(),
        (error, stack) => reported = error,
      );
      await blocker.writeAsString('not-a-directory');
      await _append(session, '失败后仍保留');
      await session.saveInBackground();
      expect(reported, isNotNull);
      expect(session.saveError.value, isNotNull);
      expect(_text(session), '失败后仍保留');
      await blocker.delete();
      await session.flush();
      expect(session.saveError.value, isNull);
      expect(await store.read(), isNotNull);
      await session.close();
    },
  );

  testWidgets(
    'host saves on system back, releases route, and reopens document',
    (tester) async {
      final paths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TestPaths(directory.path);
      addTearDown(() => PathProviderPlatform.instance = paths);
      await tester.pumpWidget(const HostApp());
      await tester.tap(find.text('打开离线文档'));
      await _waitFor(
        tester,
        () => find.byType(DocumentEditorView).evaluate().isNotEmpty,
      );
      expect(find.byType(DocumentEditorView), findsOneWidget);
      final state = tester
          .widget<DocumentEditorView>(find.byType(DocumentEditorView))
          .editorState;
      final node = state.document.root.children.first;
      await state.apply(state.transaction..insertText(node, 0, '路由保存恢复'));
      // 系统返回先被PopScope拦截，等待保存后由页面退出。
      await tester.binding.handlePopRoute();
      await _waitFor(
        tester,
        () =>
            state.isDisposed &&
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed !=
                null,
      );
      expect(find.byType(DocumentEditorView), findsNothing);
      await tester.tap(find.text('打开离线文档'));
      await _waitFor(
        tester,
        () => find.byType(DocumentEditorView).evaluate().isNotEmpty,
      );
      final restored = tester
          .widget<DocumentEditorView>(find.byType(DocumentEditorView))
          .editorState;
      expect(
        restored.document.root.children.first.delta!.toPlainText(),
        '路由保存恢复',
      );
      await tester.tap(find.byIcon(Icons.arrow_back));
      await _waitFor(tester, () => restored.isDisposed);
      expect(find.byType(DocumentEditorView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('host initializes editor localization without example app', (
    tester,
  ) async {
    await tester.pumpWidget(const HostApp());
    await tester.pumpAndSettle();
    expect(find.text('打开离线文档'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
