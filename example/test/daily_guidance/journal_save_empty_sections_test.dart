import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/body_content_codec.dart';
import 'package:cses_offline_example/daily_guidance/empty_guidance_record.dart';
import 'package:cses_offline_example/daily_guidance/guidance_api.dart';
import 'package:cses_offline_example/daily_guidance/guidance_entries.dart';
import 'package:cses_offline_example/daily_guidance/guidance_record_fields.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_share_page.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_controller.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 创建借用文字 [text] 的 [kind] 栏目；自定义栏目保留稳定标签，不持有资源。
Node _section(String kind, String text) => Node(
  type: journalSectionType,
  attributes: {
    'section': kind,
    if (kind.startsWith('custom:')) 'guidance_section_label': kind,
  },
  children: [paragraphNode(text: text)],
);

/// 按 [type] 创建既有协议记录，包含空感悟、自检和自定义栏目及一个有值栏目。
Map<String, dynamic> _record({String type = 'ORIENT'}) {
  final record = createEmptyGuidanceRecord(
    DateTime(2026, 11, 5),
    orientType: type,
  );
  final draft = BodyContentCodec.decode(
    record['bodyContent'] as Map<String, dynamic>,
  );
  final document = Document.fromJson(
    jsonDecode(draft.documentJson) as Map<String, dynamic>,
  );
  try {
    document.root.insert(_section('reflection', ' \n\t'));
    document.root.insert(_section('self-check', ''));
    document.root.insert(_section('custom:empty', '　'));
    document.root.insert(_section('custom:filled', '保留的值'));
    final snapshot = JournalDraft.fromJson({
      ...draft.toJson(),
      'document': document.toJson(),
    });
    final body = BodyContentCodec.encode(snapshot);
    return {
      ...record,
      'bodyContent': body,
      ...GuidanceRecordFields.extract(body, orientType: type),
    };
  } finally {
    document.dispose();
  }
}

/// 测试拥有的无网络接口，可模拟保存失败，保留最后成功的后台记录。
class _Api implements GuidanceApi {
  /// 以 [type] 创建测试记录，后台由本实例拥有。
  _Api({String type = 'ORIENT'})
    : backend = MockGuidanceApi(
        record: _record(type: type),
        latency: Duration.zero,
      );

  /// 测试独占的无延迟后台。
  final MockGuidanceApi backend;

  /// 模拟请求失败，不覆盖后台。
  bool fail = false;

  /// 实际提交次数。
  int writes = 0;

  /// 读取借用的 [recordId] 对应记录。
  @override
  Future<Map<String, dynamic>> fetch(String recordId) =>
      backend.fetch(recordId);

  /// 保存 [recordId] 的 [record]，失败时不修改后台。
  @override
  Future<void> save(String recordId, Map<String, dynamic> record) async {
    writes++;
    if (fail) throw StateError('测试保存失败');
    await backend.save(recordId, record);
  }
}

/// 返回借用 [state] 的可见栏目，不读取隐藏草稿。
List<String> _keys(EditorState state) => [
  for (final node in state.document.root.children)
    node.attributes['section'] as String,
];

/// 借用 [tester] 中当前页面的编辑器状态。
EditorState _state(WidgetTester tester) =>
    tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;

/// 用借用的 [api] 在 [tester] 中挂载真实路由；返回稳定身份存储供断言后台结果。
Future<ApiJournalStore> _open(
  WidgetTester tester,
  _Api api, {
  String type = 'ORIENT',
}) async {
  final store = ApiJournalStore(
    api: api,
    recordId: _record(type: type)['id'] as String,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => LocalJournalPage(store: store)),
          ),
          child: const Text('打开'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
  return store;
}

/// 验证空栏目在显式保存关闭，非空与业务内容保留，关闭可撤销且结果可重开。
void main() {
  test(
    'empty cleanup is one undoable command and keeps tasks, mentions and business rows',
    () async {
      final api = _Api();
      final store = ApiJournalStore(
        api: api,
        recordId: _record()['id'] as String,
      );
      final journal = await LocalJournalController.open(
        store: store,
        autoSave: false,
      );
      final state = journal.editor.editorState;
      try {
        final selfCheck = state.document.root.children.singleWhere(
          (node) => node.attributes['section'] == 'self-check',
        );
        await state.apply(
          state.transaction
            ..insertNode([...selfCheck.path, 1], todoListNode(checked: false)),
        );
        await journal.addCustomSection('提及');
        final mention = state.document.root.children.last.children.single;
        await state.apply(
          state.transaction..updateNode(mention, {
            blockComponentDelta: EditorUserMention.createDelta(
              const CollabMentionUser(id: 'u1', name: '小林'),
            ).toJson(),
          }),
        );
        await journal.addCustomSection('业务空行');
        final business = state.document.root.children.last.children.single;
        await state.apply(
          state.transaction..updateNode(business, {
            guidanceEntryAttribute: 'pilot',
            'guidance_entry_id': 'pilot-1',
            'guidance_done': false,
          }),
        );
        final before = _keys(state);
        await journal.closeEmptySections();
        expect(_keys(state), isNot(contains('reflection')));
        expect(_keys(state), isNot(contains('custom:empty')));
        expect(
          _keys(state),
          containsAll([
            'record',
            'self-check',
            'custom:filled',
            before[before.length - 2],
            before.last,
          ]),
        );
        state.undoManager.undo();
        expect(_keys(state), before);
        state.undoManager.redo();
        expect(_keys(state), isNot(contains('reflection')));
        expect(await journal.flush(), isTrue);
        final reopened = await LocalJournalController.open(
          store: store,
          readOnly: true,
        );
        try {
          expect(_keys(reopened.editor.editorState), _keys(state));
          await reopened.closeEmptySections();
          expect(_keys(reopened.editor.editorState), _keys(state));
        } finally {
          await reopened.close();
        }
      } finally {
        await journal.close();
      }
    },
  );

  testWidgets(
    'save closes blank optional fields in preview, share and reopened document',
    (tester) async {
      final api = _Api();
      final store = await _open(tester, api);
      expect(_keys(_state(tester)), contains('reflection'));
      await tester.tap(find.byKey(const ValueKey('journal-save')));
      await tester.pumpAndSettle();
      expect(_state(tester).editable, isFalse);
      expect(_keys(_state(tester)), ['record', 'custom:filled']);
      final submitted = await api.fetch(store.recordId);
      expect(
        submitted['bodyContent']['meta']['mobileGuidanceView']['hiddenSections'],
        containsAll(['reflection', 'self-check', 'custom:empty']),
      );
      expect(submitted['thinking'], {'content': '', 'mentions': []});
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journal-share')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final share = tester.widget<JournalSharePage>(
        find.byType(JournalSharePage),
      );
      final shared = Document.fromJson(share.document);
      expect(
        [
          for (final section in shared.root.children)
            section.attributes['section'],
        ],
        ['record', 'custom:filled'],
      );
      shared.dispose();
      for (
        var i = 0;
        i < 80 &&
            find
                .byKey(const ValueKey('journal-share-image'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('journal-share-image')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('journal-share-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journal-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(_keys(_state(tester)), ['record', 'custom:filled']);
      expect(api.writes, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed save keeps values editable and cleanup undoable before retry',
    (tester) async {
      final api = _Api()..fail = true;
      await _open(tester, api);
      final state = _state(tester);
      await tester.tap(find.byKey(const ValueKey('journal-save')));
      await tester.pumpAndSettle();
      expect(state.editable, isTrue);
      expect(find.byKey(const ValueKey('journal-retry-save')), findsOneWidget);
      expect(
        state.document.root.children.last.children.single.delta!.toPlainText(),
        '保留的值',
      );
      state.undoManager.undo();
      await tester.pumpAndSettle();
      expect(
        _keys(state),
        containsAll(['reflection', 'self-check', 'custom:empty']),
      );
      api.fail = false;
      await tester.tap(find.byKey(const ValueKey('journal-retry-save')));
      await tester.pumpAndSettle();
      expect(_keys(state), ['record', 'custom:filled']);
      expect(state.editable, isFalse);
      expect(api.writes, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('save before leaving also closes blank fields for RESULT', (
    tester,
  ) async {
    final api = _Api(type: 'RESULT');
    final store = await _open(tester, api, type: 'RESULT');
    final state = _state(tester);
    await state.apply(
      state.transaction..insertText(state.getNodeAtPath([0, 0])!, 0, '成果'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存后离开'));
    await tester.pumpAndSettle();
    expect(find.byType(LocalJournalPage), findsNothing);
    final reopened = await store.read();
    final document = Document.fromJson(
      jsonDecode(reopened.documentJson) as Map<String, dynamic>,
    );
    expect(
      [
        for (final section in document.root.children)
          section.attributes['section'],
      ],
      ['record', 'custom:filled'],
    );
    document.dispose();
    expect(api.writes, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
