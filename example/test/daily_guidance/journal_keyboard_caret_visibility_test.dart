import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 提供长正文的独立草稿，资源不与用户文件或服务共享。
class _Store implements JournalStore {
  /// [singleParagraph] 为 true 时以单段多行测试行级避让，否则使用多段正文。
  _Store({required bool singleParagraph}) {
    final draft = JournalDraft.blank(DateTime(2026, 11, 3));
    final lines = List.generate(80, (index) => '第${index + 1}行，持续记录今天的内容。');
    final document = Document(
      root: Node(
        type: 'page',
        children: [
          Node(
            type: journalSectionType,
            attributes: {'section': 'record'},
            children: [
              if (singleParagraph)
                paragraphNode(text: lines.join('\n'))
              else
                for (final line in lines) paragraphNode(text: line),
            ],
          ),
        ],
      ),
    );
    try {
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

  /// 异步读取本用例草稿。
  @override
  Future<JournalDraft?> read() async => value;

  /// 异步保存 [draft]，不获取编辑器所有权。
  @override
  Future<void> write(JournalDraft draft) async =>
      value = JournalDraft.fromJson(draft.toJson());
}

/// 验证键盘迟到、连续改变高度和展开菜单时，整行光标都在实际可编辑区域内。
void main() {
  for (final sample in [(390.0, 1.0), (320.0, 1.5)]) {
    for (final singleParagraph in [false, true]) {
      testWidgets(
        'caret clears keyboard and menu at $sample single=$singleParagraph',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(sample.$1, 1100));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(sample.$2)),
                child: child!,
              ),
              home: LocalJournalPage(
                store: _Store(singleParagraph: singleParagraph),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final state = tester
              .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
              .editorState;
          await tester.tapAt(const Offset(80, 1000));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          expect(state.selection?.isCollapsed, isTrue);
          final selected = state.selection;
          final before = jsonEncode(state.document.toJson());
          expect(state.selectionRects().single.bottom, greaterThan(780));
          // 系统键盘在点击后才逐帧弹起，选区不再变化。
          for (final height in [120.0, 240.0, 320.0]) {
            tester.view.viewInsets = FakeViewPadding(bottom: height);
            await tester.pump(const Duration(milliseconds: 16));
            await tester.pump();
            final toolbarTop = tester
                .getTopLeft(find.byKey(const ValueKey('editor-mobile-toolbar')))
                .dy;
            expect(
              state.selectionRects().single.bottom,
              lessThanOrEqualTo(toolbarTop - 4),
            );
            expect(
              state.selectionRects().single.top,
              greaterThanOrEqualTo(
                tester
                    .getRect(find.byKey(const ValueKey('journal-cover')))
                    .bottom,
              ),
            );
            expect(state.selection, selected);
          }
          await tester.tap(
            find.byKey(const ValueKey('editor-shortcut-inline-style')),
          );
          await tester.pump();
          await tester.pump();
          final menuTop = tester
              .getTopLeft(find.byKey(const ValueKey('editor-toolbar-popup')))
              .dy;
          expect(
            state.selectionRects().single.bottom,
            lessThanOrEqualTo(menuTop - 4),
          );
          expect(jsonEncode(state.document.toJson()), before);
          expect(state.selection, selected);
          final end = state.document.root.children.single.children.last;
          state.selection = Selection.collapsed(
            Position(path: end.path, offset: end.delta!.length),
          );
          await tester.pump();
          await tester.pump();
          expect(
            state.selectionRects().single.bottom,
            lessThanOrEqualTo(menuTop - 4),
          );
          expect(jsonEncode(state.document.toJson()), before);
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('editor-toolbar-close-keyboard-or-menu')),
          );
          await tester.pump();
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pumpAndSettle();
          expect(tester.testTextInput.isVisible, isFalse);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
