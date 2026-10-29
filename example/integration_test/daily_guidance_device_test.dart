import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// 从[tester]借用当前页面的编辑状态，不获取其释放所有权。
EditorState _state(WidgetTester tester) =>
    tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;

/// 收集借用[state]的文本叶节点内容，用于预览和重开断言。
String _text(EditorState state) {
  final lines = <String>[];
  void visit(Node node) {
    if (node.delta != null) lines.add(node.delta!.toPlainText());
    for (final child in node.children) {
      visit(child);
    }
  }

  visit(state.document.root);
  return lines.join('\n');
}

/// 为[tester]中的[state]建立真实输入连接，并将光标定位到借用的[node]末尾。
Future<void> _focus(WidgetTester tester, EditorState state, Node node) async {
  final selection = state.updateSelectionWithReason(
    Selection.collapsed(Position(path: node.path, offset: node.delta!.length)),
    reason: SelectionUpdateReason.uiEvent,
  );
  await tester.pump(const Duration(milliseconds: 300));
  await selection;
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('editor-mobile-toolbar')), findsOneWidget);
}

/// 在[tester]的真实横向工具栏中显示并点击[key]，不跳过不可达按钮。
Future<void> _toolbar(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  final list = find.descendant(
    of: find.byKey(const ValueKey('editor-mobile-toolbar')),
    matching: find.byType(ListView),
  );
  await tester.drag(list, const Offset(1000, 0));
  await tester.pumpAndSettle();
  for (var i = 0; i < 18 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(-120, 0));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget, reason: key);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// 收起借用[state]的真实键盘，等待[tester]中的布局稳定，不释放编辑会话。
Future<void> _hideKeyboard(WidgetTester tester, EditorState state) async {
  state.service.keyboardService?.closeKeyboard();
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
}

/// 在真实设备验证编辑历史、键盘、提及/业务行、栏目、日期、预览和草稿恢复。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('standalone daily guidance persists on the device', (
    tester,
  ) async {
    await tester.pumpWidget(const OfflineExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-daily-guidance')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('journal-cover')), findsOneWidget);
    final state = _state(tester);
    final marker = '真机离线验证-${DateTime.now().millisecondsSinceEpoch}';
    final node = state.getNodeAtPath([0, 0])!;
    await state.apply(
      state.transaction..insertText(node, 0, marker),
      skipHistoryDebounce: true,
    );
    await tester.pumpAndSettle();
    expect(_text(state), contains(marker));
    state.undoManager.undo();
    await tester.pumpAndSettle();
    expect(_text(state), isNot(contains(marker)));
    state.undoManager.redo();
    await tester.pumpAndSettle();
    expect(_text(state), contains(marker));

    await tester.tap(find.byKey(const ValueKey('journal-preview')));
    await tester.pumpAndSettle();
    expect(_state(tester).editable, isFalse);
    expect(_text(_state(tester)), contains(marker));
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('device-preview');
    await tester.tap(find.byKey(const ValueKey('journal-preview')));
    await tester.pumpAndSettle();
    expect(_state(tester).editable, isTrue);

    await tester.tap(find.byKey(const ValueKey('journal-json-menu')));
    await tester.pumpAndSettle();
    expect(find.text('导出桌面JSON'), findsOneWidget);
    expect(find.text('打开桌面JSON'), findsOneWidget);
    await tester.tapAt(const Offset(20, 250));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-daily-guidance')), findsOneWidget);

    // 实际设备私有目录中的文件必须已经包含已完成的编辑事务。
    final directory = await getApplicationDocumentsDirectory();
    final files = await Directory(
      '${directory.path}/daily-guidance',
    ).list().toList();
    final drafts = files
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList();
    expect(drafts, isNotEmpty);
    var saved = false;
    for (final file in drafts) {
      final content = await file.readAsString();
      jsonDecode(content);
      if (content.contains(marker)) saved = true;
    }
    expect(saved, isTrue);

    await tester.tap(find.byKey(const ValueKey('open-daily-guidance')));
    await tester.pumpAndSettle();
    expect(_text(_state(tester)), contains(marker));
    await binding.takeScreenshot('device-reopened');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('journal-back')));
    await tester.pumpAndSettle();
  });
  testWidgets(
    'daily guidance native toolbar, people, sections and date work after layout migration',
    (tester) async {
      await tester.pumpWidget(const OfflineExampleApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-daily-guidance')));
      await tester.pumpAndSettle();
      final state = _state(tester);
      var record = state.document.root.children.first;
      var body = record.children.first;
      const marker = '结构调整后功能验证';
      await state.apply(
        state.transaction..insertText(body, 0, marker),
        skipHistoryDebounce: true,
      );
      await _focus(tester, state, body);
      await _toolbar(tester, 'editor-keyboard-todoList');
      body = state.getNodeAtPath([0, 0])!;
      expect(body.type, TodoListBlockKeys.type);
      expect(body.delta!.toPlainText(), contains(marker));
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('device-todo-toolbar');

      await _toolbar(tester, 'editor-shortcut-mention');
      expect(find.byKey(const ValueKey('mention-search')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mention-user-sample-lin')));
      await tester.pumpAndSettle();
      expect(jsonEncode(state.document.toJson()), contains('sample-lin'));
      expect(state.localTransactionsPaused, isFalse);

      for (final kind in ['pilot', 'help']) {
        record = state.document.root.children.first;
        await _focus(tester, state, record.children.first);
        await _toolbar(tester, 'editor-keyboard-host-guidance-action-$kind');
        await tester.tap(
          find.byKey(const ValueKey('mention-user-sample-chen')),
        );
        await tester.pumpAndSettle();
        expect(
          state.document.root.children.first.children.any(
            (node) => node.attributes['guidance_entry'] == kind,
          ),
          isTrue,
        );
        expect(state.localTransactionsPaused, isFalse);
      }

      for (final kind in ['reflection', 'self-check']) {
        await _focus(
          tester,
          state,
          state.document.root.children.first.children.first,
        );
        await _toolbar(tester, 'editor-keyboard-host-guidance-add-$kind');
        final section = state.document.root.children.firstWhere(
          (node) => node.attributes['section'] == kind,
        );
        await state.apply(
          state.transaction..insertText(section.children.first, 0, '$kind栏目正文'),
          skipHistoryDebounce: true,
        );
      }
      expect(state.document.root.children.length, 3);
      await _hideKeyboard(tester, state);
      final close = find.byKey(const ValueKey('journal-close-reflection'));
      await tester.ensureVisible(close);
      await tester.pumpAndSettle();
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(
        state.document.root.children.any(
          (node) => node.attributes['section'] == 'reflection',
        ),
        isFalse,
      );
      state.undoManager.undo();
      await tester.pumpAndSettle();
      expect(_text(state), contains('reflection栏目正文'));
      await _hideKeyboard(tester, state);

      final date = find.byKey(const ValueKey('journal-date'));
      await tester.ensureVisible(date);
      await tester.pumpAndSettle();
      await tester.tap(date);
      await tester.pumpAndSettle();
      final calendar = find.byKey(const ValueKey('journal-calendar'));
      final day = find.descendant(of: calendar, matching: find.text('15'));
      await tester.ensureVisible(day);
      await tester.pumpAndSettle();
      await tester.tap(day);
      await tester.pumpAndSettle();
      expect(calendar, findsNothing);

      await tester.tap(find.byKey(const ValueKey('journal-preview')));
      await tester.pumpAndSettle();
      expect(_state(tester).editable, isFalse);
      expect(_text(_state(tester)), contains(marker));
      expect(_text(_state(tester)), contains('reflection栏目正文'));
      await binding.takeScreenshot('device-sections-preview');
      await tester.tap(find.byKey(const ValueKey('journal-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-daily-guidance')));
      await tester.pumpAndSettle();
      final restored = _state(tester);
      expect(restored.document.root.children.length, 3);
      expect(_text(restored), contains('self-check栏目正文'));
      final content = jsonEncode(restored.document.toJson());
      for (final value in ['sample-lin', 'sample-chen', 'pilot', 'help']) {
        expect(content, contains(value));
      }
      final directory = await getApplicationDocumentsDirectory();
      final draft =
          jsonDecode(
                await File(
                  '${directory.path}/daily-guidance/offline-example.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect((draft['date'] as String).endsWith('-15'), isTrue);
      await binding.takeScreenshot('device-full-reopened');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('journal-back')));
      await tester.pumpAndSettle();
    },
  );
}
