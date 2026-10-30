import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/journal_surface.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试独占的栏目草稿，包含内部空行、大量尾部空段落和只有一行的栏目。
class _Store implements JournalStore {
  /// 构建独立草稿；临时 Document 在生成快照后释放。
  _Store() {
    final blank = JournalDraft.blank(DateTime(2026, 10, 29));
    final document = Document(
      root: Node(
        type: 'page',
        children: [
          Node(
            type: journalSectionType,
            attributes: {'section': 'record'},
            children: [
              paragraphNode(text: '第一行'),
              paragraphNode(),
              paragraphNode(text: '最后一行'),
              for (var i = 0; i < 8; i++) paragraphNode(),
            ],
          ),
          Node(
            type: journalSectionType,
            attributes: {'section': 'reflection'},
            children: [paragraphNode(text: '感悟内容')],
          ),
          Node(
            type: journalSectionType,
            attributes: {'section': 'self-check'},
            children: [paragraphNode(text: '自检内容')],
          ),
        ],
      ),
    );
    try {
      value = JournalDraft.fromJson({
        ...blank.toJson(),
        'document': document.toJson(),
      });
    } finally {
      document.dispose();
    }
  }

  /// 初始草稿快照，不与视图共享可变节点。
  late final JournalDraft value;

  /// 保存次数，预览排版始终不提交。
  int writes = 0;

  /// 返回初始化的草稿，不访问外部服务。
  @override
  Future<JournalDraft?> read() async => value;

  /// 统计 [draft] 的保存请求。
  @override
  Future<void> write(JournalDraft draft) async {
    writes++;
  }
}

/// 验证编辑和预览共用两行内的栏目留白，编辑空段落可继续输入且撤销，不删除原文。
void main() {
  for (final sample in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'edit and preview section gaps match within two lines at $sample',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(sample.$1, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final store = _Store();
        final modeGaps = <List<double>>[];
        for (final preview in [false, true]) {
          final journal = await LocalJournalController.open(
            store: store,
            readOnly: preview,
            autoSave: false,
          );
          final state = journal.editor.editorState;
          final before = jsonEncode(state.document.toJson());
          final record = state.document.root.children.first;
          final reflection = state.document.root.children[1];
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(sample.$1, 2400),
                  textScaler: TextScaler.linear(sample.$2),
                ),
                child: Scaffold(
                  body: JournalSurface(
                    editorState: state,
                    preview: preview,
                    header: const SizedBox(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final recordLast = find.byKey(
            ValueKey(
              'journal-lines-${record.children[preview ? 2 : record.children.length - 1].id}',
            ),
          );
          final gap =
              tester.getRect(find.text('感悟')).top -
              tester.getRect(recordLast).bottom;
          final shortSectionGap =
              tester.getRect(find.text('自检')).top -
              tester
                  .getRect(
                    find.byKey(
                      ValueKey(
                        'journal-lines-${reflection.children.single.id}',
                      ),
                    ),
                  )
                  .bottom;
          expect(gap, inInclusiveRange(0, 2 * 32 * sample.$2));
          expect(shortSectionGap, inInclusiveRange(0, 2 * 32 * sample.$2));
          modeGaps.add([gap, shortSectionGap]);
          expect(
            find.byKey(ValueKey('journal-lines-${record.children.last.id}')),
            preview ? findsNothing : findsOneWidget,
          );
          // 中间的空行仍显示，只有栏目末尾的普通空段落在预览时折叠。
          expect(
            find.byKey(ValueKey('journal-lines-${record.children[1].id}')),
            findsOneWidget,
          );
          expect(jsonEncode(state.document.toJson()), before);
          if (!preview) {
            await state.apply(
              state.transaction..insertText(record.children.last, 0, '继续书写'),
            );
            await tester.pumpAndSettle();
            expect(record.children.last.delta!.toPlainText(), '继续书写');
            state.undoManager.undo();
            await tester.pumpAndSettle();
            expect(jsonEncode(state.document.toJson()), before);
          }
          expect(store.writes, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await tester.runAsync(journal.close);
        }
        expect(modeGaps[0], modeGaps[1]);
      },
    );
  }
}
