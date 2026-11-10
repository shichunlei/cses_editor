import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_ruled_content.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/journal_surface.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_controller.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 真机验收使用独立内存草稿。
class _Store implements JournalStore {
  /// 异步提供测试日期的空草稿。
  @override
  Future<JournalDraft?> read() async =>
      JournalDraft.blank(DateTime(2026, 11, 5));

  /// 接收测试页保存的 [draft]，无需持有持久资源。
  @override
  Future<void> write(JournalDraft draft) async {}
}

/// 找到末尾感悟栏的横格绘制区域。
Finder _reflectionRules() => find
    .descendant(
      of: find.byKey(const ValueKey('journal-section-reflection')),
      matching: find.byType(JournalRuledContent),
    )
    .first;

/// 在设备真实视口上验证横格绘制、日期手势及程序化滚动。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android short content fills the editor viewport', (
    tester,
  ) async {
    final journal = await LocalJournalController.open(
      store: _Store(),
      autoSave: false,
    );
    final state = journal.editor.editorState;
    await journal.addSection('reflection');
    state.selection = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalSurface(
            editorState: state,
            preview: false,
            header: const SizedBox(height: 24),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byType(AppFlowyEditor));
    final shortRules = tester.getRect(_reflectionRules());
    final render = tester.renderObject<RenderJournalRules>(_reflectionRules());
    expect(shortRules.bottom, closeTo(viewport.bottom, 1));
    expect(render.debugLineOffsets, isNotEmpty);
    expect(render.size.height - render.debugLineOffsets.last, lessThan(32));
    debugPrint(
      'Device short rules: ${shortRules.height}; viewport bottom: ${viewport.bottom}; rules bottom: ${shortRules.bottom}',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await journal.close();
  });

  testWidgets('Android date selection and index jump with a full page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LocalJournalPage(store: _Store())),
    );
    await tester.pumpAndSettle();
    final editorFinder = find.byType(AppFlowyEditor);
    final editor = tester.widget<AppFlowyEditor>(editorFinder);
    final state = editor.editorState;
    final first = state.document.root.children.first.children.first;
    await state.apply(
      state.transaction
        ..updateNode(state.document.root, {'guidance_section_revision': 1})
        ..insertText(first, 0, '今日记录')
        ..insertNode(
          [1],
          Node(
            type: journalSectionType,
            attributes: {'section': 'reflection'},
            children: [paragraphNode()],
          ),
        ),
      skipHistoryDebounce: true,
    );
    await tester.pumpAndSettle();

    state.selection = null;
    state.service.keyboardService?.closeKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final viewportBottom = tester.getRect(editorFinder).bottom;
    final rulesBottom = tester.getRect(_reflectionRules()).bottom;
    debugPrint(
      'Device full page: viewport bottom $viewportBottom; rules bottom $rulesBottom',
    );
    expect(rulesBottom, closeTo(viewportBottom, 1));
    expect(
      tester
          .renderObject<RenderJournalRules>(_reflectionRules())
          .debugLineOffsets,
      isNotEmpty,
    );

    state.selection = Selection(
      start: Position(path: first.path),
      end: Position(path: first.path, offset: 1),
    );
    await tester.pump();
    expect(state.selection?.isCollapsed, isFalse);
    final date = find.byKey(const ValueKey('journal-date'));
    final dateStart = tester.getTopLeft(date).dy;
    final press = await tester.startGesture(tester.getCenter(date));
    await tester.pump();
    expect(state.selection, isNull);
    await press.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('journal-calendar')), findsOneWidget);
    tester
        .widget<CalendarDatePicker>(
          find.byKey(const ValueKey('journal-calendar')),
        )
        .onDateChanged(DateTime(2026, 11, 5));
    await tester.pumpAndSettle();

    await state.apply(
      state.transaction..insertText(first, 0, List.filled(45, '长文\n').join()),
      skipHistoryDebounce: true,
    );
    await tester.pumpAndSettle();
    final scroll = editor.editorScrollController!.itemScrollController;
    scroll.jumpTo(index: 2);
    await tester.pumpAndSettle();
    expect(tester.getSize(_reflectionRules()).height, closeTo(32, 2));
    debugPrint(
      'Device long rules: ${tester.getSize(_reflectionRules()).height}',
    );
    scroll.jumpTo(index: 0);
    await tester.pumpAndSettle();
    expect(date.hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(date).dy, closeTo(dateStart, 1));
    expect(tester.takeException(), isNull);
    debugPrint('Device return to date: ${tester.getTopLeft(date).dy}');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
