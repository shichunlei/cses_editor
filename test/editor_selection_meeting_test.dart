import 'dart:async';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 验证真实移动划词菜单、回执写入、撤销、引用图标与会议详情分发。
void main() {
  for (final outcome in [
    'created',
    'cancelled',
    'changed',
    'rejected',
    'revoked',
  ]) {
    testWidgets('划词创建会议 $outcome', (tester) async {
      final reply = Completer<CollabMeetingReference?>();
      final events = <CollabMentionTap>[];
      final messages = <String>[];
      final titles = <String>[];
      final services =
          CollabHostServices(
            createMeetingFromText:
                (_, {required initialTitle, required canEdit}) {
                  expect(canEdit.value, isTrue);
                  titles.add(initialTitle);
                  return reply.future;
                },
            onMeetingMentionTap: events.add,
            showFeedback: messages.add,
          ).withMentionUserPicker((
            _, {
            required keyword,
            required canEdit,
          }) async {
            return null;
          });
      final original = Delta()
        ..insert('要讨论')
        ..insert(' 发布计划 ', attributes: {'bold': true})
        ..insert('明天见');
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
        startOffset: 3,
        endOffset: 9,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('创建会议'));
      await tester.pumpAndSettle();
      expect(titles, ['发布计划']);

      if (outcome == 'changed') {
        await editor.apply(editor.transaction..insertText(node, 0, '新增'));
        await tester.pumpAndSettle();
      }
      if (outcome == 'rejected') editor.transactionGuard = (_) => false;
      if (outcome == 'revoked') {
        editor.editable = false;
        editor.editable = true;
      }
      final beforeReceipt = node.delta!.toJson();
      reply.complete(
        outcome == 'cancelled'
            ? null
            : const CollabMeetingReference(meetingId: 'm-42', title: '最终主题'),
      );
      await tester.pumpAndSettle();

      if (outcome == 'created') {
        expect(BlockCraftJsonCodec.encodeInline(node.delta!), [
          {'insert': '要讨论'},
          {
            'insert': {'mention': '最终主题'},
            'attributes': {'mentionId': 'm-42', 'mentionType': 'meeting'},
          },
          {'insert': '明天见'},
        ]);
        final meetingIcon = find.byIcon(LucideIcons.calendarClock);
        expect(meetingIcon, findsOneWidget);
        // 引用标题由正文 TextSpan 自然排版，图标与各行标题共用同一原子入口。
        await tester.tap(meetingIcon);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: find.byType(BottomSheet), matching: meetingIcon),
          findsOneWidget,
        );
        await tester.tap(find.text('打开会议详情'));
        await tester.pumpAndSettle();
        expect(events.single.id, 'm-42');
        expect(events.single.type, CollabMentionType.meeting);
        editor.undoManager.undo();
        await tester.pumpAndSettle();
        expect(node.delta!.toJson(), original.toJson());
      } else {
        expect(node.delta!.toJson(), beforeReceipt);
      }
      expect(
        messages,
        const {'changed', 'rejected', 'revoked'}.contains(outcome)
            ? ['会议已创建，未能添加到正文']
            : isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.runAsync(controller.close);
      expect(tester.takeException(), isNull);
    });
  }
}
