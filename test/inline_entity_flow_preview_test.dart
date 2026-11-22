import 'dart:convert';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 在同段混排中验证两种预览布局的多引用换行、点击映射及静态截图一致性。
void main() {
  for (final embedded in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('会议任务混排自然换行并保持只读 embedded=$embedded dark=$dark', (
        tester,
      ) async {
        const meeting = '会议名称很长需要跨行显示并完整保留后半段';
        const task = '任务名称同样很长也需要跨行显示并完整保留';
        const prefix = '开头🙂';
        const between = '中间正文';
        const suffix = '末尾';
        final node = BlockCraftJsonCodec.decodeBlock({
          'id': 'mixed',
          'flavour': 'paragraph',
          'nodeType': 'editable',
          'props': <String, dynamic>{},
          'meta': <String, dynamic>{},
          'children': [
            {'insert': prefix},
            {
              'insert': {'mention': meeting},
              'attributes': {
                'mentionType': 'meeting',
                'mentionId': 'meeting-id',
              },
            },
            {'insert': between},
            {
              'insert': {'mention': task},
              'attributes': {'mentionType': 'task', 'mentionId': 'task-id'},
            },
            {'insert': suffix},
          ],
        });
        final events = <CollabMentionTap>[];
        final editor = DocumentEditorController(
          document: Document(root: pageNode(children: [node])),
          commandContext: EditorCommandContext(
            localOnly: true,
            services: CollabHostServices(
              mentionIconResolver: (type) => type == CollabMentionType.meeting
                  ? Icons.event_note
                  : Icons.assignment,
              onMeetingMentionTap: events.add,
              onTaskMentionTap: events.add,
            ),
          ),
        );
        editor.editorState
          ..editable = false
          ..transactionGuard = (_) => false;
        final snapshot = jsonEncode(editor.editorState.document.toJson());
        final tracker = EditorResourceTracker();
        final foreground = dark ? Colors.white : Colors.black;

        /// 在 [staticMedia] 用途下重建同一编辑器视图，保留显示尺寸并禁用截图交互。
        Future<void> mount({bool staticMedia = false}) async {
          final view = DocumentEditorView(
            editorState: editor.editorState,
            preview: true,
            embeddedPreview: embedded,
            previewMentionInteractions: true,
            configuration: EditorViewConfiguration(
              style: (_, style) => style.copyWith(
                textStyleConfiguration: TextStyleConfiguration(
                  text: TextStyle(fontSize: 16, color: foreground),
                ),
              ),
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 240,
                    child: EditorResourceScope(
                      tracker: tracker,
                      staticMedia: staticMedia,
                      child: embedded
                          ? SingleChildScrollView(child: view)
                          : view,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await mount();
        final rich = find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains(meeting),
        );
        var render = tester.renderObject<RenderParagraph>(rich);
        final plain = render.text.toPlainText();
        expect(plain, contains('$meeting$between'));
        expect(plain, endsWith('$task$suffix'));
        expect(find.byIcon(Icons.event_note), findsOneWidget);
        expect(find.byIcon(Icons.assignment), findsOneWidget);
        final size = render.size;

        /// 返回当前排版中 UTF-16 [offset] 的字符框，不将显示偏移写入正文。
        Rect charAt(int offset) => render
            .getBoxesForSelection(
              TextSelection(baseOffset: offset, extentOffset: offset + 1),
            )
            .single
            .toRect();

        final referenceStyles = <TextStyle>[];
        render.text.visitChildren((span) {
          if (span is TextSpan &&
              (span.text?.endsWith(meeting) == true ||
                  span.text?.endsWith(task) == true)) {
            referenceStyles.add(span.style!);
          }
          return true;
        });
        expect(referenceStyles, hasLength(2));
        for (final style in referenceStyles) {
          expect(
            style.color,
            dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
          );
          expect(style.backgroundColor, Colors.transparent);
          expect(style.decoration, TextDecoration.none);
        }
        for (final title in [meeting, task]) {
          final first = plain.indexOf(title);
          final last = first + title.length - 1;
          expect(charAt(last).top, greaterThan(charAt(first).top));
          for (final offset in [first, last]) {
            await tester.tapAt(render.localToGlobal(charAt(offset).center));
            await tester.pumpAndSettle();
          }
        }
        expect(events.map((e) => e.id), [
          'meeting-id',
          'meeting-id',
          'task-id',
          'task-id',
        ]);
        for (final text in [prefix, between, suffix]) {
          await tester.tapAt(
            render.localToGlobal(charAt(plain.indexOf(text)).center),
          );
          await tester.pumpAndSettle();
        }
        expect(events, hasLength(4));
        expect(find.text('打开会议详情'), findsNothing);
        expect(find.text('打开任务详情'), findsNothing);

        await mount(staticMedia: true);
        render = tester.renderObject<RenderParagraph>(rich);
        expect(render.text.toPlainText(), plain);
        expect(render.size, size);
        expect(find.byIcon(Icons.event_note), findsOneWidget);
        expect(find.byIcon(Icons.assignment), findsOneWidget);
        for (final title in [meeting, task]) {
          final last = plain.indexOf(title) + title.length - 1;
          await tester.tapAt(render.localToGlobal(charAt(last).center));
          await tester.pumpAndSettle();
        }
        expect(events, hasLength(4));
        await mount();
        render = tester.renderObject<RenderParagraph>(rich);
        await tester.tapAt(
          render.localToGlobal(charAt(plain.indexOf(meeting)).center),
        );
        await tester.pumpAndSettle();
        expect(events.last.id, 'meeting-id');
        expect(events, hasLength(5));
        expect(editor.editorState.selection, isNull);
        expect(editor.revision, 0);
        expect(jsonEncode(editor.editorState.document.toJson()), snapshot);
        expect(node.delta!.toPlainText(), '$prefix\uFFFC$between\uFFFC$suffix');
        expect(find.byType(EditableText), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(editor.close);
        tracker.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
