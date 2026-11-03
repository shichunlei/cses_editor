# 审查临时复现用例

在 example/test/daily_guidance/review_layout_probe_test.dart 放入以下代码，在 example 包运行 `flutter test --no-pub test/daily_guidance/review_layout_probe_test.dart --reporter expanded`。本轮审查后已移除临时用例，业务代码未改动。

```dart
import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/journal_exchange_keys.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
class _Store implements JournalStore {
  _Store({bool plain = false}) {
    final draft = JournalDraft.blank(DateTime(2026, 11, 3));
    final document = Document.fromJson(jsonDecode(draft.documentJson));
    document.root.updateAttributes({if (plain) journalPlainDesktopAttribute: true});
    document.root.children.first.children.first.updateAttributes({blockComponentDelta: (Delta()..insert('审查首行正文')).toJson()});
    value = JournalDraft.fromJson({...draft.toJson(), 'document': document.toJson()});
    document.dispose();
  }
  late JournalDraft value;
  @override
  Future<JournalDraft?> read() async => value;
  @override
  Future<void> write(JournalDraft draft) async => value = draft;
}
void main() {
  testWidgets('review: single section must remain visible to selection service', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LocalJournalPage(store: _Store())));
    await tester.pumpAndSettle();
    final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
    final range = editor.editorScrollController!.visibleRangeNotifier.value;
    debugPrint('single-section visible range: $range');
    final text = find.byKey(ValueKey('journal-lines-${editor.editorState.document.root.children.first.children.first.id}'));
    await tester.tapAt(tester.getRect(text).center);
    await tester.pumpAndSettle();
    expect(editor.editorState.selection, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('review: plain document first line must not overlap app bar', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LocalJournalPage(store: _Store(plain: true))));
    await tester.pumpAndSettle();
    final state = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;
    final first = state.document.root.children.first.children.first.key.currentContext!.findRenderObject()! as RenderBox;
    final top = first.localToGlobal(Offset.zero).dy;
    final bottom = tester.getRect(find.byKey(const ValueKey('journal-back'))).bottom;
    expect(top, greaterThanOrEqualTo(bottom));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('review: landscape keyboard leaves enough room for fixed cover', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(home: LocalJournalPage(store: _Store())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

```
