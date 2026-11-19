import 'dart:ui' as ui;

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证公开嵌入预览在无界高度内完整布局，不创建可写输入服务。
void main() {
  testWidgets(
    'embedded preview rejects writable sessions without leaking resources',
    (tester) async {
      final controller = DocumentEditorController();
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentEditorView(
            editorState: controller.editorState,
            preview: true,
            embeddedPreview: true,
          ),
        ),
      );
      expect(tester.takeException(), isA<StateError>());
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(controller.close);
      expect(tester.takeException(), isNull);
    },
  );
  for (final count in [1, 80]) {
    testWidgets('embedded preview renders all $count rows into a full PNG', (
      tester,
    ) async {
      final controller = DocumentEditorController(
        document: Document(
          root: pageNode(
            children: [
              for (var i = 0; i < count; i++)
                paragraphNode(text: 'row $i full content'),
            ],
          ),
        ),
      );
      final state = controller.editorState..editable = false;
      final before = state.document.toJson();
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                  width: 340,
                  child: DocumentEditorView(
                    editorState: state,
                    preview: true,
                    embeddedPreview: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(EditableText), findsNothing);
      expect(state.service.keyboardService, isNull);
      expect(state.service.selectionServiceKey.currentState, isNull);
      expect(state.selection, isNull);
      final height = tester.getSize(find.byKey(boundaryKey)).height;
      if (count > 1) expect(height, greaterThan(600));
      expect(find.byKey(state.document.root.children.last.key), findsWidgets);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1),
      );
      expect(image!.height, height.ceil());
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      expect(bytes!.lengthInBytes, greaterThan(100));
      image.dispose();
      expect(state.document.toJson(), before);
      expect(controller.revision, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(controller.close);
      expect(tester.takeException(), isNull);
    });
  }
}
