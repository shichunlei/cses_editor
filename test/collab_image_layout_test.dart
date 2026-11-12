import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_editor/src/model/collab_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 无外部资源的三种原始图片，分别为横图、正方形和竖图。
const _images = {
  'landscape':
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAASCAIAAAC1qksFAAAAHklEQVR4nGNgaGCgLRq1YNSCUQtGLRi1YNQCelgAAGBcIBAjUUCjAAAAAElFTkSuQmCC',
  'square':
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGUlEQVR4nGNgaGAgH41qHtU8qnlU88BqBgCwqMgBRRgyswAAAABJRU5ErkJggg==',
  'portrait':
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABIAAAAgCAIAAACQHr+mAAAAHUlEQVR4nGNgaGAgB41qG9U2qm1U26i2UW2DWRsAQOIgELKPr3kAAAAASUVORK5CYII=',
};

/// 验证图片自然高度、正方形上限和只读模式的相同布局。
void main() {
  for (final entry in _images.entries) {
    for (final preview in [false, true]) {
      testWidgets('${entry.key} preview=$preview 图片铺满宽度且高度最多为正方形', (
        tester,
      ) async {
        final node = Node(
          type: ImageBlockKeys.type,
          attributes: {
            ImageBlockKeys.url: entry.value,
            collabImageAttribute: const CollabImage().toJson(),
          },
        );
        final controller = DocumentEditorController(
          document: Document(root: pageNode(children: [node])),
        );
        final before = controller.editorState.document.toJson();
        final scroll = EditorScrollController(
          editorState: controller.editorState,
          shrinkWrap: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: DocumentEditorView(
                  editorState: controller.editorState,
                  preview: preview,
                  scrollController: scroll,
                ),
              ),
            ),
          ),
        );
        for (var frame = 0; frame < 3; frame++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        final box = find.byKey(const ValueKey('collab-image-box'));
        final image = tester.widget<Image>(
          find.descendant(of: box, matching: find.byType(Image)),
        );
        final size = tester.getSize(box);
        final expectedHeight = entry.key == 'landscape'
            ? size.width * 18 / 32
            : size.width;
        expect(size.height, closeTo(expectedHeight, .1));
        expect(image.width, size.width);
        expect(image.fit, BoxFit.cover);
        expect(controller.editorState.document.toJson(), before);
        await tester.pumpWidget(const SizedBox());
        scroll.dispose();
        await tester.runAsync(controller.close);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
