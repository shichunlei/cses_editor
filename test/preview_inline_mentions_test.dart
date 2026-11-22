import 'dart:async';
import 'dart:convert';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 使用真实行内原子、普通预览和自然高度预览验证直接详情、只读与静态隔离。
void main() {
  for (final embedded in [true, false]) {
    for (final kind in ['meeting', 'task', 'user']) {
      testWidgets('$kind 预览直接回调 embedded=$embedded', (tester) async {
        final events = <CollabMentionTap>[];
        final editor = _editor(
          services: CollabHostServices(
            onMeetingMentionTap: events.add,
            onTaskMentionTap: events.add,
            onMentionTap: events.add,
          ),
        );
        final before = jsonEncode(editor.editorState.document.toJson());
        await _mount(tester, editor, embedded: embedded);
        await _tap(tester, 'Ref-$kind');
        expect(events, hasLength(1));
        expect(events.single.type.name, kind);
        expect(events.single.id, '$kind-id');
        expect(events.single.attributes['extension'], {'kept': true});
        expect(find.text('打开任务详情'), findsNothing);
        expect(find.text('打开会议详情'), findsNothing);
        expect(editor.editorState.selection, isNull);
        expect(editor.revision, 0);
        expect(jsonEncode(editor.editorState.document.toJson()), before);
        expect(find.byType(EditableText), findsNothing);
        await _close(tester, editor);
      });
    }
  }

  testWidgets('旧任务专用预览开关保留原面板，会议仍不放行', (tester) async {
    final events = <CollabMentionTap>[];
    final editor = _editor(
      services: CollabHostServices(onMentionTap: events.add),
    );
    await _mount(tester, editor, interactions: false, legacyTasks: true);
    await _tap(tester, 'Ref-meeting');
    expect(events, isEmpty);
    await _tap(tester, 'Ref-task');
    expect(events, isEmpty);
    expect(find.text('打开任务详情'), findsOneWidget);
    await tester.tap(find.text('打开任务详情'));
    await tester.pumpAndSettle();
    expect(events.single.id, 'task-id');
    expect(editor.revision, 0);
    await _close(tester, editor);
  });

  for (final mode in ['off', 'disabled', 'static', 'no-callback', 'empty-id']) {
    testWidgets('预览不越过 $mode 边界', (tester) async {
      final events = <CollabMentionTap>[];
      final tracker = EditorResourceTracker();
      final editor = _editor(
        id: mode == 'empty-id' ? '   ' : null,
        services: mode == 'no-callback'
            ? const CollabHostServices()
            : CollabHostServices(onMentionTap: events.add),
      );
      await _mount(
        tester,
        editor,
        enabled: mode != 'disabled',
        interactions: mode != 'off',
        tracker: tracker,
        staticMedia: mode == 'static',
      );
      for (final kind in ['meeting', 'task', 'user']) {
        await _tap(tester, 'Ref-$kind');
      }
      expect(events, isEmpty);
      expect(find.text('打开任务详情'), findsNothing);
      expect(editor.revision, 0);
      await _close(tester, editor);
      tracker.dispose();
    });
  }

  testWidgets('静态用途切换立即撤销引用命中，恢复后仍可打开', (tester) async {
    final events = <CollabMentionTap>[];
    final tracker = EditorResourceTracker();
    final editor = _editor(
      services: CollabHostServices(onMentionTap: events.add),
    );
    await _mount(tester, editor, tracker: tracker);
    await _tap(tester, 'Ref-user');
    await _mount(tester, editor, tracker: tracker, staticMedia: true);
    await _tap(tester, 'Ref-user');
    expect(events, hasLength(1));
    await _mount(tester, editor, tracker: tracker);
    await _tap(tester, 'Ref-user');
    expect(events, hasLength(2));
    await _close(tester, editor);
    tracker.dispose();
  });

  testWidgets('引用在嵌套提示块内仍可点击，普通正文不出现编辑菜单', (tester) async {
    final events = <CollabMentionTap>[];
    final editor = _editor(
      nested: true,
      services: CollabHostServices(onMentionTap: events.add),
    );
    await _mount(tester, editor);
    await _tap(tester, 'Ref-meeting');
    await _tap(tester, 'Ref-task');
    await _tap(tester, 'Ref-user');
    expect(events.map((event) => event.type.name), ['meeting', 'task', 'user']);
    expect(editor.editorState.selection, isNull);
    await _close(tester, editor);
  });

  testWidgets('详情未关闭时跨引用重复点击只派发一次，返回后可继续', (tester) async {
    final events = <CollabMentionTap>[];
    final pending = Completer<void>();
    final editor = _editor(
      services: CollabHostServices(
        onMentionTap: (event) {
          events.add(event);
          return pending.future;
        },
      ),
    );
    await _mount(tester, editor);
    await _tap(tester, 'Ref-meeting');
    await _tap(tester, 'Ref-task');
    expect(events, hasLength(1));
    pending.complete();
    await tester.pumpAndSettle();
    await _tap(tester, 'Ref-user');
    expect(events, hasLength(2));
    expect(editor.editorState.selection, isNull);
    await _close(tester, editor);
  });

  testWidgets('回调在途退出不恢复键盘、不修改正文或迟到报错', (tester) async {
    final pending = Completer<void>();
    final editor = _editor(
      services: CollabHostServices(onMentionTap: (_) => pending.future),
    );
    await _mount(tester, editor);
    await _tap(tester, 'Ref-meeting');
    await _close(tester, editor);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('回调失败报告一次并使用宿主提示，之后仍能点击', (tester) async {
    final errors = <Object>[];
    final messages = <String>[];
    var count = 0;
    final failure = StateError('detail-failed');
    final editor = _editor(
      services: CollabHostServices(
        onMentionTap: (_) async {
          count++;
          if (count == 1) throw failure;
        },
        onError: (_, error, _, _) => errors.add(error),
        showFeedback: messages.add,
      ),
    );
    await _mount(tester, editor);
    await _tap(tester, 'Ref-meeting');
    expect(errors, [failure]);
    expect(messages, ['操作失败，请重试']);
    await _tap(tester, 'Ref-meeting');
    expect(count, 2);
    expect(editor.revision, 0);
    await _close(tester, editor);
  });
}

/// 使用借用 [services] 构建只读原子文档；[id] 可覆盖所有身份测试空 ID，[nested] 默认无嵌套。
/// 返回的控制器归测试持有，须在视图卸载后 close，不访问网络或业务目录。
DocumentEditorController _editor({
  required CollabHostServices services,
  String? id,
  bool nested = false,
}) {
  final nodes = [
    for (final kind in ['meeting', 'task', 'user'])
      BlockCraftJsonCodec.decodeBlock({
        'id': kind,
        'flavour': 'paragraph',
        'nodeType': 'editable',
        'props': <String, dynamic>{},
        'meta': <String, dynamic>{},
        'children': [
          {
            'insert': {'mention': 'Ref-$kind'},
            'attributes': {
              'mentionType': kind,
              'mentionId': id ?? '$kind-id',
              'extension': {'kept': true},
            },
          },
        ],
      }),
  ];
  final editor = DocumentEditorController(
    document: Document(
      root: pageNode(
        children: nested ? [Node(type: 'callout', children: nodes)] : nodes,
      ),
    ),
    commandContext: EditorCommandContext(localOnly: true, services: services),
  );
  editor.editorState
    ..editable = false
    ..transactionGuard = (_) => false;
  return editor;
}

/// 在 [tester] 中展示借用 [editor]；[embedded] 默认自然高度，[enabled]/[interactions] 控制点击边界。
/// [legacyTasks] 默认 false，验证原任务预览面板兼容；[tracker] 可空并由测试拥有，[staticMedia] 为 true 模拟截图；不创建输入或业务持久化端口。
Future<void> _mount(
  WidgetTester tester,
  DocumentEditorController editor, {
  bool embedded = true,
  bool enabled = true,
  bool interactions = true,
  bool legacyTasks = false,
  EditorResourceTracker? tracker,
  bool staticMedia = false,
}) async {
  final view = DocumentEditorView(
    editorState: editor.editorState,
    preview: true,
    embeddedPreview: embedded,
    enabled: enabled,
    previewMentionInteractions: interactions,
    previewTaskMentionInteractions: legacyTasks,
  );
  final body = embedded ? SingleChildScrollView(child: view) : view;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: tracker == null
            ? body
            : EditorResourceScope(
                tracker: tracker,
                staticMedia: staticMedia,
                child: body,
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 点击 [tester] 中 [title] 的实际排版字符，兼容 WidgetSpan 与跨行任务 TextSpan；不调用回调替身。
Future<void> _tap(WidgetTester tester, String title) async {
  final rich = find
      .byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains(title),
      )
      .first;
  final render = tester.renderObject<RenderParagraph>(rich);
  final offset = render.text.toPlainText().indexOf(title) + 1;
  final box = render
      .getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      )
      .first;
  await tester.tapAt(render.localToGlobal(box.toRect().center));
  await tester.pumpAndSettle();
}

/// 先卸载 [tester] 的真实视图，再等待本测试拥有的 [editor] 关闭；释放失败保留为测试失败。
Future<void> _close(
  WidgetTester tester,
  DocumentEditorController editor,
) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(editor.close);
  expect(tester.takeException(), isNull);
}
