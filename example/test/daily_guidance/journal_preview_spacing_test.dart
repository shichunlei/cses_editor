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

/// 验证栏目间距最多两行，预览折叠尾部空白且不删除原文，编辑保留原书写空间。
void main() {
  for (final sample in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('preview section gaps stay within two lines at $sample', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(sample.$1, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = _Store();
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
          ValueKey('journal-lines-${record.children[2].id}'),
        );
        final gap =
            tester.getRect(find.text('感悟')).top -
            tester.getRect(recordLast).bottom;
        final shortSectionGap =
            tester.getRect(find.text('自检')).top -
            tester
                .getRect(
                  find.byKey(
                    ValueKey('journal-lines-${reflection.children.single.id}'),
                  ),
                )
                .bottom;
        if (preview) {
          expect(gap, inInclusiveRange(0, 2 * 32 * sample.$2));
          expect(shortSectionGap, inInclusiveRange(0, 2 * 32 * sample.$2));
          expect(
            find.byKey(ValueKey('journal-lines-${record.children.last.id}')),
            findsNothing,
          );
        } else {
          expect(gap, greaterThan(2 * 32 * sample.$2));
          expect(shortSectionGap, greaterThanOrEqualTo(2 * 32 * sample.$2));
          expect(
            find.byKey(ValueKey('journal-lines-${record.children.last.id}')),
            findsOneWidget,
          );
        }
        // 中间的空行仍显示，只有栏目末尾的普通空段落在预览时折叠。
        expect(
          find.byKey(ValueKey('journal-lines-${record.children[1].id}')),
          findsOneWidget,
        );
        expect(jsonEncode(state.document.toJson()), before);
        expect(store.writes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.runAsync(journal.close);
      }
    });
  }
}
