import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_ruled_content.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/journal_surface.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用例独占的内存草稿，不创建外部资源。
class _Store implements JournalStore {
  /// 初始只包含首栏目。
  JournalDraft value = JournalDraft.blank(DateTime(2026, 11, 3));

  /// 异步返回当前草稿。
  @override
  Future<JournalDraft?> read() async => value;

  /// 异步保存 [draft]，由用例持有存储。
  @override
  Future<void> write(JournalDraft draft) async => value = draft;
}

/// 验证固定封面、视口补线及动态栏目切换。
void main() {
  for (final sample in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('rules fill viewport and cover stays fixed at $sample', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(sample.$1, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(sample.$2)),
            child: child!,
          ),
          home: LocalJournalPage(store: _Store()),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      final before = jsonEncode(state.document.toJson());
      final cover = find.byKey(const ValueKey('journal-cover'));
      final coverRect = tester.getRect(cover);
      final surface = tester.getRect(find.byType(JournalSurface));
      final rulesFinder = find
          .descendant(
            of: find.byKey(const ValueKey('journal-section-record')),
            matching: find.byType(JournalRuledContent),
          )
          .first;
      final rules = tester.renderObject<RenderJournalRules>(rulesFinder);
      expect(surface.top, coverRect.bottom);
      expect(tester.getRect(rulesFinder).bottom, closeTo(surface.bottom, 1));
      expect(rules.debugLineOffsets.length, greaterThan(2));
      expect(
        rules.size.height - rules.debugLineOffsets.last,
        lessThan(32 * sample.$2),
      );
      expect(jsonEncode(state.document.toJson()), before);
      final record = state.document.root.children.single;
      for (final kind in ['reflection', 'self-check', 'custom:sample']) {
        final extra = Node(
          type: journalSectionType,
          attributes: {'section': kind, 'guidance_section_label': '测试栏目'},
          children: [paragraphNode(text: '栏目内容')],
        );
        await state.apply(
          state.transaction
            ..updateNode(state.document.root, {
              'guidance_section_revision': 1,
              if (kind.startsWith('custom:')) 'guidance_body_template': '',
            })
            ..insertNode([1], extra),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(rulesFinder).height, lessThan(100 * sample.$2));
        state.undoManager.undo();
        await tester.pumpAndSettle();
        expect(tester.getRect(rulesFinder).bottom, closeTo(surface.bottom, 1));
      }
      await state.apply(
        state.transaction..insertText(
          record.children.first,
          0,
          List.filled(80, '今日持续书写，测试正文滚动。').join(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(
        Offset(sample.$1 / 2, surface.top + 60),
        const Offset(0, 10000),
      );
      await tester.pumpAndSettle();
      final date = find.byKey(const ValueKey('journal-date'));
      final dateTop = tester.getTopLeft(date).dy;
      await tester.dragFrom(
        Offset(sample.$1 / 2, surface.bottom - 60),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(cover), coverRect);
      expect(tester.getTopLeft(date).dy, lessThan(dateTop));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
