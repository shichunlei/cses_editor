# 临时边界回归

在 example/test/daily_guidance/journal_section_close_focus_review_probe_test.dart 放入以下代码，并在 example 包执行 `flutter test --no-pub test/daily_guidance/journal_section_close_focus_review_probe_test.dart --reporter expanded`。审查后临时文件已移除。

```dart
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 关闭栏目焦点回归的独立草稿存储，不访问外部资源。
class _Store implements JournalStore {
  /// [kind] 指定唯一可关闭栏目；临时文档序列化后释放。
  _Store(String kind) {
    final draft = JournalDraft.blank(DateTime(2026, 11, 3));
    final document = Document.fromJson(jsonDecode(draft.documentJson));
    try {
      document.root.updateAttributes({'guidance_body_template': ''});
      for (final kind in [kind]) {
        document.insert(
          [document.root.children.length],
          [
            Node(
              type: journalSectionType,
              attributes: {'section': kind, 'guidance_section_label': kind},
              children: [paragraphNode(text: '保留栏目正文')],
            ),
          ],
        );
      }
      value = JournalDraft.fromJson({
        ...draft.toJson(),
        'document': document.toJson(),
      });
    } finally {
      document.dispose();
    }
  }

  /// 用例独占的持久快照。
  late JournalDraft value;

  /// 异步返回草稿，不借用可变正文。
  @override
  Future<JournalDraft?> read() async => value;

  /// 异步保存 [draft]，不接管编辑器资源。
  @override
  Future<void> write(JournalDraft draft) async =>
      value = JournalDraft.fromJson(draft.toJson());
}

/// 验证关闭栏目不激活正文输入，用户再次点击正文仍可继续编辑。
void main() {
  for (final kind in ['reflection', 'self-check', 'custom:focus']) {
    for (final keyboardWasOpen in [false, true]) {
      testWidgets(
        'review last $kind closes without focus with keyboard initially $keyboardWasOpen',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(390, 1400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(home: LocalJournalPage(store: _Store(kind))),
          );
          await tester.pumpAndSettle();
          final state = tester
              .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
              .editorState;
          final keyboard = tester.state<KeyboardServiceWidgetState>(
            find.byType(KeyboardServiceWidget),
          );
          final section = state.document.root.children.singleWhere(
            (node) => node.attributes['section'] == kind,
          );
          final before = section.toJson();
          {
            final entry = section.children.first;
            final rect = tester.getRect(
              find.byKey(ValueKey('journal-lines-${entry.id}')),
            );
            await tester.tapAt(Offset(rect.left + 20, rect.center.dy));
            await tester.pumpAndSettle();
            expect(tester.testTextInput.isVisible, isTrue);
            expect(keyboard.focusNode.hasFocus, isTrue);
            if (!keyboardWasOpen) {
              keyboard.closeKeyboard();
              FocusManager.instance.primaryFocus?.unfocus();
              await tester.pumpAndSettle();
              expect(state.selection, isNotNull);
              expect(tester.testTextInput.isVisible, isFalse);
            }
          }
          await tester.tap(find.byKey(ValueKey('journal-close-$kind')));
          await tester.pumpAndSettle();
          expect(
            state.document.root.children.any(
              (node) => node.attributes['section'] == kind,
            ),
            isFalse,
          );
          expect(closedJournalSections(state.document).single.toJson(), before);
          expect(state.selection, isNull);
          expect(tester.testTextInput.isVisible, isFalse);
          expect(keyboard.focusNode.hasFocus, isFalse);
          // 关闭保持可编辑；下一次真实点击正文才恢复输入。
          final record = state.document.root.children.first.children.first;
          final rect = tester.getRect(
            find.byKey(ValueKey('journal-lines-${record.id}')),
          );
          await tester.tapAt(Offset(rect.left + 20, rect.center.dy));
          await tester.pumpAndSettle();
          expect(state.selection?.start.path, record.path);
          expect(tester.testTextInput.isVisible, isTrue);
          expect(state.editable, isTrue);
          state.undoManager.undo();
          await tester.pumpAndSettle();
          expect(
            state.document.root.children
                .singleWhere((node) => node.attributes['section'] == kind)
                .toJson(),
            before,
          );
          state.undoManager.redo();
          await tester.pumpAndSettle();
          expect(state.selection, isNull);
          expect(tester.testTextInput.isVisible, isFalse);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}

```
