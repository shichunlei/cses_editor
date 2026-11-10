import 'dart:convert';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_editor/src/editor/collab_inline_mention.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// 使用真实共享人员标签验证浅色正文中的文字可读性；展示不修改正文或宿主服务。
void main() {
  for (final color in <Color?>[
    Colors.white,
    const Color(0xffE9FBFF),
    const Color(0xff333333),
    null,
  ]) {
    testWidgets('人员标签前景 $color 与实际背景有可读对比度且保留文字样式', (tester) async {
      final node = paragraphNode(text: '原正文');
      final controller = DocumentEditorController(
        document: Document(root: pageNode(children: [node])),
        commandContext: const EditorCommandContext(localOnly: true),
      );
      final before = jsonEncode(controller.editorState.document.toJson());
      final style = TextStyle(
        color: color,
        fontSize: 19,
        fontWeight: FontWeight.w600,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<EditorState>.value(
            value: controller.editorState,
            child: Scaffold(
              body: CollabInlineMention(
                node: node,
                offset: 0,
                name: '验收人员',
                userId: 'person',
                style: style,
              ),
            ),
          ),
        ),
      );
      final label = tester.widget<Text>(find.text('验收人员'));
      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CollabInlineMention),
              matching: find.byType(Container),
            )
            .first,
      );
      final background = (card.decoration! as BoxDecoration).color!;
      final foreground = label.style!.color!;
      final a = foreground.computeLuminance();
      final b = background.computeLuminance();
      final contrast = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
      expect(label.style!.fontSize, 19);
      expect(label.style!.fontWeight, FontWeight.w600);
      expect(foreground, color ?? const Color(0xff2563EB));
      expect(jsonEncode(controller.editorState.document.toJson()), before);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(controller.close);
      expect(tester.takeException(), isNull);
    });
  }
}
