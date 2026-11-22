import 'dart:convert';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_editor/src/editor/collab_inline_entity_mention.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

/// 从真实正文与操作面板验证业务图标映射、默认回退、服务复制和引用原子不变。
void main() {
  for (final kind in ['meeting', 'task']) {
    for (final mode in ['custom', 'default', 'null']) {
      testWidgets('$kind 行内与底部面板共用图标 $mode', (tester) async {
        final expected = mode == 'custom'
            ? (kind == 'meeting' ? Icons.event_note : Icons.assignment)
            : (kind == 'meeting'
                  ? LucideIcons.calendarClock
                  : LucideIcons.clipboardList);
        final calls = <CollabMentionType>[];
        final events = <CollabMentionTap>[];
        final original = CollabHostServices(
          onMentionTap: events.add,
          mentionIconResolver: mode == 'default'
              ? null
              : (type) {
                  calls.add(type);
                  if (mode == 'null') return null;
                  return type == CollabMentionType.meeting
                      ? Icons.event_note
                      : Icons.assignment;
                },
        );
        final services = original.withMentionUserPicker(
          (context, {required keyword, required canEdit}) async => null,
        );
        expect(
          services.mentionIconResolver,
          same(original.mentionIconResolver),
        );
        final node = _node(kind, '这是很长的行内引用标题需要换行并保持图标一致');
        final editor = DocumentEditorController(
          document: Document(root: pageNode(children: [node])),
          commandContext: EditorCommandContext(
            localOnly: true,
            services: services,
          ),
        );
        final snapshot = jsonEncode(editor.editorState.document.toJson());
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 240,
                child: DocumentEditorView(editorState: editor.editorState),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(expected), findsOneWidget);
        final rich = find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('保持图标一致'),
        );
        final paragraph = tester.renderObject<RenderParagraph>(rich);
        final plain = paragraph.text.toPlainText();
        final last = plain.indexOf('保持图标一致') + '保持图标一致'.length - 1;
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: last, extentOffset: last + 1),
            )
            .single
            .toRect();
        await tester.tapAt(paragraph.localToGlobal(box.center));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byIcon(expected),
          ),
          findsOneWidget,
        );
        if (mode != 'default') {
          expect(calls, isNotEmpty);
          expect(calls.every((type) => type.name == kind), isTrue);
        }
        await tester.tap(find.text(kind == 'meeting' ? '打开会议详情' : '打开任务详情'));
        await tester.pumpAndSettle();
        expect(events.single.id, '$kind-id');
        expect(events.single.name, '这是很长的行内引用标题需要换行并保持图标一致');
        expect(jsonEncode(editor.editorState.document.toJson()), snapshot);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(editor.close);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$kind 独立 WidgetSpan 路径也读取同一图标端口', (tester) async {
      final node = _node(kind, '引用');
      final editor = DocumentEditorController(
        document: Document(root: pageNode(children: [node])),
        commandContext: EditorCommandContext(
          localOnly: true,
          services: CollabHostServices(mentionIconResolver: (_) => Icons.flag),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<EditorState>.value(
            value: editor.editorState,
            child: Scaffold(
              body: CollabInlineEntityMention(
                node: node,
                offset: 0,
                name: '引用',
                entityType: kind,
                style: const TextStyle(fontSize: 19, color: Colors.black),
              ),
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.flag));
      expect(icon.size, 19);
      expect(icon.color, const Color(0xFF1D4ED8));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(editor.close);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('人员和文档不调用会议任务图标端口', (tester) async {
    final calls = <CollabMentionType>[];
    final editor = DocumentEditorController(
      document: Document(
        root: pageNode(children: [_node('user', '人员'), _node('doc', '文档')]),
      ),
      commandContext: EditorCommandContext(
        localOnly: true,
        services: CollabHostServices(
          mentionIconResolver: (type) {
            calls.add(type);
            return Icons.flag;
          },
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentEditorView(editorState: editor.editorState),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.byIcon(LucideIcons.fileText), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(editor.close);
    expect(tester.takeException(), isNull);
  });
}

/// 创建 [kind] 对应的正式原子及 [title]，保留稳定 ID、前后正文与原属性供点击复核。
Node _node(String kind, String title) => BlockCraftJsonCodec.decodeBlock({
  'id': kind,
  'flavour': 'paragraph',
  'nodeType': 'editable',
  'props': <String, dynamic>{},
  'meta': <String, dynamic>{},
  'children': [
    {'insert': '前文'},
    {
      'insert': {'mention': title},
      'attributes': {'mentionType': kind, 'mentionId': '$kind-id'},
    },
    {'insert': '后文'},
  ],
});
