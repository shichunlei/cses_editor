import 'package:cses_offline_example/daily_guidance/ui/company_journal_poster.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/file_journal_store.dart';
import 'package:cses_offline_example/daily_guidance/guidance_entries.dart';
import 'package:cses_offline_example/daily_guidance/journal_image_actions.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 验证试点页面的实际输入、动态栏目、落盘、重开及完整分享 PNG。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'HFYS V2 edits on paper and shares the saved long document',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp('hfys-pilot-');
      addTearDown(() => directory.delete(recursive: true));
      const person = CollabMentionUser(id: 'hfys-test', name: '示例伙伴');
      const scope = 'hfys-pilot-test';
      final imageActions = _TestImageActions();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => LocalJournalPage(
                        store: FileJournalStore(
                          directory: directory,
                          scope: scope,
                        ),
                        storageScope: scope,
                        currentUser: person,
                        poster: CompanyJournalPoster.hfysV2,
                        imageActions: imageActions,
                        hostServices: CollabHostServices(
                          pickMentionUser:
                              (_, {required keyword, required canEdit}) async =>
                                  canEdit.value ? person : null,
                        ),
                      ),
                    ),
                  ),
                  child: const Text('打开试点'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开试点'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hfys-v2-header')), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      final actions = find.byKey(
        const ValueKey('journal-poster-floating-actions'),
      );
      expect(actions, findsOneWidget);
      expect(tester.getTopLeft(actions).dy, lessThan(100));
      expect(find.byTooltip('添加栏目'), findsNothing);

      final state = _editor(tester);
      expect(state.document.root.children, hasLength(1));
      final record = state.getNodeAtPath([0, 0])!;
      final recordLines = find.byKey(ValueKey('journal-lines-${record.id}'));
      await tester.ensureVisible(recordLines);
      await tester.tapAt(
        tester.getTopLeft(recordLines) +
            Offset(2, tester.getSize(recordLines).height / 2),
      );
      await tester.pumpAndSettle();
      expect(state.selection?.start.path, record.path);
      final longText = List.filled(45, '模板内直接记录今天的重点与行动。').join();
      await state.apply(state.transaction..insertText(record, 0, longText));
      await tester.pumpAndSettle();

      for (final (action, section, content) in [
        ('reflection', 'reflection', '今日感悟'),
        ('self-check', 'self-check', '自检完成'),
      ]) {
        await _add(tester, 'guidance-add-$action');
        final node = state.document.root.children
            .firstWhere((node) => node.attributes['section'] == section)
            .children
            .first;
        await state.apply(state.transaction..insertText(node, 0, content));
        await tester.pumpAndSettle();
      }

      for (final kind in ['help', 'pilot']) {
        await _add(tester, 'guidance-action-$kind');
        final entry = state.document.root.children
            .expand((section) => section.children)
            .singleWhere(
              (node) => node.attributes[guidanceEntryAttribute] == kind,
            );
        expect(entry.delta!.toJson().toString(), contains(person.id));
      }

      await _save(tester);
      await tester.pumpAndSettle();
      expect(state.editable, isFalse);
      expect(await File('${directory.path}/$scope.json').exists(), isTrue);
      final saved = state.document.toJson();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('journal-share')));
      final image = find.byKey(const ValueKey('journal-share-image'));
      for (var frame = 0; frame < 120 && image.evaluate().isEmpty; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(image, findsOneWidget);
      final bytes = (tester.widget<Image>(image).image as MemoryImage).bytes;
      final decoded = await ui.instantiateImageCodec(bytes);
      final raster = (await decoded.getNextFrame()).image;
      try {
        final logicalHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(raster.height / 2, greaterThan(logicalHeight));
        final pixels = (await raster.toByteData())!;
        // 深色画布贯穿图底，包含撕纸之后的品牌页脚。
        final lastRow = (raster.height - 4) * raster.width * 4;
        expect(pixels.getUint32(lastRow), 0x162124ff);
      } finally {
        raster.dispose();
        decoded.dispose();
      }

      await tester.tap(find.byKey(const ValueKey('journal-share-save')));
      await tester.pumpAndSettle();
      expect(imageActions.target, JournalImageTarget.save);
      expect(imageActions.bytes, same(bytes));
      if (const bool.fromEnvironment('HFYS_DEVICE_SCREENSHOT')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('hfys-v2-share-preview');
      }

      await tester.tap(find.byKey(const ValueKey('journal-share-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journal-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开试点'));
      await tester.pumpAndSettle();
      final reopened = _editor(tester);
      expect(reopened.editable, isTrue);
      expect(reopened.document.toJson(), saved);
      final paragraph = reopened.getNodeAtPath([0, 0])!;
      await reopened.apply(
        reopened.transaction..insertText(paragraph, 0, '重开后继续编辑。'),
      );
      await tester.pumpAndSettle();
      expect(paragraph.delta!.toPlainText(), startsWith('重开后继续编辑。'));
      await _save(tester);
      await tester.pumpAndSettle();
      expect(reopened.editable, isFalse);
      await tester.tap(find.byKey(const ValueKey('journal-back')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// 从 [tester] 的当前页面借用编辑状态，控制器由页面释放。
EditorState _editor(WidgetTester tester) =>
    tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;

/// 在 [tester] 的键盘横向菜单执行 [action]，并等待业务事务完成。
Future<void> _add(WidgetTester tester, String action) async {
  final state = _editor(tester);
  final node = state.document.root.children.first.children.first;
  final selection = state.updateSelectionWithReason(
    Selection.collapsed(Position(path: node.path, offset: node.delta!.length)),
    reason: SelectionUpdateReason.uiEvent,
  );
  await tester.pump(const Duration(milliseconds: 300));
  await selection;
  await tester.pumpAndSettle();
  final toolbar = find.byKey(const ValueKey('editor-mobile-toolbar'));
  expect(toolbar, findsOneWidget);
  expect(
    find.byKey(const ValueKey('journal-save')).hitTestable(),
    findsOneWidget,
  );
  final menu = find.descendant(of: toolbar, matching: find.byType(ListView));
  final target = find.byKey(ValueKey('editor-keyboard-host-$action'));
  await tester.drag(menu, const Offset(1000, 0));
  await tester.pumpAndSettle();
  for (
    var index = 0;
    index < 18 && target.hitTestable().evaluate().isEmpty;
    index++
  ) {
    await tester.drag(menu, const Offset(-120, 0));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// 收起 [tester] 当前编辑器的键盘，通过顶部悬浮入口显式保存。
Future<void> _save(WidgetTester tester) async {
  _editor(tester).service.keyboardService?.closeKeyboard();
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('journal-save')));
}

/// 捕获宿主收到的图片，测试时不弹出系统应用或文件选择器。
class _TestImageActions extends JournalImageActions {
  /// 收到的导出目标。
  JournalImageTarget? target;

  /// 收到的原始 PNG。
  Uint8List? bytes;

  /// 记录借用的 [png] 与 [target]，异步模拟平台接收成功。
  @override
  Future<bool> perform(Uint8List png, JournalImageTarget target) async {
    this.target = target;
    bytes = png;
    return true;
  }
}
