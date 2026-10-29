import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/daily_guidance/body_content_codec.dart';
import 'package:cses_offline_example/daily_guidance/guidance_api.dart';
import 'package:cses_offline_example/daily_guidance/guidance_entries.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_controller.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:cses_offline_example/daily_guidance/guidance_people.dart';
import 'package:cses_offline_example/daily_guidance/journal_ruled_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// 加载宿主原始接口样例，每次返回独立对象，不修改用户文件。
Map<String, dynamic> _record() =>
    jsonDecode(File('文档完整数据结构.json').readAsStringSync())
        as Map<String, dynamic>;

/// 测试拥有的可失败及可延迟服务，无网络资源。
class _Api implements GuidanceApi {
  /// 以独立 [record] 初始化后台数据。
  _Api(Map<String, dynamic> record)
    : backend = MockGuidanceApi(record: record, latency: Duration.zero);

  /// 独立 mock 后台。
  final MockGuidanceApi backend;

  /// 模拟获取挂起。
  Completer<Map<String, dynamic>>? pendingRead;

  /// 模拟保存挂起。
  Completer<void>? pendingSave;

  /// 模拟获取失败。
  bool failRead = false;

  /// 模拟保存失败。
  bool failSave = false;

  /// 保存调用次数。
  int writes = 0;

  /// 最近捕获的请求补丁。
  Map<String, dynamic>? submitted;

  /// 获取 [recordId] 的独立记录或等待测试响应。
  @override
  Future<Map<String, dynamic>> fetch(String recordId) async {
    if (failRead) throw StateError('fetch failed');
    return pendingRead?.future ?? backend.fetch(recordId);
  }

  /// 捕获 [recordId] 的 [patch]；失败不覆盖后台旧值。
  @override
  Future<void> save(String recordId, Map<String, dynamic> patch) async {
    writes++;
    submitted = jsonDecode(jsonEncode(patch)) as Map<String, dynamic>;
    await pendingSave?.future;
    if (failSave) throw StateError('save failed');
    await backend.save(recordId, patch);
  }
}

/// 从 [tester] 借用当前编辑状态。
EditorState _state(WidgetTester tester) =>
    tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;

/// 修改 [state] 的首段，插入 [text] 并触发真实事务监听。
Future<void> _insert(EditorState state, String text) => state.apply(
  state.transaction..insertText(state.getNodeAtPath([0, 0])!, 0, text),
);

/// 在 [tester] 中点击 [key] 并等待帧及异步请求完成。
Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// 将 [tester] 中的原生工具栏滚动到 [key]，随后点击实际可达按钮。
Future<void> _toolbar(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  final list = find.descendant(
    of: find.byKey(const ValueKey('editor-mobile-toolbar')),
    matching: find.byType(ListView),
  );
  for (var i = 0; i < 15 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(-130, 0));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// 可选地捕获 [tester] 中由 [key] 标识的页面，输出固定 [name] PNG。
Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('SAVE_BODY_API_SCREENSHOTS')) return;
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '../docs/verification/body-content-api-20261029/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

/// 验证 moke 正文映射、无损往返、原有菜单、标题和显式提交边界。
void main() {
  test(
    'bodyContent projects to existing journal sections and round trips exactly',
    () {
      final original = _record()['bodyContent'] as Map<String, dynamic>;
      final draft = BodyContentCodec.decode(original);
      final document = Document.fromJson(
        jsonDecode(draft.documentJson) as Map<String, dynamic>,
      );
      try {
        expect(
          document.root.children.map(
            (section) => section.attributes['section'],
          ),
          [
            'record',
            'reflection',
            'self-check',
            'custom:local_KYlqAwkdYUsE_BTzfk',
          ],
        );
        expect(document.root.attributes['guidance_desktop_import'], isNull);
        expect(
          journalEditorConfiguration(document).keyboardToolbarItems,
          journalConfiguration.keyboardToolbarItems,
        );
        expect(
          journalContentNodes(
            document.root.children,
          ).where((node) => node.attributes[guidanceEntryAttribute] == 'help'),
          hasLength(2),
        );
        expect(jsonEncode(document.toJson()), contains('cses_mention_type'));
        expect(BodyContentCodec.encode(draft), original);
        final future = <String, dynamic>{
          ...original,
          'meta': {
            ...(original['meta'] as Map),
            'mobileGuidanceView': {'futureSetting': true},
          },
        };
        expect(
          BodyContentCodec.encode(BodyContentCodec.decode(future)),
          future,
        );
      } finally {
        document.dispose();
      }
    },
  );

  test(
    'live edits, menus, date and custom fields save in original body format',
    () async {
      final original = _record();
      final api = _Api(original);
      final store = ApiJournalStore(
        api: api,
        recordId: original['id'] as String,
      );
      final journal = await LocalJournalController.open(
        store: store,
        autoSave: false,
      );
      try {
        final state = journal.editor.editorState;
        await _insert(state, '保存编辑 ');
        final custom = state.document.root.children.last.children.first;
        await state.apply(state.transaction..insertText(custom, 0, '2'));
        final target = journal.captureInsertionTarget()!;
        await journal.insertPeople(target, [
          const GuidancePerson(id: 'new-user', name: '新成员'),
        ], kind: 'pilot');
        journal.setDate('2026-10-30');
        expect(await journal.flush(), isTrue);
        expect(api.submitted!.keys, ['bodyContent']);
        final saved = await api.fetch(original['id'] as String);
        for (final entry in original.entries.where(
          (entry) => entry.key != 'bodyContent',
        )) {
          expect(saved[entry.key], entry.value);
        }
        final body = saved['bodyContent'] as Map<String, dynamic>;
        expect(jsonEncode(body), isNot(contains('guidance_body_template')));
        expect(jsonEncode(body), isNot(contains('guidance_body_region')));
        expect(jsonEncode(body), contains('保存编辑'));
        expect(jsonEncode(body), contains('"dailyTag":"pilot"'));
        expect(jsonEncode(body), contains('"mentionType":"task"'));
        expect(jsonEncode(body), contains('211111'));
        expect((body['meta'] as Map)['dailyDate'], '2026-10-30');
        expect(jsonEncode(body), contains('2026-10-30T12:00:00'));
        expect(body['props'], (original['bodyContent'] as Map)['props']);
        final reopened = await LocalJournalController.open(
          store: store,
          autoSave: false,
        );
        expect(
          jsonEncode(reopened.editor.editorState.document.toJson()),
          contains('保存编辑'),
        );
        expect(reopened.date, '2026-10-30');
        await reopened.close();
      } finally {
        await journal.close();
      }
    },
  );

  test(
    'close and reopen retain hidden content and allow restoring the same section',
    () async {
      final original = _record();
      final api = _Api(original);
      final store = ApiJournalStore(
        api: api,
        recordId: original['id'] as String,
      );
      final journal = await LocalJournalController.open(
        store: store,
        autoSave: false,
      );
      await journal.closeSection('reflection');
      expect(journal.hasSection('reflection'), isFalse);
      expect(await journal.flush(), isTrue);
      await journal.close();
      final reopened = await LocalJournalController.open(
        store: store,
        autoSave: false,
      );
      expect(reopened.hasSection('reflection'), isFalse);
      await reopened.addSection('reflection');
      expect(reopened.hasSection('reflection'), isTrue);
      expect(
        jsonEncode(reopened.editor.editorState.document.toJson()),
        contains('XSNJKJCDSJJCKLJCDSKLDC,MN'),
      );
      await reopened.close();
    },
  );

  for (final orient in ['ORIENT', 'RESULT']) {
    testWidgets(
      '$orient uses existing notebook and submits only bodyContent on save',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final record = _record()..['orientType'] = orient;
        final api = _Api(record);
        await tester.pumpWidget(
          MaterialApp(
            home: LocalJournalPage(
              store: ApiJournalStore(
                api: api,
                recordId: record['id'] as String,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(orient == 'RESULT' ? '今日成果' : '今日导向'),
          findsNWidgets(2),
        );
        expect(find.byKey(const ValueKey('journal-json-menu')), findsNothing);
        expect(
          find.byKey(const ValueKey('journal-cover-image')),
          findsOneWidget,
        );
        expect(find.byType(JournalRuledContent), findsWidgets);
        expect(find.text('感悟'), findsOneWidget);
        expect(find.text('自检'), findsOneWidget);
        expect(find.text('金额'), findsOneWidget);
        await _insert(_state(tester), '实时正文');
        await tester.pump(const Duration(seconds: 2));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(api.writes, 0);
        api.failSave = true;
        await _tap(tester, 'journal-save');
        expect(api.writes, 1);
        expect(
          find.byKey(const ValueKey('journal-retry-save')),
          findsOneWidget,
        );
        expect(
          _state(tester).getNodeAtPath([0, 0])!.delta!.toPlainText(),
          startsWith('实时正文'),
        );
        api.failSave = false;
        await _tap(tester, 'journal-retry-save');
        expect(api.submitted!.keys, ['bodyContent']);
        expect(jsonEncode(api.submitted), contains('实时正文'));
        await _insert(_state(tester), '未提交');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(api.writes, 2);
        expect(
          jsonEncode(await api.fetch(record['id'] as String)),
          isNot(contains('未提交')),
        );
      },
    );
  }

  testWidgets('late fetch never mounts content after identity change', (
    tester,
  ) async {
    final record = _record();
    final api = _Api(record)..pendingRead = Completer<Map<String, dynamic>>();
    var identity = 'a';
    await tester.pumpWidget(
      MaterialApp(
        home: LocalJournalPage(
          store: ApiJournalStore(api: api, recordId: record['id'] as String),
          sessionIdentity: () => identity,
        ),
      ),
    );
    await tester.pump();
    identity = 'b';
    api.pendingRead!.complete(record);
    await tester.pumpAndSettle();
    expect(find.byType(AppFlowyEditor), findsNothing);
    expect(api.writes, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  test('native Enter and undo retain unique backend identities', () async {
    final record = _record();
    final store = ApiJournalStore(
      api: _Api(record),
      recordId: record['id'] as String,
    );
    final journal = await LocalJournalController.open(
      store: store,
      autoSave: false,
    );
    final state = journal.editor.editorState;
    try {
      state.selection = Selection.collapsed(Position(path: [0, 0], offset: 3));
      expect(await handleDocumentParagraphEnter(state), isTrue);
      expect(await journal.flush(), isTrue);
      final saved = BodyContentCodec.encode(await store.read());
      final ids = <Object>{};

      /// 检查借用的 [block] 全树身份唯一，包含模板锁定节点及日期。
      void visit(Map block) {
        expect(ids.add(block['id']), isTrue);
        if (block['nodeType'] != 'editable') {
          for (final child in block['children'] as List) {
            visit(child as Map);
          }
        }
      }

      visit(saved);
      state.undoManager.undo();
      expect(await journal.flush(), isTrue);
    } finally {
      await journal.close();
    }
  });

  test(
    'invalid bodies and mismatched record types are rejected without mutation',
    () async {
      final record = _record();
      final body = record['bodyContent'] as Map<String, dynamic>;
      final original = jsonEncode(body);
      final bad = jsonDecode(original) as Map<String, dynamic>;
      (((bad['children'] as List).first as Map)['children'] as List).add({
        'id': 'bad-tag',
        'flavour': 'paragraph',
        'nodeType': 'editable',
        'props': {},
        'meta': {},
        'children': [
          {
            'insert': {'dailyTag': 'invalid'},
          },
        ],
      });
      expect(() => BodyContentCodec.decode(bad), throwsFormatException);
      expect(jsonEncode(body), original);
      final invalid = {...record, 'orientType': 'UNKNOWN'};
      final store = ApiJournalStore(
        api: _Api(invalid),
        recordId: record['id'] as String,
      );
      await expectLater(store.read(), throwsFormatException);
    },
  );

  testWidgets(
    'fetch failure retries without replacing data with a blank journal',
    (tester) async {
      final record = _record();
      final api = _Api(record)..failRead = true;
      await tester.pumpWidget(
        MaterialApp(
          home: LocalJournalPage(
            store: ApiJournalStore(api: api, recordId: record['id'] as String),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppFlowyEditor), findsNothing);
      expect(api.writes, 0);
      api.failRead = false;
      await tester.tap(find.text('重试读取'));
      await tester.pumpAndSettle();
      expect(find.byType(AppFlowyEditor), findsOneWidget);
      expect(
        _state(tester).getNodeAtPath([0, 0])!.delta!.toPlainText(),
        contains('KJDCJODCJDCK'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('late save completion cannot acknowledge another host session', (
    tester,
  ) async {
    final record = _record();
    final api = _Api(record)..pendingSave = Completer<void>();
    var identity = 'first';
    await tester.pumpWidget(
      MaterialApp(
        home: LocalJournalPage(
          store: ApiJournalStore(api: api, recordId: record['id'] as String),
          sessionIdentity: () => identity,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _insert(_state(tester), '原记录提交');
    await tester.tap(find.byKey(const ValueKey('journal-save')));
    await tester.pump();
    await tester.pump();
    identity = 'second';
    await tester.pump(const Duration(milliseconds: 250));
    api.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(api.writes, 1);
    expect(find.text('宿主会话已变化，请关闭后重新打开'), findsOneWidget);
    expect(find.text('已保存到后台'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'API document retains native keyboard menus and custom people actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const screenshot = bool.fromEnvironment('SAVE_BODY_API_SCREENSHOTS');
      if (screenshot) {
        await tester.runAsync(() async {
          final bytes = await File(
            '/System/Library/Fonts/STHeiti Medium.ttc',
          ).readAsBytes();
          for (final name in ['Ahem', 'Roboto', 'PaperPreview']) {
            await ui.loadFontFromList(bytes, fontFamily: name);
          }
          await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
                rootBundle.load(
                  'packages/lucide_icons_flutter/assets/lucide.ttf',
                ),
              ))
              .load();
        });
      }
      final capture = GlobalKey();
      final record = _record();
      final api = _Api(record);
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: screenshot ? 'PaperPreview' : null,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff8b6e63),
              ),
              useMaterial3: true,
            ),
            home: LocalJournalPage(
              store: ApiJournalStore(
                api: api,
                recordId: record['id'] as String,
              ),
              hostServices: CollabHostServices(
                pickMentionUser:
                    (context, {required keyword, required canEdit}) async =>
                        const CollabMentionUser(
                          id: 'keyboard-user',
                          name: '菜单同事',
                        ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (screenshot) {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/daily_guidance_mountain.png'),
            tester.element(find.byType(AppFlowyEditor)),
          ),
        );
      }
      await _capture(tester, capture, 'api-paper');
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final state = _state(tester);
      state.selection = Selection.collapsed(Position(path: [0, 0]));
      await tester.pumpAndSettle();
      for (final kind in ['pilot', 'help']) {
        state.selection = Selection.collapsed(Position(path: [0, 0]));
        await tester.pumpAndSettle();
        await _toolbar(tester, 'editor-keyboard-host-guidance-action-$kind');
        expect(
          state.document.root.children.first.children.any(
            (node) =>
                node.attributes[guidanceEntryAttribute] == kind &&
                node.delta!.toPlainText().contains('\uFFFC'),
          ),
          isTrue,
        );
      }
      await _capture(tester, capture, 'api-keyboard');
      state.selection = Selection.collapsed(Position(path: [0, 0]));
      await tester.pumpAndSettle();
      final list = find.descendant(
        of: find.byKey(const ValueKey('editor-mobile-toolbar')),
        matching: find.byType(ListView),
      );
      await tester.drag(list, const Offset(1500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('块类型'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('editor-block-style-menu')),
        findsOneWidget,
      );
      await _capture(tester, capture, 'api-block-menu');
      await tester.tap(find.byKey(const ValueKey('editor-block-heading-1')));
      await tester.pumpAndSettle();
      expect(state.getNodeAtPath([0, 0])!.type, HeadingBlockKeys.type);
      await tester.tap(find.byKey(const ValueKey('journal-save')));
      await tester.pumpAndSettle();
      final saved = api.submitted!['bodyContent'] as Map;
      final cover = (saved['children'] as List).first as Map;
      expect(((cover['children'] as List)[1] as Map)['props']['heading'], 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
