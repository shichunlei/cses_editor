import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/guidance_entries.dart';
import 'package:cses_offline_example/daily_guidance/guidance_people.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_ruled_content.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/journal_surface.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 原生提及回归专用内存存储，使用JSON往返模拟文件恢复而不接触用户草稿。
final class _Store implements JournalStore {
  /// 已保存的独立快照，null表示首次创建。
  JournalDraft? value;

  /// 返回可恢复的已保存内容。
  @override
  Future<JournalDraft?> read() async => value;

  /// 对[draft]执行JSON往返，拒绝保存非法对象并隔离可变正文。
  @override
  Future<void> write(JournalDraft draft) async =>
      value = JournalDraft.fromJson(draft.toJson());
}

/// 虚构用户的原生投影快照，不使用真实企业资料或认证数据。
const _native = <String, dynamic>{
  'cses_inline_mention': '原生用户',
  'cses_mention_id': 'native-user',
  'cses_mention_attributes': '{"mentionType":"user","mentionId":"native-user"}',
};

/// 为[store]创建可独立关闭的日记会话；[services]为可选本实例提及服务。
Future<LocalJournalController> _open(
  _Store store, {
  CollabHostServices? services,
}) => LocalJournalController.open(
  store: store,
  now: DateTime(2026, 10, 22),
  saveDelay: const Duration(days: 1),
  services: services,
);

/// 向[journal]的今日记录插入原生用户对象及尾部空格；[bold]控制对象基础格式。
Future<Node> _insert(
  LocalJournalController journal, {
  bool bold = false,
}) async {
  final state = journal.editor.editorState;
  final node = state.getNodeAtPath([0, 0])!;
  state.selection = Selection.collapsed(Position(path: node.path));
  await state.apply(
    state.transaction..insertTextDelta(
      node,
      0,
      Delta()
        ..insert('\uFFFC', attributes: {..._native, if (bold) 'bold': true})
        ..insert(' '),
    ),
    skipHistoryDebounce: true,
  );
  return node;
}

/// 在[tester]挂载[journal]的生产正文视图；[preview]关闭输入但保留原生对象渲染。
/// [scale]为系统字号倍率，默认1，用于验证对象与正文仅缩放一次。
Future<void> _mount(
  WidgetTester tester,
  LocalJournalController journal, {
  bool preview = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: JournalSurface(
          editorState: journal.editor.editorState,
          preview: preview,
          header: const SizedBox(),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 卸载[tester]中的视图后等待[journal]资源关闭和最新快照保存。
Future<void> _unmount(
  WidgetTester tester,
  LocalJournalController journal,
) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  await tester.runAsync(journal.close);
}

/// 从[tester]读取生产键盘服务，直接提交平台文字增量而不替代模型内容。
KeyboardServiceWidgetState _keyboard(WidgetTester tester) => tester
    .state<KeyboardServiceWidgetState>(find.byType(KeyboardServiceWidget));

/// 验证原生用户身份在日记输入、历史、剪贴板、草稿恢复和预览中的完整链路。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scale in [1.0, 2.0]) {
    for (final kind in ['plain', 'legacy', 'native']) {
      testWidgets('review regression: $kind mention scales once at $scale', (
        tester,
      ) async {
        final journal = await _open(_Store());
        try {
          final delta = switch (kind) {
            'plain' => Delta()..insert('原生用户甲'),
            'legacy' => guidanceMentionDelta([
              const GuidancePerson(id: 'native-user', name: '原生用户'),
            ])..insert('甲'),
            _ =>
              Delta()
                ..insert('\uFFFC', attributes: _native)
                ..insert('甲'),
          };
          final state = journal.editor.editorState;
          await state.apply(
            state.transaction
              ..insertTextDelta(state.getNodeAtPath([0, 0])!, 0, delta),
          );
          await _mount(tester, journal, scale: scale);
          await tester.pumpAndSettle();
          final paragraphs = tester.renderObjectList<RenderParagraph>(
            find.byType(RichText),
          );
          final body = paragraphs.singleWhere(
            (p) => p.text.toPlainText() == delta.toPlainText(),
          );
          expect(body.size.height, closeTo(32 * scale, .1));
          if (kind == 'native') {
            final name = paragraphs.singleWhere(
              (p) => p.text.toPlainText() == '原生用户',
            );
            expect(name.textScaler.scale(16), 16);
            expect(name.getTransformTo(body).getMaxScaleOnAxis(), scale);
          }
          expect(tester.takeException(), isNull);
        } finally {
          await _unmount(tester, journal);
        }
      });
    }
  }
  for (final kind in ['pilot', 'help']) {
    for (final sample in [(1, 1.0), (1, 2.0), (2, 1.0), (2, 2.0)]) {
      final offset = sample.$1;
      final scale = sample.$2;
      testWidgets(
        'mention-only $kind keeps paper row metrics after IME Enter at $sample',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final journal = await _open(_Store());
          final state = journal.editor.editorState;
          state.selection = Selection.collapsed(Position(path: [0, 0]));
          await journal.insertUserEntry(
            journal.captureInsertionTarget()!,
            const CollabMentionUser(id: 'row-user', name: '示例小陈'),
            kind: kind,
          );
          final entry = state.getNodeAtPath([0, 1])!;
          await _mount(tester, journal, scale: scale);
          try {
            await tester.pumpAndSettle();
            final lines = find.byKey(ValueKey('journal-lines-${entry.id}'));
            final before = tester.getRect(lines);
            final rules = tester.renderObject<RenderJournalRules>(lines);
            expect(before.height, closeTo(32 * scale, .1));
            expect(rules.debugLineOffsets.single, closeTo(32 * scale, .1));
            state.selection = Selection.collapsed(
              Position(path: entry.path, offset: offset),
            );
            await tester.pump();
            await _keyboard(tester).textInputService.apply([
              TextEditingDeltaInsertion(
                oldText: ' \uFFFC ',
                textInserted: '\n',
                insertionOffset: offset + 1,
                selection: TextSelection.collapsed(offset: offset + 2),
                composing: TextRange.empty,
              ),
            ]);
            await tester.pumpAndSettle();
            expect(tester.getRect(lines), before);
            expect(rules.debugLineOffsets.single, closeTo(32 * scale, .1));
            expect(
              tester.getRect(find.text('示例小陈')).center.dy,
              closeTo(before.center.dy, .1),
            );
            final next = state.getNodeAtPath([0, 2])!;
            final nextLines = find.byKey(ValueKey('journal-lines-${next.id}'));
            expect(tester.getRect(nextLines).left, before.left);
            expect(tester.getRect(nextLines).width, before.width);
            expect(tester.getRect(nextLines).top, closeTo(before.bottom, .1));
            expect(tester.getRect(nextLines).height, closeTo(32 * scale, .1));
            expect(next.attributes[guidanceEntryAttribute], isNull);
            expect(
              entry.delta!.toPlainText(),
              offset == 1 ? '\uFFFC' : '\uFFFC ',
            );
            state.undoManager.undo();
            await tester.pumpAndSettle();
            expect(state.getNodeAtPath([0, 2]), isNull);
            expect(entry.delta!.toPlainText(), '\uFFFC ');
            state.undoManager.redo();
            await tester.pumpAndSettle();
            expect(tester.getRect(lines), before);
            await _mount(tester, journal, scale: scale, preview: true);
            await tester.pumpAndSettle();
            expect(tester.getRect(lines), before);
            expect(
              tester
                  .renderObject<RenderJournalRules>(lines)
                  .debugLineOffsets
                  .single,
              closeTo(32 * scale, .1),
            );
            expect(tester.takeException(), isNull);
          } finally {
            await _unmount(tester, journal);
          }
        },
      );
    }
  }
  for (final kind in ['pilot', 'help']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('deleting $kind person keeps empty paper row at $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final journal = await _open(_Store());
        final state = journal.editor.editorState;
        state.selection = Selection.collapsed(Position(path: [0, 0]));
        await journal.insertUserEntry(
          journal.captureInsertionTarget()!,
          const CollabMentionUser(id: 'delete-user', name: '待删除用户'),
          kind: kind,
        );
        final entry = state.getNodeAtPath([0, 1])!;
        await _mount(tester, journal, scale: scale);
        try {
          await tester.pumpAndSettle();
          final lines = find.byKey(ValueKey('journal-lines-${entry.id}'));
          final before = tester.getRect(lines);
          for (final end in [1, 2]) {
            state.selection = Selection(
              start: Position(path: entry.path),
              end: Position(path: entry.path, offset: end),
            );
            await tester.pump();
            await _keyboard(tester).textInputService.apply([
              TextEditingDeltaDeletion(
                oldText: ' \uFFFC ',
                deletedRange: TextRange(start: 1, end: end + 1),
                selection: const TextSelection.collapsed(offset: 1),
                composing: TextRange.empty,
              ),
            ]);
            await tester.pumpAndSettle();
            expect(entry.delta!.toPlainText(), end == 1 ? ' ' : '');
            expect(entry.attributes[guidanceEntryAttribute], kind);
            expect(tester.getRect(lines), before);
            expect(
              tester
                  .renderObject<RenderJournalRules>(lines)
                  .debugLineOffsets
                  .single,
              closeTo(32 * scale, .1),
            );
            state.undoManager.undo();
            await tester.pumpAndSettle();
            expect(entry.delta!.toPlainText(), '\uFFFC ');
            expect(tester.getRect(lines), before);
          }
          state.undoManager.redo();
          await tester.pumpAndSettle();
          expect(entry.delta!.isEmpty, isTrue);
          expect(tester.getRect(lines), before);
          await _mount(tester, journal, preview: true, scale: scale);
          await tester.pumpAndSettle();
          expect(tester.getRect(lines), before);
          expect(
            tester
                .renderObject<RenderJournalRules>(lines)
                .debugLineOffsets
                .single,
            closeTo(32 * scale, .1),
          );
          expect(tester.takeException(), isNull);
        } finally {
          await _unmount(tester, journal);
        }
      });
    }
  }
  tearDown(() => AppFlowyClipboard.mockSetData(null));

  test(
    'native and legacy references share clipboard, history and reopen',
    () async {
      final store = _Store();
      var journal = await _open(store);
      try {
        final state = journal.editor.editorState;
        final node = await _insert(journal);
        state.selection = Selection.collapsed(
          Position(path: node.path, offset: node.delta!.length),
        );
        await journal.insertPeople(journal.captureInsertionTarget()!, const [
          GuidancePerson(id: 'legacy-user', name: '旧用户'),
        ], kind: 'help');
        final business = state.document.root.children.single.children.last;
        expect(business.attributes[guidanceEntryAttribute], 'help');
        final selection = Selection(
          start: Position(path: node.path),
          end: Position(path: business.path, offset: business.delta!.length),
        );
        state.selection = selection;
        final original = state.document.root.children.single.children
            .map(
              (node) => {
                'type': node.type,
                'delta': node.delta!.toJson(),
                'entry': node.attributes[guidanceEntryAttribute],
              },
            )
            .toList();
        await journal.copySelection(selection, cut: true);
        expect(AppFlowyClipboard.lastText, '@原生用户 \n@旧用户 ');
        expect(node.delta!.isEmpty, isTrue);
        state.undoManager.undo();
        expect(
          state.document.root.children.single.children
              .map(
                (node) => {
                  'type': node.type,
                  'delta': node.delta!.toJson(),
                  'entry': node.attributes[guidanceEntryAttribute],
                },
              )
              .toList(),
          original,
        );
        validateJournalDocument(state.document);
        expect(await journal.flush(), isTrue);
        await journal.close();
        journal = await _open(store);
        final restored = journal.editor.editorState;
        expect(
          EditorUserMention.read(
            restored.getNodeAtPath([0, 0])!.delta!.first.attributes!,
          ).id,
          'native-user',
        );
        expect(
          restored.getNodeAtPath([0, 1])!.attributes[guidanceEntryAttribute],
          'help',
        );
        restored.selection = Selection.collapsed(
          Position(path: [0, 0], offset: 2),
        );
        AppFlowyClipboard.mockSetData(AppFlowyClipboardData(text: '@可读用户'));
        await journal.pasteFromClipboard();
        expect(
          restored.getNodeAtPath([0, 0])!.delta!.toPlainText(),
          '\uFFFC @可读用户',
        );
        expect(restored.getNodeAtPath([0, 0])!.delta!.last.attributes, isNull);
        validateJournalDocument(restored.document);
      } finally {
        await journal.close();
      }
    },
  );

  test(
    'native malformed, mixed, oversized and non-user objects reject atomically',
    () async {
      final journal = await _open(_Store());
      try {
        final state = journal.editor.editorState;
        final node = state.getNodeAtPath([0, 0])!;
        final before = jsonEncode(state.document.toJson());
        final invalid = [
          {..._native, 'cses_mention_type': 'task'},
          {..._native, 'cses_mention_attributes': '{invalid'},
          {..._native, 'cses_mention_attributes': '{"mentionId":"other"}'},
          {..._native, 'cses_inline_mention': '长' * 201},
          {
            ..._native,
            'cses_mention_attributes': jsonEncode({'payload': '长' * 400}),
          },
          {
            ..._native,
            ...guidanceMentionAttributes(
              const GuidancePerson(id: 'x', name: '旧用户'),
            ),
          },
          {'cses_inline_mention': '缺少身份'},
          {'cses_mention_id': '缺少姓名'},
        ];
        for (final attributes in invalid) {
          final transaction = state.transaction
            ..insertText(node, 0, '\uFFFC', attributes: attributes);
          expect(state.canApplyTransaction(transaction), isFalse);
          await state.apply(transaction);
          expect(jsonEncode(state.document.toJson()), before);
        }
        final text = state.transaction
          ..insertText(node, 0, '伪造', attributes: _native);
        expect(state.canApplyTransaction(text), isFalse);
        await state.apply(text);
        expect(jsonEncode(state.document.toJson()), before);
      } finally {
        await journal.close();
      }
    },
  );

  for (final bold in [false, true]) {
    testWidgets(
      'native IME insertion, composition and replacement preserve identity bold=$bold',
      (tester) async {
        final journal = await _open(_Store());
        final state = journal.editor.editorState;
        final node = await _insert(journal, bold: bold);
        await _mount(tester, journal);
        try {
          state.undoManager.undoStack.clear();
          state.undoManager.redoStack.clear();
          final original = node.delta!.toJson();
          state.selection = Selection.collapsed(
            Position(path: node.path, offset: 1),
          );
          await tester.pump();
          await _keyboard(tester).textInputService.apply([
            const TextEditingDeltaInsertion(
              oldText: ' \uFFFC ',
              textInserted: 'xin',
              insertionOffset: 2,
              selection: TextSelection.collapsed(offset: 5),
              composing: TextRange(start: 2, end: 5),
            ),
          ]);
          expect(node.delta!.toPlainText(), '\uFFFCxin ');
          await _keyboard(tester).textInputService.apply([
            const TextEditingDeltaReplacement(
              oldText: ' \uFFFCxin ',
              replacementText: '新',
              replacedRange: TextRange(start: 2, end: 5),
              selection: TextSelection.collapsed(offset: 3),
              composing: TextRange.empty,
            ),
          ]);
          expect(node.delta!.toPlainText(), '\uFFFC新 ');
          expect(
            EditorUserMention.read(node.delta!.first.attributes!).id,
            'native-user',
          );
          final inserted = node.delta!.slice(1, 2).single;
          expect(
            EditorUserMention.attributeKeys.any(
              (key) => inserted.attributes?[key] != null,
            ),
            isFalse,
          );
          expect(inserted.attributes?['bold'] == true, bold);
          validateJournalDocument(state.document);
          state.undoManager.undo();
          await tester.pump();
          expect(node.delta!.toJson(), original);
          state.undoManager.redo();
          await tester.pump();
          expect(node.delta!.toPlainText(), '\uFFFC新 ');
          state.selection = Selection.single(
            path: node.path,
            startOffset: 0,
            endOffset: 1,
          );
          await tester.pump();
          await _keyboard(tester).textInputService.apply([
            const TextEditingDeltaReplacement(
              oldText: ' \uFFFC新 ',
              replacementText: '替',
              replacedRange: TextRange(start: 1, end: 2),
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange.empty,
            ),
          ]);
          expect(node.delta!.toPlainText(), '替新 ');
          validateJournalDocument(state.document);
        } finally {
          await _unmount(tester, journal);
        }
      },
    );
  }

  testWidgets(
    'typing @ uses native services and preview preserves the same user',
    (tester) async {
      var calls = 0;
      String? receivedKeyword;
      bool? receivedPermission;
      final store = _Store();
      final journal = await _open(
        store,
        services: CollabHostServices(
          pickMentionUser:
              (context, {required keyword, required canEdit}) async {
                calls++;
                receivedKeyword = keyword;
                receivedPermission = canEdit.value;
                return const CollabMentionUser(id: 'picked-user', name: '选择用户');
              },
          mentionAvatarBuilder:
              (
                context, {
                required userId,
                required name,
                required size,
                avatarUrl,
              }) => SizedBox.square(
                key: ValueKey('avatar-$userId'),
                dimension: size,
              ),
        ),
      );
      final state = journal.editor.editorState;
      await _mount(tester, journal);
      try {
        state.selection = Selection.collapsed(Position(path: [0, 0]));
        final event = tester
            .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
            .characterShortcutEvents
            .singleWhere((event) => event.key == 'cses-user-mention');
        final pending = event.handler(state);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        await tester.pump();
        expect(await pending, isTrue);
        expect(calls, 1);
        expect(receivedKeyword, isEmpty);
        expect(receivedPermission, isTrue);
        final node = state.getNodeAtPath([0, 0])!;
        expect(node.delta!.toPlainText(), '\uFFFC ');
        expect(
          EditorUserMention.read(node.delta!.first.attributes!).id,
          'picked-user',
        );
        expect(find.text('选择用户'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('avatar-picked-user')),
          findsOneWidget,
        );
        expect(await tester.runAsync(journal.flush), isTrue);
        state.editable = false;
        await _mount(tester, journal, preview: true);
        expect(find.text('选择用户'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('avatar-picked-user')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<EditorInteractionShell>(
                find.byType(EditorInteractionShell),
              )
              .enabled,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, journal);
      }
    },
  );
}
