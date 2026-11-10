import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 验证桌面导入的任务提及在真实编辑段落中的布局、配色与操作菜单。
void main() {
  testWidgets('长任务引用自然换行，选区、点击、删除和撤销保留单个原子', (tester) async {
    const before = '前面的正文';
    const after = '后';
    const title = '这是一个很长的任务引用标题需要自然换行显示';
    final node = BlockCraftJsonCodec.decodeBlock({
      'id': 'inline-task',
      'flavour': 'todo',
      'nodeType': 'editable',
      'props': <String, dynamic>{},
      'meta': <String, dynamic>{},
      'children': [
        {'insert': before},
        {
          'insert': {'mention': title},
          'attributes': {'mentionType': 'task', 'mentionId': 'task-1'},
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
            width: 360,
            child: ColoredBox(
              color: const Color(0xFF0D2038),
              child: DocumentEditorView(
                editorState: controller.editorState,
                configuration: EditorViewConfiguration(
                  style: (_, style) => style.copyWith(
                    textStyleConfiguration: const TextStyleConfiguration(
                      text: TextStyle(fontSize: 16, color: Color(0xFFE9FBFF)),
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
    TextStyle? taskStyle;
    render.text.visitChildren((span) {
      if (span is TextSpan && span.text?.endsWith(title) == true) {
        taskStyle = span.style;
      }
      return true;
    });
    final colors = taskStyle!;
    expect(find.byIcon(LucideIcons.clipboardList), findsOneWidget);
    expect(colors.backgroundColor, Colors.transparent);
    expect(colors.decoration, TextDecoration.none);
    final ink = colors.color!.computeLuminance();
    final surface = const Color(0xFF0D2038).computeLuminance();
    expect((ink + .05) / (surface + .05), greaterThanOrEqualTo(4.5));

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
    expect(find.text('打开任务详情'), findsOneWidget);
    expect(find.text('切换为卡片视图'), findsNothing);
    await tester.tap(find.text('打开任务详情'));
    await tester.pumpAndSettle();
    expect(events.single.id, 'task-1');
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
