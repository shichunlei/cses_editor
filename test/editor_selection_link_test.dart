import 'dart:async';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证宿主结果仍受原文、权限和验证规则保护，未注入时内置界面可用。
void main() {
  for (final outcome in ['非法回执', '正文变化', '权限撤销后恢复']) {
    testWidgets('拒绝文字链接的$outcome', (tester) async {
      final pending = Completer<String?>();
      final services =
          CollabHostServices(
            editTextLink:
                (
                  _, {
                  required initialUrl,
                  required canRemove,
                  required validate,
                }) {
                  expect(initialUrl, isEmpty);
                  expect(canRemove, isFalse);
                  expect(validate('https://example.com'), isNull);
                  expect(validate('ftp://example.com'), isNotNull);
                  return pending.future;
                },
            showFeedback: (_) {},
          ).withMentionUserPicker(
            (_, {required keyword, required canEdit}) async => null,
          );
      final (controller, node) = await _mountEditor(tester, services);
      final editor = controller.editorState;

      if (outcome == '正文变化') {
        await editor.apply(editor.transaction..insertText(node, 0, '新正文'));
      }
      if (outcome == '权限撤销后恢复') {
        editor.editable = false;
        editor.editable = true;
      }
      final original = node.delta!.toJson();
      pending.complete(
        outcome == '非法回执' ? 'ftp://example.com' : 'https://example.com',
      );
      await tester.pumpAndSettle();
      expect(node.delta!.toJson(), original);
      await _closeEditor(tester, controller);
    });
  }

  testWidgets('缺省表单继续允许取消或保存文字链接', (tester) async {
    final (controller, node) = await _mountEditor(
      tester,
      const CollabHostServices(),
    );
    expect(find.text('文字链接'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('editor-text-link-input')),
      'https://example.com',
    );
    await tester.tap(find.byKey(const ValueKey('editor-text-link-save')));
    await tester.pumpAndSettle();
    expect(
      node.delta!.first.attributes?[AppFlowyRichTextKeys.href],
      'https://example.com',
    );
    final editor = controller.editorState;
    editor.undoManager.undo();
    await tester.pumpAndSettle();
    expect(node.delta!.first.attributes?[AppFlowyRichTextKeys.href], isNull);
    await _closeEditor(tester, controller);
  });
}

/// 在 [tester] 中装配借用 [services] 的单段编辑器，并通过真实划词菜单打开链接。
/// 返回的控制器由测试负责关闭，正文节点保持在真实文档中。
Future<(DocumentEditorController, Node)> _mountEditor(
  WidgetTester tester,
  CollabHostServices services,
) async {
  final node = paragraphNode(delta: Delta()..insert('划词链接'));
  final controller = DocumentEditorController(
    document: Document(root: pageNode(children: [node])),
    commandContext: EditorCommandContext(localOnly: true, services: services),
  );
  final editor = controller.editorState;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: DocumentEditorView(editorState: editor)),
    ),
  );
  await tester.pumpAndSettle();
  editor.selection = Selection.single(
    path: node.path,
    startOffset: 0,
    endOffset: 4,
  );
  await tester.pumpAndSettle();
  if (find.text('链接').evaluate().isEmpty) {
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('链接'));
  await tester.pumpAndSettle();
  return (controller, node);
}

/// 在 [tester] 中卸载正文后等待 [controller] 的真实关闭任务。
Future<void> _closeEditor(
  WidgetTester tester,
  DocumentEditorController controller,
) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.runAsync(controller.close);
  expect(tester.takeException(), isNull);
}
