import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_blockcraft_codec.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 布局测试专用只读快照；测试拥有，无文件、账号或客户端资源。
final class _PreviewStore implements JournalStore {
  /// 持有与原编辑器无可变共享的 [draft]。
  _PreviewStore(this.draft);

  /// 独立的初始只读内容。
  final JournalDraft draft;

  /// 返回独立校验值，模拟从首页打开预览的加载流程。
  @override
  Future<JournalDraft?> read() async => JournalDraft.fromJson(draft.toJson());

  /// 预览不可调用持久化；出现 [value] 写入即让测试失败。
  @override
  Future<void> write(JournalDraft value) async => throw StateError('预览不得保存');
}

/// 为已有布局回归在独立路由打开/关闭固定预览，不在编辑页添加切换按钮。
/// 从 [tester] 当前编辑树捕获独立快照，保留原编辑路由的选择、历史和资源所有权。
Future<void> openOrCloseJournalPreview(WidgetTester tester) async {
  final pageFinder = find.byType(LocalJournalPage);
  final page = tester.widget<LocalJournalPage>(pageFinder);
  if (page.mode == JournalPageMode.preview) {
    await tester.tap(find.byKey(const ValueKey('journal-back')));
    await tester.pumpAndSettle();
    return;
  }
  final state = tester
      .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
      .editorState;
  final saved =
      await tester.runAsync(() => page.store.read()) ??
      JournalDraft.blank(DateTime.now());
  final dates = tester
      .widgetList<Semantics>(find.byType(Semantics))
      .map((widget) => widget.properties.label)
      .whereType<String>()
      .where((label) => label.startsWith('记录日期 '));
  final snapshot = JournalDraft(
    id: saved.id,
    date: dates.isEmpty ? saved.date : dates.first.substring('记录日期 '.length),
    createdAt: saved.createdAt,
    updatedAt: saved.updatedAt,
    timezoneOffsetMinutes: saved.timezoneOffsetMinutes,
    documentJson: jsonEncode(state.document.toJson()),
    blockCraftIdsJson: JournalBlockCraftCodec.captureIdentities(state.document),
  );
  final navigator = Navigator.of(tester.element(pageFinder));
  unawaited(
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => LocalJournalPage(
          store: _PreviewStore(snapshot),
          mode: JournalPageMode.preview,
          hostServices: page.hostServices,
          mentionDirectory: page.mentionDirectory,
          storageScope: page.storageScope,
          sessionIdentity: page.sessionIdentity,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
