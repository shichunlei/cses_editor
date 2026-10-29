import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/journal_surface.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_controller.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:cses_offline_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试独占的本地存储，记录预览是否意外保存。
class _Store implements JournalStore {
  /// 初始可编辑快照，预览加载不能修改该对象。
  JournalDraft? value = JournalDraft.blank(DateTime(2026, 10, 29));

  /// 实际持久化次数。
  int writes = 0;

  /// 返回当前独立快照。
  @override
  Future<JournalDraft?> read() async => value;

  /// 记录并校验 [draft] 写入，不访问外部资源。
  @override
  Future<void> write(JournalDraft draft) async {
    writes++;
    value = JournalDraft.fromJson(draft.toJson());
  }
}

/// 从 [tester] 借用当前可见编辑器状态。
EditorState _state(WidgetTester tester) =>
    tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;

/// 验证初始模式永久固定，首页分别进入编辑/只读页，预览不提交数据。
void main() {
  test(
    'read-only controller refuses transactions, dates and all save paths',
    () async {
      final store = _Store();
      final journal = await LocalJournalController.open(
        store: store,
        readOnly: true,
      );
      final state = journal.editor.editorState;
      final before = jsonEncode(state.document.toJson());
      expect(state.editable, isFalse);
      expect(journal.autoSave, isFalse);
      journal.setDate('2026-10-20');
      // 模拟视图意外改变权限；控制器的固定权限仍必须拒绝写入。
      state.editable = true;
      await state.apply(
        state.transaction..insertText(state.getNodeAtPath([0, 0])!, 0, '不应写入'),
      );
      expect(jsonEncode(state.document.toJson()), before);
      expect(journal.date, '2026-10-29');
      expect(await journal.flush(), isTrue);
      await journal.close();
      expect(store.writes, 0);
    },
  );

  testWidgets(
    'preview has no editing controls and never saves on exit or background',
    (tester) async {
      final store = _Store();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => LocalJournalPage(
                    store: store,
                    mode: JournalPageMode.preview,
                  ),
                ),
              ),
              child: const Text('打开预览'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开预览'));
      await tester.pumpAndSettle();
      expect(_state(tester).editable, isFalse);
      expect(find.byKey(const ValueKey('journal-preview')), findsNothing);
      expect(find.byKey(const ValueKey('journal-save')), findsNothing);
      expect(find.byTooltip('撤销'), findsNothing);
      expect(find.byTooltip('重做'), findsNothing);
      expect(
        tester
            .widget<JournalSurface>(find.byType(JournalSurface))
            .keyboardActions,
        isEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('journal-date')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('journal-calendar')), findsNothing);
      _state(tester).selection = Selection.collapsed(Position(path: [0, 0]));
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor-mobile-toolbar')), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journal-back')));
      await tester.pumpAndSettle();
      expect(find.byType(LocalJournalPage), findsNothing);
      expect(store.writes, 0);
    },
  );

  testWidgets(
    'changing a mounted preview mode cannot unlock the existing page',
    (tester) async {
      final store = _Store();
      await tester.pumpWidget(
        MaterialApp(
          home: LocalJournalPage(store: store, mode: JournalPageMode.preview),
        ),
      );
      await tester.pumpAndSettle();
      final state = _state(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: LocalJournalPage(store: store, mode: JournalPageMode.edit),
        ),
      );
      await tester.pumpAndSettle();
      expect(state.editable, isFalse);
      expect(find.byKey(const ValueKey('journal-save')), findsNothing);
      expect(find.text('宿主会话已变化，请关闭后重新打开'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(store.writes, 0);
    },
  );

  testWidgets(
    'home exposes separate preview and edit routes for the same API record',
    (tester) async {
      await tester.pumpWidget(const OfflineExampleApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('open-daily-guidance')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('preview-daily-guidance')),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('preview-daily-guidance')));
        await rootBundle.loadString('文档完整数据结构.json');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(
        tester.widget<LocalJournalPage>(find.byType(LocalJournalPage)).mode,
        JournalPageMode.preview,
      );
      expect(_state(tester).editable, isFalse);
      expect(
        tester
            .widget<LocalJournalPage>(find.byType(LocalJournalPage))
            .hostServices
            .mentionAvatarBuilder,
        isNotNull,
      );
      expect(find.byKey(const ValueKey('journal-save')), findsNothing);
      expect(
        find.byKey(const ValueKey('journal-preview-user')),
        findsOneWidget,
      );
      expect(find.text('示例团队 · 前端开发'), findsOneWidget);
      final before = jsonEncode(_state(tester).document.toJson());
      await tester.tap(find.byKey(const ValueKey('journal-back')));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-daily-guidance')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LocalJournalPage>(find.byType(LocalJournalPage)).mode,
        JournalPageMode.edit,
      );
      expect(_state(tester).editable, isTrue);
      expect(
        tester
            .widget<LocalJournalPage>(find.byType(LocalJournalPage))
            .hostServices
            .mentionAvatarBuilder,
        isNotNull,
      );
      expect(jsonEncode(_state(tester).document.toJson()), before);
      expect(find.byKey(const ValueKey('journal-save')), findsOneWidget);
      expect(find.byKey(const ValueKey('journal-preview-user')), findsNothing);
      expect(find.byKey(const ValueKey('journal-preview')), findsNothing);
      final record =
          jsonDecode(File('文档完整数据结构.json').readAsStringSync()) as Map;
      expect(
        find.text(record['orientType'] == 'RESULT' ? '今日成果' : '今日导向'),
        findsNWidgets(2),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
