import 'dart:convert';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_offline_example/daily_guidance/guidance_api.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:cses_offline_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 从 [tester] 借用当前页面编辑器，资源由页面拥有并释放。
EditorState _state(WidgetTester tester) =>
    tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;

/// 在真实 Android 验证空文档日期、编辑历史、完整保存、分享 PNG 和重开恢复。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'empty guidance edits, saves, generates share image and reopens',
    (tester) async {
      await tester.pumpWidget(const OfflineExampleApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-daily-guidance')));
      await tester.pumpAndSettle();
      final state = _state(tester);
      expect(state.document.root.children, hasLength(1));
      final node = state.getNodeAtPath([0, 0])!;
      expect(node.delta!.isEmpty, isTrue);
      final page = tester.widget<LocalJournalPage>(
        find.byType(LocalJournalPage),
      );
      final store = page.store as ApiJournalStore;
      final initial = await store.api.fetch(store.recordId);
      expect(initial['orientType'], 'ORIENT');
      expect(
        (initial['bodyContent'] as Map)['meta']['dailyDate'],
        journalDate(DateTime.now()),
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('empty-device-initial');
      debugPrint('EMPTY_FLOW: initial empty ORIENT and local date verified');

      final selection = state.updateSelectionWithReason(
        Selection.collapsed(Position(path: node.path)),
        reason: SelectionUpdateReason.uiEvent,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await selection;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('editor-mobile-toolbar')),
        findsOneWidget,
      );
      const text = '真机空白文档验证：记录今天，完成编辑、保存与分享。';
      await state.apply(
        state.transaction..insertText(node, 0, text),
        skipHistoryDebounce: true,
      );
      await tester.pumpAndSettle();
      state.undoManager.undo();
      await tester.pumpAndSettle();
      expect(node.delta!.toPlainText(), isEmpty);
      state.undoManager.redo();
      await tester.pumpAndSettle();
      expect(node.delta!.toPlainText(), text);
      await binding.takeScreenshot('empty-device-edited');
      debugPrint('EMPTY_FLOW: keyboard, text, undo and redo verified');

      await tester.tap(find.byKey(const ValueKey('journal-save')));
      await tester.pumpAndSettle();
      expect(state.editable, isFalse);
      expect(find.byKey(const ValueKey('journal-save')), findsNothing);
      final record = await store.api.fetch(store.recordId);
      expect(record['dailyOrient'], {'content': text, 'mentions': []});
      expect(record['dailyResult'], isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('empty-device-saved-preview');
      final snapshot = jsonEncode(state.document.toJson());
      debugPrint(
        'EMPTY_FLOW: full record saved and read-only preview verified',
      );

      await tester.tap(find.byKey(const ValueKey('journal-share')));
      await tester.pumpAndSettle();
      final image = find.byKey(const ValueKey('journal-share-image'));
      for (var i = 0; i < 100 && image.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(image, findsOneWidget);
      final bytes = (tester.widget<Image>(image).image as MemoryImage).bytes;
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      for (final target in ['wechat', 'timeline', 'save']) {
        expect(
          tester
              .widget<TextButton>(find.byKey(ValueKey('journal-share-$target')))
              .onPressed,
          isNotNull,
        );
      }
      await binding.takeScreenshot('empty-device-share');
      debugPrint('EMPTY_FLOW: real PNG and all three share actions verified');
      await tester.tap(find.byKey(const ValueKey('journal-share-cancel')));
      await tester.pumpAndSettle();
      expect(jsonEncode(state.document.toJson()), snapshot);
      await tester.tap(find.byKey(const ValueKey('journal-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-daily-guidance')));
      await tester.pumpAndSettle();
      expect(_state(tester).editable, isTrue);
      expect(_state(tester).getNodeAtPath([0, 0])!.delta!.toPlainText(), text);
      await binding.takeScreenshot('empty-device-reopened');
      debugPrint('EMPTY_FLOW: saved document reopened without loss');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('journal-back')));
      await tester.pumpAndSettle();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
