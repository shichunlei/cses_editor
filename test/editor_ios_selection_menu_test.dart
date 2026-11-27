import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证 iOS 光标菜单能进入局部选区，并保留只读和 Android 的交互边界。
void main() {
  testWidgets('iOS 光标菜单选择英文词并切换到范围菜单', (tester) async {
    final node = paragraphNode(text: 'review agenda next');
    final controller = await _mount(tester, node);
    final editor = controller.editorState;
    await _showCaretMenu(tester, editor, node, 9);
    expect(find.text('粘贴'), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);
    expect(find.text('选择'), findsOneWidget);
    expect(find.text('复制'), findsNothing);
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    expect(
      editor.selection,
      Selection.single(path: node.path, startOffset: 7, endOffset: 13),
    );
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('剪切'), findsOneWidget);
    expect(find.text('选择'), findsNothing);
    expect(node.delta!.toPlainText(), 'review agenda next');
    await _unmount(tester, controller);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));

  for (final (text, offset, start, end) in [
    ('review agenda next', 0, 0, 6),
    ('review agenda next', 7, 7, 13),
    ('review agenda next', 18, 14, 18),
    // 测试引擎将此中文词边界解析为单字；菜单沿用排版器，不自行分词。
    ('你好 世界', 0, 0, 1),
  ]) {
    testWidgets(
      'iOS 词首和行尾选择 $text @$offset',
      (tester) async {
        final node = paragraphNode(text: text);
        final controller = await _mount(tester, node);
        await _showCaretMenu(tester, controller.editorState, node, offset);
        await tester.tap(find.text('选择'));
        await tester.pumpAndSettle();
        expect(
          controller.editorState.selection,
          Selection.single(path: node.path, startOffset: start, endOffset: end),
        );
        await _unmount(tester, controller);
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  for (final (text, offset) in [('', 0), ('   ', 1), ('review agenda', 6)]) {
    testWidgets(
      'iOS 空段落和空白不提供选择 $text @$offset',
      (tester) async {
        final node = paragraphNode(text: text);
        final controller = await _mount(tester, node);
        await _showCaretMenu(tester, controller.editorState, node, offset);
        expect(find.text('全选'), findsOneWidget);
        expect(find.text('选择'), findsNothing);
        expect(controller.editorState.selection!.isCollapsed, isTrue);
        await _unmount(tester, controller);
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  testWidgets('iOS 只读正文可以选择和复制但没有写操作', (tester) async {
    final node = paragraphNode(text: 'review agenda');
    final controller = await _mount(tester, node, editable: false);
    await _showCaretMenu(tester, controller.editorState, node, 9);
    expect(find.text('选择'), findsOneWidget);
    expect(find.text('粘贴'), findsNothing);
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('剪切'), findsNothing);
    expect(find.text('粘贴'), findsNothing);
    expect(find.text('创建会议'), findsNothing);
    await _unmount(tester, controller);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));

  for (final change in ['caret', 'text', 'unmount', 'editor']) {
    testWidgets(
      'iOS 旧选择菜单在 $change 后失效',
      (tester) async {
        final node = paragraphNode(text: 'review agenda next');
        final controller = await _mount(tester, node);
        final editor = controller.editorState;
        await _showCaretMenu(tester, editor, node, 9);
        final toolbar = tester.widget<AdaptiveTextSelectionToolbar>(
          find.byKey(const ValueKey('editor-selection-menu')),
        );
        final oldAction = toolbar.buttonItems!
            .singleWhere((item) => item.label == '选择')
            .onPressed!;
        DocumentEditorController? replacement;
        switch (change) {
          case 'caret':
            editor.selection = Selection.collapsed(
              Position(path: node.path, offset: 2),
            );
          case 'text':
            await editor.apply(editor.transaction..insertText(node, 0, 'new '));
          case 'unmount':
            await tester.pumpWidget(const SizedBox());
          case 'editor':
            replacement = await _mount(
              tester,
              paragraphNode(text: 'another document'),
            );
        }
        final before = editor.selection;
        oldAction();
        await tester.pumpAndSettle();
        expect(editor.selection, before);
        if (replacement != null) {
          expect(replacement.editorState.selection, isNull);
          await _unmount(tester, replacement);
        }
        await _unmount(tester, controller);
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  for (final kind in ['meeting', 'task', 'latex']) {
    testWidgets(
      'iOS 选择 $kind 行内对象保持完整原子',
      (tester) async {
        final node = BlockCraftJsonCodec.decodeBlock({
          'id': 'selection-$kind',
          'flavour': 'paragraph',
          'nodeType': 'editable',
          'props': <String, dynamic>{},
          'meta': <String, dynamic>{},
          'children': [
            {'insert': 'before '},
            if (kind == 'latex')
              {
                'insert': {'latex': 'x+1'},
              }
            else
              {
                'insert': {'mention': '完整引用标题'},
                'attributes': {'mentionType': kind, 'mentionId': '$kind-1'},
              },
            {'insert': ' after'},
          ],
        });
        final controller = await _mount(tester, node);
        final original = node.delta!.toJson();
        await _showCaretMenu(tester, controller.editorState, node, 7);
        await tester.tap(find.text('选择'));
        await tester.pumpAndSettle();
        expect(
          controller.editorState.selection,
          Selection.single(path: node.path, startOffset: 7, endOffset: 8),
        );
        expect(node.delta!.toJson(), original);
        await _unmount(tester, controller);
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  testWidgets(
    'Android 光标菜单不增加选择入口',
    (tester) async {
      final node = paragraphNode(text: 'review agenda');
      final controller = await _mount(tester, node);
      await _showCaretMenu(tester, controller.editorState, node, 9);
      expect(find.text('粘贴'), findsOneWidget);
      expect(find.text('全选'), findsOneWidget);
      expect(find.text('选择'), findsNothing);
      controller.editorState.selection = Selection.single(
        path: node.path,
        startOffset: 7,
        endOffset: 13,
      );
      await tester.pumpAndSettle();
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('剪切'), findsOneWidget);
      await _unmount(tester, controller);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  for (final kind in ['会议', '任务']) {
    testWidgets(
      'iOS 选择后的创建$kind接收局部原文',
      (tester) async {
        final titles = <String>[];
        final services = CollabHostServices(
          createMeetingFromText:
              (_, {required initialTitle, required canEdit}) async {
                titles.add(initialTitle);
                return null;
              },
          createTaskFromSelection:
              (_, {required initialTitle, required canEdit}) async {
                titles.add(initialTitle);
                return null;
              },
          onMentionTap: (_) {},
        );
        final node = paragraphNode(text: 'review agenda next');
        final controller = await _mount(tester, node, services: services);
        await _showCaretMenu(tester, controller.editorState, node, 9);
        expect(titles, isEmpty);
        await tester.tap(find.text('选择'));
        await tester.pumpAndSettle();
        // Cupertino 可能将业务按钮放入后续页，直接调用实际菜单项以核对业务契约。
        final toolbar = tester.widget<AdaptiveTextSelectionToolbar>(
          find.byKey(const ValueKey('editor-selection-menu')),
        );
        toolbar.buttonItems!
            .singleWhere((item) => item.label == '创建$kind')
            .onPressed!();
        await tester.pumpAndSettle();
        expect(titles, ['agenda']);
        expect(node.delta!.toPlainText(), 'review agenda next');
        await _unmount(tester, controller);
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }
}

/// 在 [tester] 中挂载包含 [node] 的真实编辑器；返回的会话由测试负责释放。
/// [editable] 默认为 true，false 保留只读选区但关闭写入与快捷栏。
/// [services] 默认空宿主端口；非空时由测试借用以记录业务回调，不访问外部应用。
Future<DocumentEditorController> _mount(
  WidgetTester tester,
  Node node, {
  bool editable = true,
  CollabHostServices services = const CollabHostServices(),
}) async {
  final controller = DocumentEditorController(
    document: Document(root: pageNode(children: [node])),
    commandContext: EditorCommandContext(localOnly: true, services: services),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DocumentEditorView(
          editorState: controller.editorState,
          editable: editable,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// 将借用 [editor] 的光标放在 [node] 的 UTF-16 [offset]，重复点击通知触发真实菜单。
/// [tester] 等待布局与浮层完成，不创建另一套菜单或替代选区服务。
Future<void> _showCaretMenu(
  WidgetTester tester,
  EditorState editor,
  Node node,
  int offset,
) async {
  final caret = Selection.collapsed(Position(path: node.path, offset: offset));
  for (var i = 0; i < 2; i++) {
    final update = editor.updateSelectionWithReason(
      caret,
      reason: SelectionUpdateReason.uiEvent,
      customSelectionType: SelectionType.inline,
      extraInfo: null,
    );
    await tester.pumpAndSettle();
    await update;
  }
}

/// 从 [tester] 卸载视图并等待浮层清理，然后释放测试拥有的 [controller]。
Future<void> _unmount(
  WidgetTester tester,
  DocumentEditorController controller,
) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.runAsync(controller.close);
  expect(tester.takeException(), isNull);
}
