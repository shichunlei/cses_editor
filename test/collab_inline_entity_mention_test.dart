import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 验证会议与任务提及在窄屏真实编辑段落中的换行、配色、原子选区和操作菜单。
void main() {
  for (final kind in ['task', 'meeting']) {
    for (final dark in [true, false]) {
      testWidgets('长 $kind 引用自然换行、配色与原子操作 dark=$dark', (tester) async {
        const before = '前面的正文';
        const after = '后';
        final kindName = kind == 'task' ? '任务' : '会议';
        final title = '这是一个很长的$kindName引用标题需要自然换行显示';
        final background = dark ? const Color(0xFF0D2038) : Colors.white;
        final foreground = dark ? const Color(0xFFE9FBFF) : Colors.black;
        final node = BlockCraftJsonCodec.decodeBlock({
          'id': 'inline-$kind',
          'flavour': dark ? 'todo' : 'paragraph',
          'nodeType': 'editable',
          'props': <String, dynamic>{},
          'meta': <String, dynamic>{},
          'children': [
            {'insert': before},
            {
              'insert': {'mention': title},
              'attributes': {'mentionType': kind, 'mentionId': '$kind-1'},
            },
            {'insert': after},
          ],
        });
        final events = <CollabMentionTap>[];
        final controller = DocumentEditorController(
          document: Document(root: pageNode(children: [node])),
          commandContext: EditorCommandContext(
            localOnly: true,
            services: CollabHostServices(onMentionTap: events.add),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: dark ? 360 : 240,
                child: ColoredBox(
                  color: background,
                  child: DocumentEditorView(
                    editorState: controller.editorState,
                    configuration: EditorViewConfiguration(
                      style: (_, style) => style.copyWith(
                        textStyleConfiguration: TextStyleConfiguration(
                          text: TextStyle(fontSize: 16, color: foreground),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final paragraph = find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains(title),
        );
        final render = tester.renderObject<RenderParagraph>(paragraph);
        final plain = render.text.toPlainText();
        final titleStart = plain.indexOf(title);
        final titleEnd = titleStart + title.length;

        /// Returns the laid-out box for the character at display [offset].
        TextBox boxAt(int offset) => render
            .getBoxesForSelection(
              TextSelection(baseOffset: offset, extentOffset: offset + 1),
            )
            .single;

        expect(boxAt(0).top, closeTo(boxAt(titleStart).top, .01));
        expect(boxAt(titleEnd - 1).top, greaterThan(boxAt(titleStart).top));
        expect(boxAt(titleEnd).top, closeTo(boxAt(titleEnd - 1).top, .01));
        expect(plain, endsWith('$title$after'));
        expect(node.delta!.toPlainText(), '$before\uFFFC$after');
        TextStyle? referenceStyle;
        render.text.visitChildren((span) {
          if (span is TextSpan && span.text?.endsWith(title) == true) {
            referenceStyle = span.style;
          }
          return true;
        });
        final colors = referenceStyle!;
        expect(
          find.byIcon(
            kind == 'task'
                ? LucideIcons.clipboardList
                : LucideIcons.calendarClock,
          ),
          findsOneWidget,
        );
        expect(colors.backgroundColor, Colors.transparent);
        expect(colors.decoration, TextDecoration.none);
        final ink = colors.color!.computeLuminance();
        final surface = background.computeLuminance();
        expect(
          (dark
              ? (ink + .05) / (surface + .05)
              : (surface + .05) / (ink + .05)),
          greaterThanOrEqualTo(4.5),
        );

        final selectable = node.selectable!;
        final atom = Selection.single(
          path: node.path,
          startOffset: before.length,
          endOffset: before.length + 1,
        );
        final boxes = selectable.getRectsInSelection(atom);
        expect(boxes.map((box) => box.top).toSet().length, greaterThan(1));
        final suffix = boxAt(titleEnd).toRect();
        final suffixStart = render.localToGlobal(
          Offset(suffix.left + .2, suffix.center.dy),
        );
        expect(
          selectable.getPositionInOffset(suffixStart).offset,
          before.length + 1,
        );
        final caret = selectable.getCursorRectInPosition(atom.end);
        expect(caret!.top, greaterThan(boxAt(titleStart).top));

        final lastTitlePoint = render.localToGlobal(
          boxAt(titleEnd - 1).toRect().center,
        );
        expect(selectable.getWordBoundaryInOffset(lastTitlePoint), atom);
        await tester.tapAt(lastTitlePoint);
        await tester.pumpAndSettle();
        expect(find.text('打开$kindName详情'), findsOneWidget);
        expect(
          find.text('切换为卡片视图'),
          kind == 'meeting' ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.text('打开$kindName详情'));
        await tester.pumpAndSettle();
        expect(events.single.id, '$kind-1');
        expect(events.single.name, title);

        await tester.tapAt(lastTitlePoint);
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除提及'));
        await tester.pumpAndSettle();
        expect(node.delta!.toPlainText(), '$before$after');
        controller.editorState.undoManager.undo();
        await tester.pumpAndSettle();
        expect(node.delta!.toPlainText(), '$before\uFFFC$after');
        expect(paragraph, findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.runAsync(controller.close);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
