import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_editor/src/model/collab_image.dart';
import 'package:cses_editor/src/ui/modal/editor_resource_scope.dart'
    show EditorResourceView;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 观测器隔离、异步 data 图片首帧和静态媒体的公共消费契约。
void main() {
  testWidgets('状态同步登记、帧后通知，换作用域及退出不残留凭据', (tester) async {
    final first = EditorResourceTracker();
    final second = EditorResourceTracker();
    var calls = 0;
    first.addListener(() => calls++);
    await tester.pumpWidget(
      EditorResourceScope(
        tracker: first,
        child: const EditorResourceView(
          status: EditorResourceStatus.loading,
          child: SizedBox(),
        ),
      ),
    );
    expect(first.value, isFalse);
    expect(calls, 1);
    await tester.pumpWidget(
      EditorResourceScope(
        tracker: second,
        child: const EditorResourceView(
          status: EditorResourceStatus.failed,
          child: SizedBox(),
        ),
      ),
    );
    expect(first.value, isTrue);
    expect(second.failed, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(second.value, isTrue);
    first.dispose();
    second.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final svg in [false, true]) {
    for (final broken in [false, true]) {
      testWidgets('data 图片必须真实解码，svg=$svg broken=$broken', (tester) async {
        final tracker = EditorResourceTracker();
        final controller = DocumentEditorController(
          document: Document(
            root: pageNode(
              children: [
                Node(
                  type: ImageBlockKeys.type,
                  attributes: {
                    ImageBlockKeys.url: svg
                        ? Uri.dataFromString(
                            broken
                                ? '<svg broken'
                                : '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><rect width="20" height="20" fill="red"/></svg>',
                            mimeType: 'image/svg+xml',
                          ).toString()
                        : broken
                        ? 'data:image/png;base64,AAAA'
                        : 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGUlEQVR4nGNgaGAgH41qHtU8qnlU88BqBgCwqMgBRRgyswAAAABJRU5ErkJggg==',
                    collabImageAttribute: const CollabImage().toJson(),
                  },
                ),
              ],
            ),
          ),
        );
        controller.editorState.editable = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: EditorResourceScope(
                  tracker: tracker,
                  staticMedia: true,
                  child: DocumentEditorView(
                    editorState: controller.editorState,
                    preview: true,
                    embeddedPreview: true,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tracker.value, isFalse);
        for (var frame = 0; frame < 8; frame++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump();
        }
        expect(tracker.failed, broken);
        expect(tracker.value, !broken);
        if (!broken && !svg) {
          final raster = find.descendant(
            of: find.byKey(const ValueKey('collab-image-box')),
            matching: find.byType(RawImage),
          );
          expect(tester.renderObject<RenderImage>(raster).image, isNotNull);
        }
        expect(controller.revision, 0);
        await tester.pumpWidget(const SizedBox());
        tracker.dispose();
        await tester.runAsync(controller.close);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('静态音视频卡不创建播放器或发起保存', (tester) async {
    final tracker = EditorResourceTracker();
    final controller = DocumentEditorController(
      document: Document(
        root: pageNode(
          children: [
            for (final type in ['audio', 'video'])
              BlockCraftJsonCodec.decodeBlock({
                'id': type,
                'flavour': type,
                'nodeType': 'void',
                'props': {'url': 'https://example.com/$type.mp4'},
                'meta': <String, dynamic>{},
                'children': [],
              }),
          ],
        ),
      ),
    );
    controller.editorState.editable = false;
    final before = controller.editorState.document.toJson();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EditorResourceScope(
              tracker: tracker,
              staticMedia: true,
              child: DocumentEditorView(
                editorState: controller.editorState,
                preview: true,
                embeddedPreview: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // 未注册播放器插件，任何初始化都会使此断言失败。
    expect(tracker.value, isTrue);
    expect(controller.revision, 0);
    expect(controller.editorState.document.toJson(), before);
    await tester.pumpWidget(const SizedBox());
    tracker.dispose();
    await tester.runAsync(controller.close);
  });
}
