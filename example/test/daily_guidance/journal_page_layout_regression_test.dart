import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_exchange_keys.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用例独占内存草稿，不访问用户存储或外部服务。
class _Store implements JournalStore {
  /// [plain] 模拟无封面的桌面导入文档；[text] 为首段内容，临时文档序列化后立即释放。
  _Store({bool plain = false, String text = '首行正文'}) {
    final draft = JournalDraft.blank(DateTime(2026, 11, 3));
    final document = Document.fromJson(jsonDecode(draft.documentJson));
    try {
      document.root.updateAttributes({
        if (plain) journalPlainDesktopAttribute: true,
        if (plain) journalDesktopImportAttribute: true,
      });
      document.root.children.first.children.first.updateAttributes({
        blockComponentDelta: (Delta()..insert(text)).toJson(),
      });
      value = JournalDraft.fromJson({
        ...draft.toJson(),
        'document': document.toJson(),
      });
    } finally {
      document.dispose();
    }
  }

  /// 可独立恢复的持久快照。
  late JournalDraft value;

  /// 异步返回草稿，不转移存储所有权。
  @override
  Future<JournalDraft?> read() async => value;

  /// 异步保存 [draft]，不借用可变正文树。
  @override
  Future<void> write(JournalDraft draft) async =>
      value = JournalDraft.fromJson(draft.toJson());
}

/// 用 [tester] 点击 [state] 的首段；验证真实选区服务而非预先指定光标。
Future<void> _tapFirstParagraph(WidgetTester tester, EditorState state) async {
  state.selection = null;
  await tester.pumpAndSettle();
  final node = state.document.root.children.first.children.first;
  final rect = tester.getRect(find.byKey(ValueKey('journal-lines-${node.id}')));
  await tester.tapAt(Offset(rect.left + 25, rect.center.dy));
  await tester.pumpAndSettle();
  expect(state.selection?.isCollapsed, isTrue);
  expect(state.selection?.start.path, node.path);
}

/// 回归初始单栏目点击定位、动态栏目切换，以及无封面文档的顶部避让。
void main() {
  testWidgets(
    'single section keeps visible indices and supports tap and IME input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: LocalJournalPage(store: _Store(text: '')),
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      final state = editor.editorState;
      final scroll = editor.editorScrollController!;
      expect(state.showHeader, isTrue);
      expect(scroll.visibleRangeNotifier.value.$2, greaterThanOrEqualTo(0));
      await _tapFirstParagraph(tester, state);
      final offset = state.selection!.start.offset;
      final node = state.document.root.children.first.children.first;
      final before = node.delta!.toPlainText();
      final keyboard = tester.state<KeyboardServiceWidgetState>(
        find.byType(KeyboardServiceWidget),
      );
      await keyboard.textInputService.apply([
        TextEditingDeltaInsertion(
          oldText: ' $before',
          textInserted: '新',
          insertionOffset: offset + 1,
          selection: TextSelection.collapsed(offset: offset + 2),
          composing: TextRange.empty,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(
        node.delta!.toPlainText(),
        '${before.substring(0, offset)}新${before.substring(offset)}',
      );
      for (final kind in ['reflection', 'custom:review']) {
        await state.apply(
          state.transaction
            ..updateNode(state.document.root, {
              'guidance_section_revision': 1,
              if (kind.startsWith('custom:')) 'guidance_body_template': '',
            })
            ..insertNode(
              [1],
              Node(
                type: journalSectionType,
                attributes: {'section': kind},
                children: [paragraphNode()],
              ),
            ),
        );
        await tester.pumpAndSettle();
        await _tapFirstParagraph(tester, state);
        state.undoManager.undo();
        await tester.pumpAndSettle();
        expect(state.document.root.children, hasLength(1));
        expect(scroll.visibleRangeNotifier.value.$2, greaterThanOrEqualTo(0));
        await _tapFirstParagraph(tester, state);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  for (final mode in JournalPageMode.values) {
    testWidgets('plain document clears app bar and status bar in $mode', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 32),
              viewPadding: const EdgeInsets.only(top: 32),
              textScaler: TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: LocalJournalPage(store: _Store(plain: true), mode: mode),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      final first =
          state.document.root.children.first.children.first.key.currentContext!
                  .findRenderObject()!
              as RenderBox;
      final top = first.localToGlobal(Offset.zero).dy;
      final barBottom = tester.getRect(find.byType(AppBar)).bottom;
      expect(find.byKey(const ValueKey('journal-cover')), findsNothing);
      expect(top, greaterThanOrEqualTo(barBottom));
      expect(top, greaterThanOrEqualTo(32 + kToolbarHeight));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
