import 'dart:convert';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_editor/src/editor/collab_inline_entity_mention.dart';
import 'package:cses_editor/src/ui/modal/collab_modal_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证实体引用面板的标题省略、详情参数及按类型显示的删除动作；文档引用可撤销删除。
void main() {
  for (final kind in ['meeting', 'task', 'doc']) {
    for (final title in ['', '短标题', '很长的引用名称需要单行省略显示且不能撑高弹窗标题\n第二行仍属于原始名称']) {
      testWidgets('$kind 面板标题单行省略 title=$title', (tester) async {
        final long = title.contains('\n');
        tester.view.physicalSize = Size(long ? 280 : 320, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final events = <CollabMentionTap>[];
        final node = BlockCraftJsonCodec.decodeBlock({
          'id': 'reference',
          'flavour': 'paragraph',
          'nodeType': 'editable',
          'props': <String, dynamic>{},
          'meta': <String, dynamic>{},
          'children': [
            {
              'insert': {'mention': title},
              'attributes': {'mentionType': kind, 'mentionId': '$kind-id'},
            },
          ],
        });
        final editor = DocumentEditorController(
          document: Document(root: pageNode(children: [node])),
          commandContext: EditorCommandContext(
            localOnly: true,
            services: CollabHostServices(onMentionTap: events.add),
          ),
        );
        final snapshot = jsonEncode(editor.editorState.document.toJson());
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(long ? 1.6 : 1)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => showCollabEntityMentionActions(
                    context,
                    editor.editorState,
                    node,
                    0,
                  ),
                  child: const Text('打开引用'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开引用'));
        await tester.pumpAndSettle();
        final kindName = switch (kind) {
          'meeting' => '会议',
          'task' => '任务',
          _ => '文档',
        };
        final displayed = title.isEmpty ? '未命名$kindName' : title;
        final heading = find.descendant(
          of: find.byType(CollabModalHeader),
          matching: find.text(displayed),
        );
        expect(heading, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: heading, matching: find.byType(RichText)),
        );
        expect(paragraph.maxLines, 1);
        expect(paragraph.softWrap, isFalse);
        expect(paragraph.overflow, TextOverflow.ellipsis);
        expect(paragraph.didExceedMaxLines, long);
        expect(find.byTooltip('关闭'), findsOneWidget);
        expect(find.text('删除$kindName'), findsOneWidget);
        await tester.tap(find.text('打开$kindName详情'));
        await tester.pumpAndSettle();
        expect(events.single.id, '$kind-id');
        expect(events.single.name, title);
        expect(jsonEncode(editor.editorState.document.toJson()), snapshot);

        if (kind == 'doc' && title == '短标题') {
          await tester.tap(find.text('打开引用'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('删除文档'));
          await tester.pumpAndSettle();
          expect(node.delta!.toPlainText(), isEmpty);
          expect(events, hasLength(1));
          editor.editorState.undoManager.undo();
          await tester.pumpAndSettle();
          expect(jsonEncode(editor.editorState.document.toJson()), snapshot);
        }

        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(editor.close);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
