import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证真实附件及音频菜单独立读取当前会话的修改入口配置。
void main() {
  final defaults = EditorConfiguration();
  final hiddenAttachment = EditorConfiguration.document.withHost(
    showAttachmentEditAction: false,
  );
  for (final (label, configuration, attachmentEdit, audioEdit) in [
    ('默认开启', defaults, true, true),
    ('隐藏附件修改', hiddenAttachment.withHost(), false, true),
    (
      '隐藏音频修改',
      hiddenAttachment.withHost(
        showAttachmentEditAction: true,
        showAudioEditAction: false,
      ),
      true,
      false,
    ),
  ]) {
    testWidgets(label, (tester) async {
      final attachment = Node(
        type: 'attachment',
        attributes: {'url': 'https://example.com/report.pdf'},
      );
      final audio = Node(
        type: 'audio',
        attributes: {'url': 'https://example.com/recording.mp3'},
      );
      final controller = DocumentEditorController(
        document: Document(root: pageNode(children: [attachment, audio])),
        commandContext: EditorCommandContext(
          configuration: configuration,
          services: CollabHostServices(mediaUpload: _MenuUploadService()),
        ),
      );
      final state = controller.editorState;
      final before = state.document.toJson();
      final tracker = EditorResourceTracker();
      final scroll = EditorScrollController(
        editorState: state,
        shrinkWrap: true,
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EditorResourceScope(
                tracker: tracker,
                staticMedia: true,
                child: DocumentEditorView(
                  editorState: state,
                  scrollController: scroll,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final (node, name, open, edit) in [
          (attachment, '附件', '下载或打开附件', attachmentEdit),
          (audio, '音频', '在浏览器打开', audioEdit),
        ]) {
          await tester.tap(
            find.byKey(ValueKey('block-lock-menu-trigger-${node.id}')),
          );
          await tester.pumpAndSettle();
          expect(find.text('修改$name'), edit ? findsOneWidget : findsNothing);
          expect(find.text(open), findsOneWidget);
          expect(find.text('在下方插入'), findsOneWidget);
          expect(find.text('替换$name'), findsOneWidget);
          expect(find.text('删除$name'), findsOneWidget);
          if (node == audio) expect(find.text('复制链接'), findsOneWidget);
          await tester.tap(find.byTooltip('关闭'));
          await tester.pumpAndSettle();
        }
        expect(state.document.toJson(), before);
      } finally {
        await tester.pumpWidget(const SizedBox());
        scroll.dispose();
        tracker.dispose();
        await tester.runAsync(controller.close);
      }
    });
  }
}

/// 声明宿主具备替换入口，菜单测试不触发选择或上传。
class _MenuUploadService extends Fake implements EditorMediaUploadService {}
