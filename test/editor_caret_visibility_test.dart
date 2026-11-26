import 'dart:convert';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_editor/src/editor/editor_caret_visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用真实编辑器覆盖短视口、字号变化及重复窗口通知；每个用例拥有并释放会话和尺寸状态。
void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          const EventChannel('keyboardHeightEventChannel'),
          MockStreamHandler.inline(
            onListen: (_, events) => events.success(0.0),
          ),
        );
  });

  for (final scale in [1.0, 2.0]) {
    for (final spare in [80.0, 6.0, 0.0, -6.0]) {
      testWidgets('光标避让 scale=$scale 行外余量=$spare，重复通知不偏移', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 680);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.reset);
        final height = ValueNotifier(252.0);
        final controller = DocumentEditorController(
          document: Document(
            root: pageNode(
              children: [
                for (var i = 0; i < 40; i++) paragraphNode(text: 'Line $i'),
              ],
            ),
          ),
        );
        final state = controller.editorState;
        final before = jsonEncode(state.document.toJson());
        try {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: const [
                AppFlowyEditorLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: ValueListenableBuilder<double>(
                      valueListenable: height,
                      builder: (context, value, _) => SizedBox(
                        height: value,
                        child: DocumentEditorView(editorState: state),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          state.selection = Selection.collapsed(Position(path: [1], offset: 2));
          await tester.pumpAndSettle();
          final selection = state.selection;
          final inputVisible = tester.testTextInput.isVisible;
          final lineHeight = state.selectionRects().single.height;
          final viewportFinder = find.byType(EditorCaretVisibility);
          final toolbarHeight =
              height.value - tester.getSize(viewportFinder).height;
          // 根据实际行高设置空间，不假定测试字体或大字模式的固定像素值。
          height.value = lineHeight + spare + toolbarHeight;
          await tester.pumpAndSettle();
          final viewport = tester.getRect(viewportFinder);
          expect(viewport.height, closeTo(lineHeight + spare, .01));
          final line = state.selectionRects().single;
          if (spare >= 0) {
            expect(line.top, greaterThanOrEqualTo(viewport.top - .01));
            expect(line.bottom, lessThanOrEqualTo(viewport.bottom + .01));
            if (spare >= 16) {
              expect(line.bottom, lessThanOrEqualTo(viewport.bottom - 8 + .01));
            }
          } else {
            expect(
              line.top,
              closeTo(viewport.top, .01),
              reason: '放不下整行时稳定对齐行顶',
            );
          }
          final scroll = state.scrollableState!.position;
          final offset = scroll.pixels;
          for (var pulse = 0; pulse < 4; pulse++) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            expect(scroll.pixels, closeTo(offset, .5));
            expect(state.selectionRects().single, line);
            expect(state.selection, selection);
          }
          expect(jsonEncode(state.document.toJson()), before);
          expect(tester.testTextInput.isVisible, inputVisible);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(controller.close);
          height.dispose();
        }
      });
    }
  }
}
