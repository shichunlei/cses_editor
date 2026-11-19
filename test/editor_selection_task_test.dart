import 'dart:async';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 验证真实划词菜单、任务回执替换、撤销及范围失效。
void main() {
  for (final outcome in ['created', 'cancelled', 'changed']) {
    testWidgets('划词创建任务 $outcome', (tester) async {
      final reply = Completer<CollabTaskReference?>();
      final opened = <CollabMentionTap>[];
      final feedback = <String>[];
      final services =
          CollabHostServices(
            createTaskFromSelection:
                (_, {required initialTitle, required canEdit}) {
                  expect(initialTitle, '客户反馈');
                  expect(canEdit.value, isTrue);
                  return reply.future;
                },
            onTaskMentionTap: opened.add,
            showFeedback: feedback.add,
          ).withMentionUserPicker(
            (_, {required keyword, required canEdit}) async => null,
          );
      final original = Delta()
        ..insert('跟进')
        ..insert('客户反馈', attributes: {'bold': true})
        ..insert('及后续安排');
      final node = paragraphNode(delta: original);
      final controller = DocumentEditorController(
        document: Document(root: pageNode(children: [node])),
        commandContext: EditorCommandContext(
          localOnly: true,
          services: services,
        ),
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
        startOffset: 2,
        endOffset: 6,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('创建任务'));
      await tester.pumpAndSettle();

      if (outcome == 'changed') {
        await editor.apply(editor.transaction..insertText(node, 0, '新增'));
        await tester.pumpAndSettle();
      }
      final beforeReceipt = node.delta!.toJson();
      reply.complete(
        outcome == 'cancelled'
            ? null
            : const CollabTaskReference(taskId: 'task-42', title: '回访客户'),
      );
      await tester.pumpAndSettle();

      if (outcome == 'created') {
        expect(BlockCraftJsonCodec.encodeInline(node.delta!), [
          {'insert': '跟进'},
          {
            'insert': {'mention': '回访客户'},
            'attributes': {'mentionId': 'task-42', 'mentionType': 'task'},
          },
          {'insert': '及后续安排'},
        ]);
        expect(find.byIcon(LucideIcons.clipboardList), findsOneWidget);
        await tester.tap(find.byIcon(LucideIcons.clipboardList));
        await tester.pumpAndSettle();
        await tester.tap(find.text('打开任务详情'));
        await tester.pumpAndSettle();
        expect(opened.single.type, CollabMentionType.task);
        expect(opened.single.id, 'task-42');
        editor.undoManager.undo();
        await tester.pumpAndSettle();
        expect(node.delta!.toJson(), original.toJson());
      } else {
        expect(node.delta!.toJson(), beforeReceipt);
      }
      expect(feedback, outcome == 'changed' ? ['任务已创建，未能添加到正文'] : isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.runAsync(controller.close);
      expect(tester.takeException(), isNull);
    });
  }
}
