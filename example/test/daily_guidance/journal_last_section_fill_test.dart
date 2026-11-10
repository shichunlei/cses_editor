import 'dart:convert';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_ruled_content.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/journal_surface.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 独占内存草稿；布局不得写入存储，不创建外部资源。
class _Store implements JournalStore {
  /// 异步提供一个首栏目空草稿，不共享可变节点。
  @override
  Future<JournalDraft?> read() async =>
      JournalDraft.blank(DateTime(2026, 11, 5));

  /// 布局过程不应保存 [draft]。
  @override
  Future<void> write(JournalDraft draft) async => fail('布局不应保存正文');
}

/// 定位 [kind] 栏目外层的补线区域；[kind] 是正文栏目身份。
Finder _rules(String kind) => find
    .descendant(
      of: find.byKey(ValueKey('journal-section-$kind')),
      matching: find.byType(JournalRuledContent),
    )
    .first;

/// 验证末栏补齐、动态内容、视口变化及真实文档与选区保持独立。
void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('last section fills viewport: editing scale=$scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final journal = await LocalJournalController.open(
        store: _Store(),
        autoSave: false,
      );
      final state = journal.editor.editorState;
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
              editorState: state,
              preview: false,
              header: const SizedBox(
                key: ValueKey('journal-test-header'),
                height: 120,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lineHeight = 32 * scale;
      for (final kind in ['reflection', 'self-check', 'custom:last']) {
        await state.apply(
          state.transaction
            ..updateNode(state.document.root, {
              'guidance_section_revision': state.document.root.children.length,
              if (kind.startsWith('custom:')) 'guidance_body_template': '',
            })
            ..insertNode(
              [state.document.root.children.length],
              Node(
                type: journalSectionType,
                attributes: {'section': kind, 'guidance_section_label': kind},
                children: [paragraphNode()],
              ),
            ),
        );
        await tester.pumpAndSettle();
        final before = jsonEncode(state.document.toJson());
        final last = tester.renderObject<RenderJournalRules>(_rules(kind));
        final surface = tester.getRect(find.byType(JournalSurface));
        expect(tester.getRect(_rules(kind)).bottom, closeTo(surface.bottom, 1));
        expect(last.debugLineOffsets, isNotEmpty);
        expect(
          last.size.height - last.debugLineOffsets.last,
          lessThan(lineHeight),
        );
        for (final preceding in state.document.root.children.take(
          state.document.root.children.length - 1,
        )) {
          expect(
            tester
                .getSize(_rules(preceding.attributes['section'] as String))
                .height,
            closeTo(lineHeight, 1),
          );
        }
        await tester.pump();
        expect(jsonEncode(state.document.toJson()), before);
      }
      final lastBefore = tester.getSize(_rules('custom:last')).height;
      final paragraph = state.document.root.children.first.children.first;
      await state.apply(state.transaction..insertText(paragraph, 0, '新增一行\n'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(_rules('custom:last')).height,
        closeTo(lastBefore - lineHeight, 1),
      );

      // 模拟键盘导致可用正文视口变短，恢复后末栏重新补齐。
      final viewportBefore = tester.getSize(find.byType(AppFlowyEditor)).height;
      final rulesBefore = tester.getSize(_rules('custom:last')).height;
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(_rules('custom:last')).height,
        closeTo(
          (rulesBefore -
                  viewportBefore +
                  tester.getSize(find.byType(AppFlowyEditor)).height)
              .clamp(lineHeight, double.infinity),
          1,
        ),
      );
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      // 上方正文超过整屏时，末栏只保留一行，不额外增加一屏空白。
      await state.apply(
        state.transaction
          ..insertText(paragraph, 0, List.filled(45, '长内容\n').join()),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorScrollController!
          .itemScrollController;
      // 编辑器的日期头部占索引 0，末栏目索引等于栏目数。
      scroll.jumpTo(index: state.document.root.children.length);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(_rules('custom:last')).height,
        closeTo(lineHeight, 1),
      );
      scroll.jumpTo(index: 0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('journal-test-header'))).dy,
        closeTo(tester.getTopLeft(find.byType(AppFlowyEditor)).dy, 1),
      );
      state.undoManager.undo();
      await tester.pumpAndSettle();
      expect(
        tester.getRect(_rules('custom:last')).bottom,
        closeTo(tester.getRect(find.byType(AppFlowyEditor)).bottom, 1),
      );

      // 删除末栏目后，补线转移至新的最后一栏。
      await state.apply(
        state.transaction
          ..updateNode(state.document.root, {'guidance_section_revision': 10})
          ..deleteNode(state.document.root.children.last),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(_rules('self-check')).bottom,
        closeTo(tester.getRect(find.byType(AppFlowyEditor)).bottom, 1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(journal.close);
    });
  }
  testWidgets(
    'preview fills last section inside safe area without changing document',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final journal = await LocalJournalController.open(
        store: _Store(),
        autoSave: false,
      );
      final state = journal.editor.editorState;
      await state.apply(
        state.transaction
          ..updateNode(state.document.root, {'guidance_section_revision': 1})
          ..insertNodes(
            [1],
            [
              for (final kind in ['reflection', 'self-check'])
                Node(
                  type: journalSectionType,
                  attributes: {'section': kind},
                  children: [paragraphNode()],
                ),
            ],
          ),
      );
      final before = jsonEncode(state.document.toJson());
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SafeArea(
              child: JournalSurface(
                editorState: state,
                preview: true,
                header: const SizedBox(height: 120),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(_rules('self-check')).bottom,
        closeTo(tester.getRect(find.byType(AppFlowyEditor)).bottom, 1),
      );
      expect(
        tester
            .renderObject<RenderJournalRules>(_rules('self-check'))
            .debugLineOffsets
            .length,
        greaterThan(2),
      );
      expect(jsonEncode(state.document.toJson()), before);
      expect(state.selection, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(journal.close);
    },
  );
}
